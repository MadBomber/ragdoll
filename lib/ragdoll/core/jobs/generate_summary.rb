# frozen_string_literal: true

require "active_job"

module Ragdoll
  module Core
    module Jobs
      class GenerateSummary < ActiveJob::Base
        queue_as :default

        def perform(document_id)
          document = Models::Document.find(document_id)
          return unless document.content.present?
          return if document.summary.present?

          text_service = TextGenerationService.new
          summary = text_service.generate_summary(document.content)

          document.update!(summary: summary) if summary.present?
        rescue ActiveRecord::RecordNotFound
          # Document was deleted, nothing to do
        rescue StandardError => e
          Rails.logger.error "Failed to generate summary for document #{document_id}: #{e.message}" if defined?(Rails)
          raise e
        end
      end
    end
  end
end
