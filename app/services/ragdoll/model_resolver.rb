# frozen_string_literal: true

require "ostruct"

module Ragdoll
  # Service for resolving models with provider/model parsing and inheritance
  class ModelResolver
    def initialize(config_service = nil)
      @config_service = config_service || Ragdoll::ConfigurationService.new
    end

    # Resolve model for a task, returns Model object
    def resolve_for_task(task_type, content_type = :text)
      model_string = @config_service.resolve_model(task_type, content_type)

      raise Ragdoll::Core::ConfigurationError, "No model configured for task '#{task_type}'" if model_string.nil?

      Ragdoll::Core::Model.new(model_string)
    end

    # Resolve embedding model for content type, returns Model object with metadata
    def resolve_embedding(content_type = :text)
      embedding_config = @config_service.embedding_config

      model_string = embedding_config[:model]

      raise Ragdoll::Core::ConfigurationError, "No embedding model configured for content type '#{content_type}'" if model_string.nil?

      model = Ragdoll::Core::Model.new(model_string)

      # Return object with model and embedding-specific metadata
      OpenStruct.new(
        model: model,
        provider_type: embedding_config[:provider],
        max_dimensions: embedding_config[:max_dimensions],
        cache_embeddings: embedding_config[:cache_embeddings]
      )
    end

    # Get provider credentials for a Model object
    def provider_credentials_for_model(model)
      provider = model.provider

      if provider.nil?
        # Use default provider if none specified
        provider = @config_service.config.default_provider
      end

      @config_service.provider_credentials(provider)
    end

    # Resolve all models for debugging/introspection
    def resolve_all_models
      {
        text_generation: {
          default: resolve_for_task(:default),
          summary: resolve_for_task(:summary),
          keywords: resolve_for_task(:keywords)
        },
        embedding: {
          text: resolve_embedding(:text)
        }
      }
    rescue Ragdoll::Core::ConfigurationError => e
      # Return partial results with error information
      { error: e.message, partial: true }
    end

    private

    attr_reader :config_service
  end
end
