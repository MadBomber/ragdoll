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

        # Setup database connection
        Database.setup(@config_service.config.database)

        @embedding_service = Ragdoll::EmbeddingService.new(
          client: nil,
          config_service: @config_service,
          model_resolver: @model_resolver
        )
        @search_engine = Ragdoll::SearchEngine.new(@embedding_service, config_service: @config_service)
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
        results = search_similar_content(query: query, limit: limit, **options)

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

      # FIXME: This high-level API method should be able to take a query that is
      #        a string or a file.  If its a file, then the downstream Process will
      #        be responsible for reading the file and passing the contents to the
      #        search method based upon whether the content is text, image or audio.

      # Semantic search++ should incorporate hybrid search
      def search(query:, **options)
        results = search_similar_content(query: query, **options)

        {
          query: query,
          results: results,
          total_results: results.length
        }
      end

      # Search similar content (core functionality)
      def search_similar_content(query:, **options)
        @search_engine.search_similar_content(query, **options)
      end

      # Hybrid search combining semantic and full-text search
      def hybrid_search(query:, **options)
        # Generate embedding for the query
        query_embedding = @embedding_service.generate_embedding(query)

        # Perform hybrid search
        results = Ragdoll::Document.hybrid_search(query, query_embedding: query_embedding, **options)

        {
          query: query,
          search_type: "hybrid",
          results: results,
          total_results: results.length,
          semantic_weight: options[:semantic_weight] || 0.7,
          text_weight: options[:text_weight] || 0.3
        }
      rescue StandardError => e
        {
          query: query,
          search_type: "hybrid",
          results: [],
          total_results: 0,
          error: "Hybrid search failed: #{e.message}"
        }
      end

      # Document management
      def add_document(path:)
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
                                                 })

        # Queue background jobs for processing if content is available
        embeddings_queued = false
        if parsed[:content].present?
          Ragdoll::GenerateEmbeddingsJob.perform_later(doc_id)
          Ragdoll::GenerateSummaryJob.perform_later(doc_id)
          Ragdoll::ExtractKeywordsJob.perform_later(doc_id)
          embeddings_queued = true
        end

        # Return success information
        {
          success: true,
          document_id: doc_id,
          title: title,
          document_type: parsed[:document_type],
          content_length: parsed[:content]&.length || 0,
          embeddings_queued: embeddings_queued,
          message: "Document '#{title}' added successfully with ID #{doc_id}"
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
        log_file = @config_service.config.logging[:filepath]
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
