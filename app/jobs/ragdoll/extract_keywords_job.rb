# frozen_string_literal: true

require "active_job"

module Ragdoll
  class ExtractKeywordsJob < ActiveJob::Base
    queue_as :default

    def perform(document_id)
      document = Ragdoll::Document.find(document_id)
      return unless document.content.present?
      return if document.keywords.present?

      text_service = Ragdoll::TextGenerationService.new
      keywords_array = text_service.extract_keywords(document.content)

      document.update!(keywords: keywords_array) if keywords_array.present?
    rescue ActiveRecord::RecordNotFound
      # Document was deleted, nothing to do
    rescue StandardError => e
      Rails.logger.error "Failed to generate keywords for document #{document_id}: #{e.message}" if defined?(Rails)
      raise e
    end
  end
end