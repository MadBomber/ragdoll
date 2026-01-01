# frozen_string_literal: true

require 'simple_flow'

module Ragdoll
  module Workflows
    # Multi-Modal Embedding Workflow using SimpleFlow for parallel execution
    #
    # Processes documents with mixed content types (text, images, audio) by
    # generating embeddings for each content type in parallel.
    #
    # Pipeline structure:
    #   parse_document
    #       ↓
    #       ├─→ embed_text_chunks   (text content)
    #       ├─→ embed_images        (image content)   ← All 3 run in parallel
    #       └─→ embed_audio         (audio content)
    #              ↓
    #         store_embeddings (depends on all embedding steps)
    #
    # @example
    #   workflow = Ragdoll::Workflows::MultiModalEmbeddingWorkflow.new(
    #     embedding_service: embedding_service
    #   )
    #   result = workflow.call(
    #     document_id: doc.id,
    #     text_content: "...",
    #     images: [image_data1, image_data2],
    #     audio_segments: [audio_data1]
    #   )
    #
    class MultiModalEmbeddingWorkflow
      # Default chunking configuration
      DEFAULT_CHUNK_SIZE = 1000
      DEFAULT_CHUNK_OVERLAP = 200

      # @param embedding_service [Ragdoll::EmbeddingService] For generating embeddings
      # @param concurrency [Symbol] Concurrency mode (:auto, :async, :threads)
      #
      def initialize(embedding_service:, concurrency: :auto)
        @embedding_service = embedding_service
        @concurrency = concurrency
        build_pipeline
      end

      # Execute the multi-modal embedding workflow
      #
      # @param document_id [Integer] The document ID
      # @param text_content [String, nil] Text content to embed
      # @param images [Array<Hash>, nil] Image data to embed
      #   Each hash should have :data (binary), :description (optional), :metadata
      # @param audio_segments [Array<Hash>, nil] Audio data to embed
      #   Each hash should have :data (binary), :transcript (optional), :metadata
      # @param options [Hash] Processing options
      # @option options [Integer] :chunk_size Max tokens per chunk
      # @option options [Integer] :chunk_overlap Overlap between chunks
      # @return [Hash] Results with embedding counts per content type
      #
      def call(document_id:, text_content: nil, images: nil, audio_segments: nil, options: {})
        document = Ragdoll::Document.find(document_id)

        initial_data = {
          document_id: document_id,
          document: document,
          text_content: text_content,
          images: images || [],
          audio_segments: audio_segments || [],
          options: options.merge(
            chunk_size: options[:chunk_size] || DEFAULT_CHUNK_SIZE,
            chunk_overlap: options[:chunk_overlap] || DEFAULT_CHUNK_OVERLAP
          ),
          # Results tracking
          text_embeddings: [],
          image_embeddings: [],
          audio_embeddings: [],
          # Error tracking
          errors: {}
        }

        # Execute the parallel pipeline
        result = @pipeline.call_parallel(SimpleFlow::Result.new(initial_data))

        if result.continue?
          data = result.value
          {
            success: true,
            document_id: document_id,
            text_embeddings_count: data[:text_embeddings].size,
            image_embeddings_count: data[:image_embeddings].size,
            audio_embeddings_count: data[:audio_embeddings].size,
            total_embeddings: data[:text_embeddings].size +
                              data[:image_embeddings].size +
                              data[:audio_embeddings].size,
            errors: data[:errors]
          }
        else
          log(:error, "MultiModalEmbeddingWorkflow failed: #{result.errors.inspect}")
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
        workflow_logger = method(:log)
        create_emb = method(:create_embedding)

        @pipeline = SimpleFlow::Pipeline.new(concurrency: @concurrency) do
          # Embed text chunks
          step :embed_text_chunks, ->(result) {
            data = result.value
            text_content = data[:text_content]

            if text_content.present?
              begin
                # Chunk the text content using class method
                chunk_size = data[:options][:chunk_size]
                chunk_overlap = data[:options][:chunk_overlap]
                chunks = Ragdoll::TextChunker.chunk(text_content, chunk_size: chunk_size, chunk_overlap: chunk_overlap)

                # Generate embeddings for each chunk in sequence
                # (parallel within this step would require nested concurrency)
                chunks.each_with_index do |chunk, index|
                  vector = embedding_service.generate_embedding(chunk, content_type: :text)
                  next unless vector.is_a?(Array) && vector.any?

                  embedding = create_emb.call(
                    document: data[:document],
                    content: chunk,
                    vector: vector,
                    content_type: 'text',
                    chunk_index: index,
                    model: embedding_service.current_model
                  )
                  data[:text_embeddings] << embedding if embedding
                end

                workflow_logger.call(:info, "Generated #{data[:text_embeddings].size} text embeddings")
              rescue StandardError => e
                workflow_logger.call(:warn, "Text embedding failed: #{e.message}")
                data[:errors][:text] = e.message
              end
            end

            result.continue(data)
          }, depends_on: :none

          # Embed images
          step :embed_images, ->(result) {
            data = result.value
            images = data[:images]

            if images.any?
              begin
                images.each_with_index do |image_data, index|
                  # Get description if available, or generate one
                  description = image_data[:description]
                  unless description.present?
                    # Use image description service if available
                    if defined?(Ragdoll::ImageDescriptionService)
                      description = Ragdoll::ImageDescriptionService.describe(image_data[:data])
                    end
                  end

                  # Generate embedding from description or image
                  if description.present?
                    vector = embedding_service.generate_embedding(description, content_type: :text)
                  else
                    # Try direct image embedding if supported
                    vector = embedding_service.generate_embedding(image_data[:data], content_type: :image)
                  end

                  next unless vector.is_a?(Array) && vector.any?

                  embedding = create_emb.call(
                    document: data[:document],
                    content: description || "[Image #{index + 1}]",
                    vector: vector,
                    content_type: 'image',
                    chunk_index: index,
                    model: embedding_service.current_model,
                    metadata: image_data[:metadata]
                  )
                  data[:image_embeddings] << embedding if embedding
                end

                workflow_logger.call(:info, "Generated #{data[:image_embeddings].size} image embeddings")
              rescue StandardError => e
                workflow_logger.call(:warn, "Image embedding failed: #{e.message}")
                data[:errors][:images] = e.message
              end
            end

            result.continue(data)
          }, depends_on: :none

          # Embed audio segments
          step :embed_audio, ->(result) {
            data = result.value
            audio_segments = data[:audio_segments]

            if audio_segments.any?
              begin
                audio_segments.each_with_index do |audio_data, index|
                  # Get transcript if available, or generate one
                  transcript = audio_data[:transcript]
                  unless transcript.present?
                    # Use audio transcription service if available
                    if defined?(Ragdoll::TextExtractionService)
                      transcript = Ragdoll::TextExtractionService.extract_from_audio(audio_data[:data])
                    end
                  end

                  # Generate embedding from transcript
                  if transcript.present?
                    vector = embedding_service.generate_embedding(transcript, content_type: :text)

                    next unless vector.is_a?(Array) && vector.any?

                    embedding = create_emb.call(
                      document: data[:document],
                      content: transcript,
                      vector: vector,
                      content_type: 'audio',
                      chunk_index: index,
                      model: embedding_service.current_model,
                      metadata: audio_data[:metadata]
                    )
                    data[:audio_embeddings] << embedding if embedding
                  end
                end

                workflow_logger.call(:info, "Generated #{data[:audio_embeddings].size} audio embeddings")
              rescue StandardError => e
                workflow_logger.call(:warn, "Audio embedding failed: #{e.message}")
                data[:errors][:audio] = e.message
              end
            end

            result.continue(data)
          }, depends_on: :none

          # Store all embeddings and update document status
          step :finalize, ->(result) {
            data = result.value
            document = data[:document]

            total_embeddings = data[:text_embeddings].size +
                               data[:image_embeddings].size +
                               data[:audio_embeddings].size

            # Update document status
            if total_embeddings.positive?
              document.update!(status: 'processed')
              workflow_logger.call(:info, "Document #{document.id} processed with #{total_embeddings} embeddings")
            elsif data[:errors].any?
              document.update!(status: 'error')
              workflow_logger.call(:warn, "Document #{document.id} had errors during embedding")
            end

            result.continue(data)
          }, depends_on: [:embed_text_chunks, :embed_images, :embed_audio]
        end
      end

      def create_embedding(document:, content:, vector:, content_type:, chunk_index:, model:, metadata: nil)
        Ragdoll::Embedding.create!(
          embeddable: document.contents.first || document,
          content: content,
          embedding_vector: vector,
          content_type: content_type,
          chunk_index: chunk_index,
          embedding_model: model,
          metadata: metadata || {}
        )
      rescue StandardError => e
        log(:error, "Failed to create embedding: #{e.message}")
        nil
      end

      def log(level, message)
        return unless defined?(Rails) && Rails.logger

        Rails.logger.send(level, "MultiModalEmbeddingWorkflow: #{message}")
      end
    end
  end
end
