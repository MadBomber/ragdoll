# frozen_string_literal: true

require "active_job"

module Ragdoll
  class ExtractTextJob < ActiveJob::Base
    queue_as :default

    def perform(document_id)
      document = Ragdoll::Document.find(document_id)
      return unless document.file_attached?
      return if document.content.present?

      document.update!(status: "processing")

      extracted_content = document.extract_text_from_file

      if extracted_content.present?
        document.update!(
          content: extracted_content,
          status: "processed"
        )

        # Queue follow-up jobs
        Ragdoll::GenerateSummaryJob.perform_later(document_id)
        Ragdoll::ExtractKeywordsJob.perform_later(document_id)
        Ragdoll::GenerateEmbeddingsJob.perform_later(document_id)
      else
        document.update!(status: "error")
      end
    rescue ActiveRecord::RecordNotFound
      # Document was deleted, nothing to do
    rescue StandardError => e
      document&.update!(status: "error")
      raise e
    end
  end
end