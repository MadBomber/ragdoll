# frozen_string_literal: true

require "delegate"
require "debug_me"
include DebugMe
$DEBUG_ME = true

# require_relative "../extensions/openstruct_merge"  # File doesn't exist

require_relative "core/version"
require_relative "core/errors"
require_relative "core/model"
require_relative "core/configuration"
require_relative "core/configuration_service"
require_relative "core/model_resolver"
require_relative "core/database"
require_relative "core/shrine_config"
require_relative "core/models/document"
require_relative "core/models/embedding"
require_relative "core/models/text_content"
require_relative "core/models/audio_content"
require_relative "core/models/image_content"
require_relative "core/document_processor"
require_relative "core/document_management"
require_relative "core/text_chunker"
require_relative "core/embedding_service"
require_relative "core/text_generation_service"
require_relative "core/search_engine"
require_relative "core/services/image_description_service"
require_relative "core/jobs/generate_embeddings"
require_relative "core/jobs/generate_summary"
require_relative "core/jobs/extract_keywords"
require_relative "core/client"

module Ragdoll
  def self.config
    @config ||= Core::Configuration.new
  end

  module Core
    extend SingleForwardable

    def self.config
      @config ||= Configuration.new
    end

    def self.configuration
      config
    end

    def self.configure
      yield(config)
    end

    # Reset configuration (useful for testing)
    def self.reset_configuration!
      @config = Configuration.new
      @default_client = nil
    end

    # Factory method for creating clients
    def self.client(_config = nil)
      Client.new
    end

    # Delegate high-level API methods to default client
    def_delegators :default_client, :add_document, :search, :enhance_prompt,
                   :get_document, :document_status, :list_documents, :delete_document,
                   :update_document, :get_context, :search_similar_content,
                   :add_directory, :stats, :healthy?, :hybrid_search

    def self.default_client
      @default_client ||= Client.new
    end
  end
end
