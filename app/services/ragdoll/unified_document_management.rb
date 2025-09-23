# frozen_string_literal: true

module Ragdoll
  # Unified document management service for text-based RAG system
  # Handles the entire pipeline from document ingestion to searchable text embeddings
  class UnifiedDocumentManagement
    class ProcessingError < StandardError; end

    def self.add_document(file_path, **options)
      new.add_document(file_path, **options)
    end

    def self.add_document_from_upload(uploaded_file, **options)
      new.add_document_from_upload(uploaded_file, **options)
    end

    def self.process_document(document_id)
      new.process_document(document_id)
    end

    def initialize
      @converter = Ragdoll::DocumentConverter.new
    end

    # Add a document from file path
    def add_document(file_path, **options)
      return nil unless File.exist?(file_path)

      # Determine document type
      document_type = @converter.determine_document_type(file_path)

      # Convert to text
      text_content = @converter.convert_to_text(file_path, document_type)

      # Create document
      document = create_unified_document(
        location: File.expand_path(file_path),
        document_type: document_type,
        text_content: text_content,
        **options
      )

      # Process asynchronously if requested
      if options[:async]
        process_document_async(document.id)
      else
        process_document_sync(document)
      end

      document
    end

    # Add a document from uploaded file
    def add_document_from_upload(uploaded_file, **options)
      # Create temporary file to process
      temp_file = nil
      begin
        temp_file = create_temp_file_from_upload(uploaded_file)
        document_type = @converter.determine_document_type(temp_file.path)
        text_content = @converter.convert_to_text(temp_file.path, document_type)

        # Create document
        document = create_unified_document(
          location: uploaded_file.original_filename || "uploaded_file",
          document_type: document_type,
          text_content: text_content,
          **options
        )

        # Process asynchronously if requested
        if options[:async]
          process_document_async(document.id)
        else
          process_document_sync(document)
        end

        document
      ensure
        temp_file&.close
        temp_file&.unlink if temp_file&.path
      end
    end

    # Process a document by ID
    def process_document(document_id)
      if defined?(Ragdoll::UnifiedDocument)
        document = Ragdoll::UnifiedDocument.find(document_id)
      else
        # Fallback to regular Document
        document = Ragdoll::Document.find(document_id)
      end

      process_document_sync(document)
    end

    # Reprocess document with new text conversion
    def reprocess_document(document_id, **options)
      if defined?(Ragdoll::UnifiedDocument)
        document = Ragdoll::UnifiedDocument.find(document_id)
      else
        document = Ragdoll::Document.find(document_id)
      end

      return nil unless File.exist?(document.location)

      # Re-convert to text
      document_type = @converter.determine_document_type(document.location)
      text_content = @converter.convert_to_text(document.location, document_type, **options)

      # Update document content
      if document.respond_to?(:unified_contents)
        # Unified document approach
        if document.unified_contents.any?
          document.unified_contents.first.update!(content: text_content)
        else
          document.unified_contents.create!(
            content: text_content,
            original_media_type: document_type,
            embedding_model: "text-embedding-3-large",
            metadata: { "reprocessed_at" => Time.current }
          )
        end
      else
        # Fallback to content field
        document.content = text_content
      end

      # Reprocess
      process_document_sync(document)
    end

    # Batch processing for multiple documents
    def batch_process_documents(file_paths, **options)
      results = []
      errors = []

      file_paths.each do |file_path|
        begin
          document = add_document(file_path, **options)
          results << document
        rescue StandardError => e
          errors << { file_path: file_path, error: e.message }
        end
      end

      {
        processed: results,
        errors: errors,
        total: file_paths.length,
        success_count: results.length,
        error_count: errors.length
      }
    end

    # Search across all documents
    def search_documents(query, **options)
      if defined?(Ragdoll::UnifiedDocument)
        Ragdoll::UnifiedDocument.search_content(query, **options)
      else
        Ragdoll::Document.search_content(query, **options)
      end
    end

    # Get processing statistics
    def processing_stats
      if defined?(Ragdoll::UnifiedDocument)
        base_stats = Ragdoll::UnifiedDocument.stats
        content_stats = Ragdoll::UnifiedContent.stats
      else
        base_stats = Ragdoll::Document.stats
        content_stats = Ragdoll::Content.stats
      end

      {
        documents: base_stats,
        content: content_stats,
        processing_summary: {
          total_documents: base_stats[:total_documents],
          processed_documents: base_stats.dig(:by_status, "processed") || 0,
          total_embeddings: base_stats[:total_embeddings],
          average_processing_time: estimate_average_processing_time
        }
      }
    end

    private

    def create_unified_document(location:, document_type:, text_content:, **options)
      title = options[:title] || extract_title_from_location(location)

      if defined?(Ragdoll::UnifiedDocument)
        document = Ragdoll::UnifiedDocument.create!(
          location: location,
          title: title,
          document_type: document_type,
          status: "pending",
          file_modified_at: options[:file_modified_at] || Time.current,
          metadata: options[:metadata] || {}
        )

        # Create unified content
        document.unified_contents.create!(
          content: text_content,
          original_media_type: document_type,
          embedding_model: "text-embedding-3-large",
          metadata: {
            "created_at" => Time.current,
            "conversion_method" => "unified_converter",
            "original_filename" => File.basename(location)
          }
        )
      else
        # Fallback to regular Document
        document = Ragdoll::Document.create!(
          location: location,
          title: title,
          content: text_content,
          document_type: document_type,
          status: "pending",
          file_modified_at: options[:file_modified_at] || Time.current,
          metadata: options[:metadata] || {}
        )
      end

      document
    end

    def process_document_sync(document)
      begin
        if document.respond_to?(:process_document!)
          document.process_document!
        else
          # Fallback processing
          document.update!(status: "processing")
          generate_embeddings_for_document(document)
          document.update!(status: "processed")
        end
      rescue StandardError => e
        document.update!(status: "error", metadata: (document.metadata || {}).merge("error" => e.message))
        raise ProcessingError, "Failed to process document #{document.id}: #{e.message}"
      end

      document
    end

    def process_document_async(document_id)
      # In a real application, this would enqueue a background job
      # For now, we'll just process synchronously
      puts "Note: Async processing not implemented, processing synchronously"
      process_document(document_id)
    end

    def generate_embeddings_for_document(document)
      if document.respond_to?(:unified_contents)
        document.unified_contents.each(&:generate_embeddings!)
      elsif document.respond_to?(:contents)
        document.contents.each(&:generate_embeddings!)
      end
    end

    def create_temp_file_from_upload(uploaded_file)
      temp_file = Tempfile.new([
        File.basename(uploaded_file.original_filename || "upload", ".*"),
        File.extname(uploaded_file.original_filename || "")
      ])

      if uploaded_file.respond_to?(:read)
        temp_file.write(uploaded_file.read)
      elsif uploaded_file.respond_to?(:path)
        FileUtils.cp(uploaded_file.path, temp_file.path)
      else
        raise ProcessingError, "Unknown upload file format"
      end

      temp_file.flush
      temp_file.rewind
      temp_file
    end

    def extract_title_from_location(location)
      filename = File.basename(location, File.extname(location))

      # Clean up common patterns in filenames
      title = filename
               .gsub(/[-_]+/, ' ')
               .gsub(/([a-z])([A-Z])/, '\1 \2')
               .gsub(/\s+/, ' ')
               .strip

      # Capitalize words for better readability
      title.split(' ').map(&:capitalize).join(' ')
    end

    def estimate_average_processing_time
      # This would be calculated from actual processing logs in production
      # For now, return a placeholder
      "~2.5 seconds"
    end
  end
end