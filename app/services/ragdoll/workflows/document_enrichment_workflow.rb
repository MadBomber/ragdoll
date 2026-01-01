# frozen_string_literal: true

require 'simple_flow'

module Ragdoll
  module Workflows
    # Document Enrichment Workflow using SimpleFlow for parallel execution
    #
    # Orchestrates parallel enrichment of a document after it's stored:
    # - Generates embeddings for content chunks
    # - Generates document summary
    # - Extracts keywords
    # - Extracts hierarchical tags
    # - Extracts atomic propositions
    #
    # Pipeline structure:
    #   store_document (critical)
    #       ↓
    #       ├─→ generate_embeddings (I/O-bound LLM call)
    #       ├─→ generate_summary    (I/O-bound LLM call)
    #       ├─→ extract_keywords    (I/O-bound LLM call)  ← All 5 run in parallel
    #       ├─→ extract_tags        (I/O-bound LLM call)
    #       └─→ extract_propositions (I/O-bound LLM call)
    #              ↓
    #         finalize (waits for all enrichment)
    #
    # @example
    #   workflow = Ragdoll::Workflows::DocumentEnrichmentWorkflow.new(
    #     embedding_service: embedding_service,
    #     config_service: config_service
    #   )
    #   result = workflow.call(
    #     document_id: doc.id,
    #     content: parsed_content,
    #     options: { chunk_size: 1000, chunk_overlap: 200 }
    #   )
    #
    class DocumentEnrichmentWorkflow
      # @param embedding_service [Ragdoll::EmbeddingService] For generating embeddings
      # @param config_service [Ragdoll::ConfigurationService, nil] Optional config
      # @param concurrency [Symbol] Concurrency mode (:auto, :async, :threads)
      #
      def initialize(embedding_service:, config_service: nil, concurrency: :auto)
        @embedding_service = embedding_service
        @config_service = config_service
        @concurrency = concurrency
        build_pipeline
      end

      # Execute the document enrichment workflow
      #
      # @param document_id [Integer] The document ID to enrich
      # @param content [String] The document content (already stored)
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
      def call(document_id:, content:, options: {})
        document = Ragdoll::Document.find(document_id)

        initial_data = {
          document_id: document_id,
          document: document,
          content: content,
          options: options,
          # Results tracking
          embeddings_count: 0,
          summary: nil,
          keywords: [],
          tags: [],
          propositions_count: 0,
          # Error tracking
          errors: {}
        }

        # Execute the parallel pipeline
        result = @pipeline.call_parallel(SimpleFlow::Result.new(initial_data))

        if result.continue?
          data = result.value
          finalize_document(data)

          {
            success: true,
            document_id: document_id,
            embeddings_count: data[:embeddings_count],
            summary_generated: data[:summary].present?,
            keywords_count: data[:keywords]&.size || 0,
            tags_count: data[:tags]&.size || 0,
            propositions_count: data[:propositions_count],
            errors: data[:errors]
          }
        else
          log(:error, "DocumentEnrichmentWorkflow failed: #{result.errors.inspect}")
          {
            success: false,
            document_id: document_id,
            errors: result.errors
          }
        end
      end

      # Generate Mermaid diagram of the workflow
      def to_mermaid
        @pipeline.visualize_mermaid
      end

      # Get the execution plan
      def execution_plan
        @pipeline.execution_plan
      end

      private

      def build_pipeline
        embedding_service = @embedding_service
        config_service = @config_service
        workflow_logger = method(:log)

        @pipeline = SimpleFlow::Pipeline.new(concurrency: @concurrency) do
          # Generate embeddings for document chunks
          step :generate_embeddings, ->(result) {
            data = result.value
            return result.continue(data) if data[:options][:skip_embeddings]

            begin
              document = data[:document]
              content = data[:content]

              # Chunk the content using class method
              chunk_size = data[:options][:chunk_size] || 1000
              chunk_overlap = data[:options][:chunk_overlap] || 200
              chunks = Ragdoll::TextChunker.chunk(content, chunk_size: chunk_size, chunk_overlap: chunk_overlap)

              # Generate embeddings for each chunk
              chunks.each_with_index do |chunk, index|
                vector = embedding_service.generate_embedding(chunk)
                next unless vector.is_a?(Array) && vector.any?

                # Create embedding record
                Ragdoll::Embedding.create!(
                  embeddable: document.contents.first || document,
                  content: chunk,
                  embedding_vector: vector,
                  chunk_index: index,
                  embedding_model: embedding_service.current_model
                )
                data[:embeddings_count] += 1
              end
            rescue StandardError => e
              workflow_logger.call(:warn, "Embedding generation failed: #{e.message}")
              data[:errors][:embeddings] = e.message
            end
            result.continue(data)
          }, depends_on: :none

          # Generate document summary
          step :generate_summary, ->(result) {
            data = result.value
            return result.continue(data) if data[:options][:skip_summary]

            begin
              document = data[:document]
              content = data[:content]

              # Only generate summary if content is substantial
              if content.to_s.length > 300
                summary = Ragdoll::TextGenerationService.summarize(content)
                if summary.present?
                  document.update!(summary: summary)
                  data[:summary] = summary
                end
              end
            rescue StandardError => e
              workflow_logger.call(:warn, "Summary generation failed: #{e.message}")
              data[:errors][:summary] = e.message
            end
            result.continue(data)
          }, depends_on: :none

          # Extract keywords
          step :extract_keywords, ->(result) {
            data = result.value
            return result.continue(data) if data[:options][:skip_keywords]

            begin
              document = data[:document]
              content = data[:content]

              keywords = Ragdoll::TextGenerationService.extract_keywords(content)
              if keywords.is_a?(Array) && keywords.any?
                document.update!(keywords: keywords)
                data[:keywords] = keywords
              end
            rescue StandardError => e
              workflow_logger.call(:warn, "Keyword extraction failed: #{e.message}")
              data[:errors][:keywords] = e.message
            end
            result.continue(data)
          }, depends_on: :none

          # Extract hierarchical tags
          step :extract_tags, ->(result) {
            data = result.value
            return result.continue(data) if data[:options][:skip_tags]

            begin
              document = data[:document]
              content = data[:content]

              # Use TagService to extract and store tags
              tags = Ragdoll::TagService.extract(content)
              if tags.is_a?(Array) && tags.any?
                Ragdoll::TagService.add_tags_to_document(
                  document_id: document.id,
                  tags: tags,
                  source: 'auto'
                )
                data[:tags] = tags
              end
            rescue StandardError => e
              workflow_logger.call(:warn, "Tag extraction failed: #{e.message}")
              data[:errors][:tags] = e.message
            end
            result.continue(data)
          }, depends_on: :none

          # Extract atomic propositions
          step :extract_propositions, ->(result) {
            data = result.value
            return result.continue(data) if data[:options][:skip_propositions]

            begin
              document = data[:document]

              # Use PropositionService to extract propositions from embeddings
              propositions = Ragdoll::PropositionService.extract_and_store(
                document.id,
                embedding_service: embedding_service
              )
              data[:propositions_count] = propositions&.count || 0
            rescue StandardError => e
              workflow_logger.call(:warn, "Proposition extraction failed: #{e.message}")
              data[:errors][:propositions] = e.message
            end
            result.continue(data)
          }, depends_on: [:generate_embeddings]  # Propositions need embeddings first

          # Finalize document status
          step :finalize, ->(result) {
            data = result.value
            # Finalization is handled after pipeline completion
            result.continue(data)
          }, depends_on: [:generate_embeddings, :generate_summary, :extract_keywords, :extract_tags, :extract_propositions]
        end
      end

      def finalize_document(data)
        document = data[:document]

        # Update document status based on enrichment results
        if data[:embeddings_count].positive?
          document.update!(status: 'processed')
        elsif data[:errors].any?
          document.update!(status: 'error')
        end

        log(:info, "Document #{document.id} enriched: " \
                   "#{data[:embeddings_count]} embeddings, " \
                   "#{data[:keywords]&.size || 0} keywords, " \
                   "#{data[:tags]&.size || 0} tags, " \
                   "#{data[:propositions_count]} propositions")
      end

      def log(level, message)
        return unless defined?(Rails) && Rails.logger

        Rails.logger.send(level, "DocumentEnrichmentWorkflow: #{message}")
      end
    end
  end
end
