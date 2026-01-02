# frozen_string_literal: true

require "fileutils"

module Ragdoll
  module Core
    class Client
      def initialize
        # Setup configuration services
        @config_service = Ragdoll::ConfigurationService.new
        @model_resolver = Ragdoll::ModelResolver.new(@config_service)

        # Setup logging
        setup_logging

        # Setup database connection (use database_config which has correct ActiveRecord keys)
        Database.setup(@config_service.config.database_config)

        @embedding_service = Ragdoll::EmbeddingService.new(
          client: nil,
          config_service: @config_service,
          model_resolver: @model_resolver
        )
        @search_engine = Ragdoll::SearchEngine.new(@embedding_service, config_service: @config_service)
        @hybrid_search_service = Ragdoll::HybridSearchService.new(embedding_service: @embedding_service)
      end

      # Primary method for RAG applications
      # Returns context-enhanced content for AI prompts
      def enhance_prompt(prompt:, context_limit: 5, **options)
        context_data = get_context(query: prompt, limit: context_limit, **options)

        if context_data[:context_chunks].any?
          enhanced_prompt = build_enhanced_prompt(prompt, context_data[:combined_context])
          {
            enhanced_prompt: enhanced_prompt,
            original_prompt: prompt,
            context_sources: context_data[:context_chunks].map { |chunk| chunk[:source] },
            context_count: context_data[:total_chunks]
          }
        else
          {
            enhanced_prompt: prompt,
            original_prompt: prompt,
            context_sources: [],
            context_count: 0
          }
        end
      end

      # Get relevant context without prompt enhancement
      def get_context(query:, limit: 10, **options)
        search_response = search_similar_content(query: query, limit: limit, **options)
        
        # Handle both old format (array) and new format (hash with results/statistics)
        if search_response.is_a?(Hash) && search_response.key?(:results)
          results = search_response[:results]
        else
          # Fallback for old format
          results = search_response || []
        end

        context_chunks = results.map do |result|
          {
            content: result[:content],
            source: result[:document_location],
            similarity: result[:similarity],
            chunk_index: result[:chunk_index]
          }
        end

        combined_context = context_chunks.map { |chunk| chunk[:content] }.join("\n\n")

        {
          context_chunks: context_chunks,
          combined_context: combined_context,
          total_chunks: context_chunks.length
        }
      end

      # Unified search method supporting both semantic and hybrid search
      #
      # When timeframe: or tags: are provided, automatically uses hybrid RRF search.
      # Otherwise, uses semantic-only search for backward compatibility.
      #
      # @param query [String] Search query
      # @param timeframe [Range, String, Symbol, nil] Time filter (:auto extracts from query)
      # @param tags [Array<String>, nil] Filter by tags
      # @param limit [Integer] Maximum results
      # @param options [Hash] Additional options
      # @return [Hash] Search results
      #
      def search(query:, timeframe: nil, tags: nil, **options)
        # Use hybrid search when timeframe or tags are specified
        if timeframe || tags
          return hybrid_search(
            query: query,
            timeframe: timeframe,
            tags: tags,
            limit: options[:limit] || 20,
            **options
          )
        end

        # Fall back to semantic-only search
        search_response = search_similar_content(query: query, **options)

        # Handle both old format (array) and new format (hash with results/statistics)
        if search_response.is_a?(Hash) && search_response.key?(:results)
          results = search_response[:results]
          statistics = search_response[:statistics]
          execution_time_ms = search_response[:execution_time_ms]

          {
            query: query,
            search_type: "semantic",
            results: results,
            total_results: results.length,
            statistics: statistics,
            execution_time_ms: execution_time_ms
          }
        else
          # Fallback for old format
          results = search_response || []
          {
            query: query,
            search_type: "semantic",
            results: results,
            total_results: results.length
          }
        end
      end

      # Search similar content (core functionality)
      def search_similar_content(query:, **options)
        @search_engine.search_similar_content(query, **options)
      end

      # Hybrid search using RRF (Reciprocal Rank Fusion)
      # Combines vector similarity, full-text, and tag-based search
      #
      # @param query [String] Search query
      # @param timeframe [Range, String, Symbol, nil] Time filter (:auto extracts from query)
      # @param tags [Array<String>, nil] Filter by tags
      # @param limit [Integer] Maximum results (default: 20)
      # @param parallel [Boolean] Use parallel execution via SimpleFlow (default: true)
      # @param filters [Hash] Additional filters (document_type, keywords, etc.)
      # @return [Hash] Search results with RRF scores
      #
      def hybrid_search(query:, timeframe: nil, tags: nil, limit: 20, parallel: true, **options)
        start_time = Time.current

        # Extract tracking options
        session_id = options.delete(:session_id)
        user_id = options.delete(:user_id)
        track_search = options.delete(:track_search) { true }

        # Extract filters for the hybrid search service
        filters = options.slice(:document_type, :keywords).compact

        # Perform hybrid search using RRF fusion
        results = @hybrid_search_service.search(
          query: query,
          limit: limit,
          timeframe: timeframe,
          tags: tags,
          filters: filters,
          candidate_limit: options[:candidate_limit] || 100,
          parallel: parallel
        )

        execution_time = ((Time.current - start_time) * 1000).round

        # Record search if tracking enabled
        if track_search && query && !query.empty?
          begin
            search_results = results.map do |result|
              {
                embedding_id: result['id'],
                similarity: result['rrf_score'] || 0.0
              }
            end

            Ragdoll::Search.record_search(
              query: query,
              query_embedding: nil,
              results: search_results,
              search_type: "hybrid_rrf",
              filters: filters.merge(tags: tags, timeframe: timeframe.to_s),
              options: options.slice(:limit, :candidate_limit).compact,
              execution_time_ms: execution_time,
              session_id: session_id,
              user_id: user_id
            )
          rescue StandardError => e
            debug_me("Warning: Hybrid search tracking failed: #{e.message}") if $DEBUG_ME
          end
        end

        {
          query: query,
          search_type: "hybrid_rrf",
          results: results,
          total_results: results.length,
          execution_time_ms: execution_time,
          timeframe: timeframe,
          tags: tags
        }
      rescue StandardError => e
        {
          query: query,
          search_type: "hybrid_rrf",
          results: [],
          total_results: 0,
          error: "Hybrid search failed: #{e.message}"
        }
      end

      # Document management
      def add_document(path:, force: false)
        # Parse the document
        parsed = Ragdoll::DocumentProcessor.parse(path)

        # Extract title from metadata or use filename
        title = parsed[:metadata][:title] ||
                File.basename(path, File.extname(path))

        # Add document to database
        doc_id = Ragdoll::DocumentManagement.add_document(path, parsed[:content], {
                                                   title: title,
                                                   document_type: parsed[:document_type],
                                                   **parsed[:metadata]
                                                 }, force: force)

        # Process document using parallel workflow if content is available
        enrichment_result = nil
        if parsed[:content].present?
          enrichment_result = enrich_document(
            document_id: doc_id,
            content: parsed[:content],
            chunk_size: parsed[:metadata][:chunk_size],
            chunk_overlap: parsed[:metadata][:chunk_overlap]
          )
        end

        # Return success information
        {
          success: true,
          document_id: doc_id,
          title: title,
          document_type: parsed[:document_type],
          content_length: parsed[:content]&.length || 0,
          enrichment: enrichment_result,
          message: "Document '#{title}' added and processed with ID #{doc_id}"
        }
      rescue StandardError => e # StandardError => e
        {
          success: false,
          error: e.message,
          message: "Failed to add document: #{e.message}"
        }
      end

      def add_text(content:, title:, **options)
        # Add document to database
        doc_id = Ragdoll::DocumentManagement.add_document(title, content, {
                                                   title: title,
                                                   document_type: "text",
                                                   **options
                                                 })

        # Queue background job for embeddings
        Ragdoll::GenerateEmbeddingsJob.perform_later(doc_id,
                                                     chunk_size: options[:chunk_size],
                                                     chunk_overlap: options[:chunk_overlap])

        doc_id
      end

      def add_directory(path:, recursive: false)
        results = []
        pattern = recursive ? File.join(path, "**", "*") : File.join(path, "*")

        Dir.glob(pattern).each do |file_path|
          next unless File.file?(file_path)

          begin
            doc_id = add_document(path: file_path)
            results << { file: file_path, document_id: doc_id, status: "success" }
          rescue StandardError => e
            results << { file: file_path, error: e.message, status: "error" }
          end
        end

        results
      end

      def get_document(id:)
        document_hash = Ragdoll::DocumentManagement.get_document(id)
        return nil unless document_hash

        # DocumentManagement.get_document already returns a hash with all needed info
        document_hash
      end

      def document_status(id:)
        document = Ragdoll::Document.find(id)
        embeddings_count = document.all_embeddings.count

        {
          id: document.id,
          title: document.title,
          status: document.status,
          embeddings_count: embeddings_count,
          embeddings_ready: embeddings_count.positive?,
          content_preview: document.content&.first(200) || "No content",
          message: case document.status
                   when "processed"
                     "Document processed successfully with #{embeddings_count} embeddings"
                   when "processing"
                     "Document is being processed"
                   when "pending"
                     "Document is pending processing"
                   when "error"
                     "Document processing failed"
                   else
                     "Document status: #{document.status}"
                   end
        }
      rescue ActiveRecord::RecordNotFound
        {
          success: false,
          error: "Document not found",
          message: "Document with ID #{id} does not exist"
        }
      end

      def update_document(id:, **updates)
        Ragdoll::DocumentManagement.update_document(id, **updates)
      end

      def delete_document(id:)
        Ragdoll::DocumentManagement.delete_document(id)
      end

      def list_documents(**options)
        Ragdoll::DocumentManagement.list_documents(options)
      end

      # Tag management
      #
      # Add tags to a document
      #
      # @param document_id [Integer] Document ID
      # @param tags [Array<String>] Tags to add (hierarchical format: "database:postgresql")
      # @param source [String] Tag source ('manual' or 'auto')
      # @return [Array<Ragdoll::DocumentTag>] Created document tags
      #
      def add_tags(document_id:, tags:, source: 'manual')
        Ragdoll::TagService.add_tags_to_document(
          document_id: document_id,
          tags: tags,
          source: source
        )
      end

      # Get tags for a document or embedding
      #
      # @param document_id [Integer, nil] Document ID
      # @param embedding_id [Integer, nil] Embedding ID
      # @return [Array<Hash>] Tags with confidence and source
      #
      def get_tags(document_id: nil, embedding_id: nil)
        if document_id
          document = Ragdoll::Document.find(document_id)
          document.document_tags.includes(:tag).map do |dt|
            {
              name: dt.tag.name,
              confidence: dt.confidence,
              source: dt.source,
              depth: dt.tag.depth
            }
          end
        elsif embedding_id
          embedding = Ragdoll::Embedding.find(embedding_id)
          embedding.embedding_tags.includes(:tag).map do |et|
            {
              name: et.tag.name,
              confidence: et.confidence,
              source: et.source,
              depth: et.tag.depth
            }
          end
        else
          raise ArgumentError, "Must provide either document_id or embedding_id"
        end
      end

      # Extract and store propositions for a document
      #
      # @param document_id [Integer] Document ID
      # @return [Array<Ragdoll::Proposition>] Created propositions
      #
      def extract_propositions(document_id:)
        Ragdoll::PropositionService.extract_and_store(
          document_id,
          embedding_service: @embedding_service
        )
      end

      # Get propositions for a document
      #
      # @param document_id [Integer] Document ID
      # @return [Array<Hash>] Propositions with metadata
      #
      def get_propositions(document_id:)
        document = Ragdoll::Document.find(document_id)
        document.propositions.map do |prop|
          {
            id: prop.id,
            content: prop.content,
            source_embedding_id: prop.source_embedding_id,
            has_embedding: prop.embedding_vector.present?,
            metadata: prop.metadata,
            created_at: prop.created_at
          }
        end
      end

      # Workflow-based document enrichment
      #
      # Enriches a document using parallel processing via SimpleFlow.
      # Runs embeddings, summary, keywords, tags, and propositions in parallel.
      #
      # @param document_id [Integer] Document ID
      # @param content [String] Document content
      # @param options [Hash] Processing options
      # @option options [Integer] :chunk_size Max tokens per chunk
      # @option options [Integer] :chunk_overlap Overlap between chunks
      # @option options [Boolean] :skip_embeddings Skip embedding generation
      # @option options [Boolean] :skip_summary Skip summary generation
      # @option options [Boolean] :skip_keywords Skip keyword extraction
      # @option options [Boolean] :skip_tags Skip tag extraction
      # @option options [Boolean] :skip_propositions Skip proposition extraction
      # @return [Hash] Enrichment results with stats
      #
      def enrich_document(document_id:, content:, **options)
        workflow = Ragdoll::Workflows::DocumentEnrichmentWorkflow.new(
          embedding_service: @embedding_service,
          config_service: @config_service
        )
        workflow.call(
          document_id: document_id,
          content: content,
          options: options
        )
      end

      # Workflow-based multi-modal embedding generation
      #
      # Generates embeddings for text, images, and audio content in parallel.
      #
      # @param document_id [Integer] Document ID
      # @param text_content [String, nil] Text content to embed
      # @param images [Array<Hash>, nil] Image data to embed
      # @param audio_segments [Array<Hash>, nil] Audio data to embed
      # @param options [Hash] Processing options
      # @return [Hash] Results with embedding counts per content type
      #
      def embed_multimodal(document_id:, text_content: nil, images: nil, audio_segments: nil, **options)
        workflow = Ragdoll::Workflows::MultiModalEmbeddingWorkflow.new(
          embedding_service: @embedding_service
        )
        workflow.call(
          document_id: document_id,
          text_content: text_content,
          images: images,
          audio_segments: audio_segments,
          options: options
        )
      end

      # Analytics and stats
      def stats
        Ragdoll::DocumentManagement.get_document_stats
      end

      def search_analytics(days: 30)
        # This could be implemented with additional database queries
        Ragdoll::Embedding.where("returned_at > ?", days.days.ago)
                         .group("DATE(returned_at)")
                         .count
      end

      # Health check
      def healthy?
        Database.connected? && stats[:total_documents] >= 0
      rescue StandardError
        false
      end

      private

      def setup_logging
        require "logger"
        require "active_job"

        # Create log directory if it doesn't exist
        log_file = File.expand_path(@config_service.config.logging[:filepath] || "~/.config/ragdoll/logs/ragdoll.log")
        log_dir = File.dirname(log_file)
        FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)

        # Set up logger with appropriate level
        logger = Logger.new(log_file)
        logger.level = case @config_service.config.logging[:level]
                       when :debug then Logger::DEBUG
                       when :info then Logger::INFO
                       when :warn then Logger::WARN
                       when :error then Logger::ERROR
                       when :fatal then Logger::FATAL
                       else Logger::WARN
                       end

        # Configure ActiveJob to use our logger and reduce verbosity
        ActiveJob::Base.logger = logger
        ActiveJob::Base.logger.level = Logger::WARN

        # Set up ActiveJob queue adapter - use inline for immediate execution
        ActiveJob::Base.queue_adapter = :inline
      end

      def build_enhanced_prompt(original_prompt, context)
        template = @config_service.config.prompt_template(:rag_enhancement)

        template
          .gsub("{{context}}", context)
          .gsub("{{prompt}}", original_prompt)
      end
    end
  end
end
