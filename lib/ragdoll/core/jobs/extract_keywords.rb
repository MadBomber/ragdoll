# frozen_string_literal: true

require "active_job"

module Ragdoll
  module Core
    module Jobs
      class ExtractKeywords < ActiveJob::Base
        queue_as :default

        def perform(document_id)
          document = Models::Document.find(document_id)
          return unless document.content.present?
          return if document.keywords.present?

          text_service = TextGenerationService.new
          keywords_array = text_service.extract_keywords(document.content)

          if keywords_array.present?
            keywords_string = keywords_array.join(", ")
            document.update!(keywords: keywords_string)
          end
        rescue ActiveRecord::RecordNotFound
          # Document was deleted, nothing to do
        rescue StandardError => e
          Rails.logger.error "Failed to generate keywords for document #{document_id}: #{e.message}" if defined?(Rails)
          raise e
        end
      end
    end
  end
end
