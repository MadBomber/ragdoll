# frozen_string_literal: true

module Ragdoll
  class DocumentManagement
    class << self
      def add_document(location, content, metadata = {})
        # Ensure location is an absolute path if it's a file path
        absolute_location = location.start_with?("http") || location.start_with?("ftp") ? location : File.expand_path(location)

        # Get file modification time if it's a file path
        file_modified_at = if File.exist?(absolute_location) && !absolute_location.start_with?("http")
                             File.mtime(absolute_location)
                           else
                             Time.current
                           end

        # Check if document already exists with same location and file_modified_at
        existing_document = Ragdoll::Document.find_by(
          location: absolute_location,
          file_modified_at: file_modified_at
        )

        # Return existing document ID if found (skip duplicate)
        return existing_document.id.to_s if existing_document

        document = Ragdoll::Document.create!(
          location: absolute_location,
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

      def get_document(id)
        document = Ragdoll::Document.find_by(id: id)
        return nil unless document

        hash = document.to_hash
        hash[:content] = document.content
        hash
      end

      def update_document(id, **updates)
        document = Ragdoll::Document.find_by(id: id)
        return nil unless document

        # Only update allowed fields
        allowed_updates = updates.slice(:title, :metadata, :status, :document_type)
        document.update!(allowed_updates) if allowed_updates.any?

        document.to_hash
      end

      def delete_document(id)
        document = Ragdoll::Document.find_by(id: id)
        return nil unless document

        document.destroy!
        true
      end

      def list_documents(options = {})
        limit = options[:limit] || 100
        offset = options[:offset] || 0

        Ragdoll::Document.offset(offset).limit(limit).recent.map(&:to_hash)
      end

      def get_document_stats
        Ragdoll::Document.stats
      end

      # FIXME: should this be here?

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

      def extract_title_from_location(location)
        File.basename(location, File.extname(location))
      end
    end
  end
end