# frozen_string_literal: true

require "delegate"
require "debug_me"
include DebugMe
$DEBUG_ME = true

# require_relative "../extensions/openstruct_merge"  # File doesn't exist

# Add app/models, app/jobs, app/services, and app/lib to the load path
$LOAD_PATH.unshift(File.expand_path("../../app/models", __dir__))
$LOAD_PATH.unshift(File.expand_path("../../app/jobs", __dir__))
$LOAD_PATH.unshift(File.expand_path("../../app/services", __dir__))
$LOAD_PATH.unshift(File.expand_path("../../app/lib", __dir__))

require_relative "core/version"
require_relative "core/errors"
require_relative "core/model"
require_relative "core/configuration"
# Require services from app/services/ragdoll
require "ragdoll/configuration_service"
require "ragdoll/model_resolver"
require_relative "core/database"
require_relative "core/shrine_config"

# Require models from app/models/ragdoll
require "ragdoll/document"
require "ragdoll/unified_document"
require "ragdoll/unified_content"
require "ragdoll/embedding"
require "ragdoll/content"
require "ragdoll/text_content"
require "ragdoll/audio_content"
require "ragdoll/image_content"
require "ragdoll/search"
require "ragdoll/search_result"
require "ragdoll/document_processor"
require "ragdoll/document_management"
require "ragdoll/unified_document_management"
require "ragdoll/document_converter"
require "ragdoll/migration_service"
require "ragdoll/text_chunker"
require "ragdoll/embedding_service"
require "ragdoll/text_generation_service"
require "ragdoll/search_engine"
require "ragdoll/image_description_service"
require "ragdoll/image_to_text_service"
require "ragdoll/text_extraction_service"
require "ragdoll/metadata_generator"
require "ragdoll/circuit_breaker"
require "ragdoll/timeframe_extractor"
require "ragdoll/timeframe"
require "ragdoll/tag"
require "ragdoll/document_tag"
require "ragdoll/embedding_tag"
require "ragdoll/tag_service"
require "ragdoll/proposition"
require "ragdoll/proposition_service"
require "ragdoll/hybrid_search_service"
# Require workflows from app/services/ragdoll/workflows
require "ragdoll/workflows/hybrid_search_workflow"
require "ragdoll/workflows/document_enrichment_workflow"
require "ragdoll/workflows/multi_modal_embedding_workflow"
# Require from app/lib/ragdoll
require "ragdoll/metadata_schemas"
# Require jobs from app/jobs/ragdoll
require "ragdoll/generate_embeddings_job"
require "ragdoll/generate_summary_job"
require "ragdoll/extract_keywords_job"
require "ragdoll/extract_text_job"
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
                   :add_directory, :stats, :healthy?, :hybrid_search,
                   :add_tags, :get_tags, :extract_propositions, :get_propositions,
                   :enrich_document, :embed_multimodal

    def self.default_client
      @default_client ||= Client.new
    end
  end
end
