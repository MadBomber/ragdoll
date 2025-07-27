# frozen_string_literal: true

require "active_job"

module Ragdoll
  module Core
    module Jobs
      class ExtractText < ActiveJob::Base
        queue_as :default

        def perform(document_id)
          document = Models::Document.find(document_id)
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
            GenerateSummaryJob.perform_later(document_id)
            GenerateKeywordsJob.perform_later(document_id)
            GenerateEmbeddingsJob.perform_later(document_id)
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
  end
end
