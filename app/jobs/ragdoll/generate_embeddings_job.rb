# frozen_string_literal: true

require "active_job"

module Ragdoll
  class GenerateEmbeddingsJob < ActiveJob::Base
    queue_as :default

    def perform(document_id, chunk_size: nil, chunk_overlap: nil)
      document = Ragdoll::Document.find(document_id)
      return unless document.content.present?
      return if document.all_embeddings.exists?

      # Process all content records using their own generate_embeddings! methods
      document.contents.each(&:generate_embeddings!)

      # Update document status to processed
      document.update!(status: "processed")
    rescue ActiveRecord::RecordNotFound
      # Document was deleted, nothing to do
    rescue StandardError => e
      if defined?(Rails)
        Rails.logger.error "Failed to generate embeddings for document #{document_id}: #{e.message}"
      end
      raise e
    end
  end
end