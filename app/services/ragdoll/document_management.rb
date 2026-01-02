# frozen_string_literal: true

require "securerandom"

module Ragdoll
  # Document CRUD operations and duplicate detection
  #
  # Provides a high-level API for managing documents in the Ragdoll system.
  # Handles document creation with automatic duplicate detection, retrieval,
  # updates, deletion, and listing. Supports file-based and content-based
  # duplicate detection strategies.
  #
  # @example Add a new document
  #   doc_id = Ragdoll::DocumentManagement.add_document(
  #     "/path/to/file.txt",
  #     "Document content here",
  #     { title: "My Document", document_type: "text" }
  #   )
  #
  # @example Force add (skip duplicate detection)
  #   doc_id = Ragdoll::DocumentManagement.add_document(path, content, {}, force: true)
  #
  class DocumentManagement
    class << self
      # Add a document to the system with duplicate detection
      #
      # @param location [String] File path or URL of the document
      # @param content [String] Text content of the document
      # @param metadata [Hash] Document metadata (title, document_type, etc.)
      # @param force [Boolean] Skip duplicate detection if true
      # @return [String] ID of the created or existing document
      #
      def add_document(location, content, metadata = {}, force: false)
        # Ensure location is an absolute path if it's a file path
        absolute_location = location.start_with?("http") || location.start_with?("ftp") ? location : File.expand_path(location)

        # Get file modification time if it's a file path
        file_modified_at = if File.exist?(absolute_location) && !absolute_location.start_with?("http")
                             File.mtime(absolute_location)
                           else
                             Time.current
                           end

        # Skip duplicate detection if force is true
        unless force
          existing_document = find_duplicate_document(absolute_location, content, metadata, file_modified_at)
          return existing_document.id.to_s if existing_document
        end

        # Modify location if force is used to avoid unique constraint violation
        final_location = if force
                           "#{absolute_location}#forced_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
                         else
                           absolute_location
                         end

        document = Ragdoll::Document.create!(
          location: final_location,
          title: metadata[:title] || metadata["title"] || extract_title_from_location(location),
          document_type: metadata[:document_type] || metadata["document_type"] || "text",
          metadata: metadata.is_a?(Hash) ? metadata : {},
          status: "pending",
          file_modified_at: file_modified_at
        )

        # Set content using the model's setter to trigger TextContent creation
        document.content = content if content.present?

        document.id.to_s
      end

      # Retrieve a document by ID
      #
      # @param id [String, Integer] Document ID
      # @return [Hash, nil] Document hash with content, or nil if not found
      #
      def get_document(id)
        document = Ragdoll::Document.find_by(id: id)
        return nil unless document

        hash = document.to_hash
        hash[:content] = document.content
        hash
      end

      # Update a document's attributes
      #
      # @param id [String, Integer] Document ID
      # @param updates [Hash] Attributes to update (:title, :metadata, :status, :document_type)
      # @return [Hash, nil] Updated document hash, or nil if not found
      #
      def update_document(id, **updates)
        document = Ragdoll::Document.find_by(id: id)
        return nil unless document

        # Only update allowed fields
        allowed_updates = updates.slice(:title, :metadata, :status, :document_type)
        document.update!(allowed_updates) if allowed_updates.any?

        document.to_hash
      end

      # Delete a document by ID
      #
      # @param id [String, Integer] Document ID
      # @return [Boolean, nil] true if deleted, nil if not found
      #
      def delete_document(id)
        document = Ragdoll::Document.find_by(id: id)
        return nil unless document

        document.destroy!
        true
      end

      # List documents with pagination
      #
      # @param options [Hash] Pagination options (:limit, :offset)
      # @return [Array<Hash>] Array of document hashes
      #
      def list_documents(options = {})
        limit = options[:limit] || 100
        offset = options[:offset] || 0

        Ragdoll::Document.offset(offset).limit(limit).recent.map(&:to_hash)
      end

      # Get aggregate statistics about documents
      #
      # @return [Hash] Document statistics from Ragdoll::Document.stats
      #
      def get_document_stats
        Ragdoll::Document.stats
      end

      # Add an embedding for a content chunk
      #
      # @param embeddable_id [Integer] ID of the embeddable content
      # @param chunk_index [Integer] Index of the chunk within the content
      # @param embedding_vector [Array<Float>] Vector embedding
      # @param metadata [Hash] Additional metadata (:embeddable_type, :content)
      # @return [String] ID of the created embedding
      #
      def add_embedding(embeddable_id, chunk_index, embedding_vector, metadata = {})
        # The embeddable_type should be the actual STI subclass, not the base class
        embeddable_type = if metadata[:embeddable_type]
                           metadata[:embeddable_type]
                         else
                           # Look up the actual STI type from the content record
                           content = Ragdoll::Content.find(embeddable_id)
                           content.class.name
                         end
        
        Ragdoll::Embedding.create!(
          embeddable_id: embeddable_id,
          embeddable_type: embeddable_type,
          chunk_index: chunk_index,
          embedding_vector: embedding_vector,
          content: metadata[:content] || ""
        ).id.to_s
      end

      private

      def find_duplicate_document(location, content, metadata, file_modified_at)
        # Primary check: exact location match (simple duplicate detection)
        existing = Ragdoll::Document.find_by(location: location)
        return existing if existing

        # Secondary check: exact location and file modification time (for files)
        existing_with_time = Ragdoll::Document.find_by(
          location: location,
          file_modified_at: file_modified_at
        )
        return existing_with_time if existing_with_time

        # Enhanced duplicate detection for file-based documents
        if File.exist?(location) && !location.start_with?("http")
          file_size = File.size(location)
          content_hash = calculate_file_hash(location)
          
          # Check for documents with same file hash (most reliable)
          potential_duplicates = Ragdoll::Document.where("metadata->>'file_hash' = ?", content_hash)
          return potential_duplicates.first if potential_duplicates.any?
          
          # Check for documents with same file size and similar metadata
          same_size_docs = Ragdoll::Document.where("metadata->>'file_size' = ?", file_size.to_s)
          same_size_docs.each do |doc|
            return doc if documents_are_duplicates?(doc, location, content, metadata, file_size, content_hash)
          end
        end

        # For non-file documents (URLs, etc), check content-based duplicates
        unless File.exist?(location)
          return find_content_based_duplicate(content, metadata)
        end

        nil
      end

      def documents_are_duplicates?(existing_doc, location, content, metadata, file_size, content_hash)
        # Compare multiple factors to determine if documents are duplicates
        
        # Check filename similarity (basename without extension)
        existing_basename = File.basename(existing_doc.location, File.extname(existing_doc.location))
        new_basename = File.basename(location, File.extname(location))
        return false unless existing_basename == new_basename
        
        # Check content length similarity (within 5% tolerance)
        if content.present? && existing_doc.content.present?
          content_length_diff = (content.length - existing_doc.content.length).abs
          max_length = [content.length, existing_doc.content.length].max
          return false if max_length > 0 && (content_length_diff.to_f / max_length) > 0.05
        end
        
        # Check key metadata fields
        existing_metadata = existing_doc.metadata || {}
        new_metadata = metadata || {}
        
        # Compare file type/document type
        return false if existing_doc.document_type != (new_metadata[:document_type] || new_metadata["document_type"] || "text")
        
        # Compare title if available
        existing_title = existing_metadata["title"] || existing_doc.title
        new_title = new_metadata[:title] || new_metadata["title"] || extract_title_from_location(location)
        return false if existing_title && new_title && existing_title != new_title
        
        # If we reach here, documents are likely duplicates
        true
      end

      def find_content_based_duplicate(content, metadata)
        return nil unless content.present?
        
        content_hash = calculate_content_hash(content)
        title = metadata[:title] || metadata["title"]
        
        # Look for documents with same content hash
        Ragdoll::Document.where("metadata->>'content_hash' = ?", content_hash).first ||
        # Look for documents with same title and similar content length (within 5% tolerance)
        (title ? find_by_title_and_content_similarity(title, content) : nil)
      end

      def find_by_title_and_content_similarity(title, content)
        content_length = content.length
        tolerance = content_length * 0.05
        
        Ragdoll::Document.where(title: title).find do |doc|
          doc.content.present? && 
          (doc.content.length - content_length).abs <= tolerance
        end
      end

      def calculate_file_hash(file_path)
        require 'digest'
        Digest::SHA256.file(file_path).hexdigest
      rescue StandardError => e
        Rails.logger.warn "Failed to calculate file hash for #{file_path}: #{e.message}" if defined?(Rails)
        nil
      end

      def calculate_content_hash(content)
        require 'digest'
        Digest::SHA256.hexdigest(content)
      end

      def extract_title_from_location(location)
        File.basename(location, File.extname(location))
      end
    end
  end
end