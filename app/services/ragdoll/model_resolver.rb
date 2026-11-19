# frozen_string_literal: true

require "ostruct"

module Ragdoll
  # Model resolution service with provider/model parsing
  #
  # Resolves the appropriate LLM model for different task types (embedding,
  # summarization, keyword extraction) based on configuration. Handles model
  # string parsing and provider credential lookup.
  #
  # @example Resolve model for embedding
  #   resolver = Ragdoll::ModelResolver.new
  #   config = resolver.resolve_embedding(:text)
  #   config.model.model  # => "nomic-embed-text:latest"
  #
  # @example Get credentials for a model
  #   model = resolver.resolve_for_task(:summary)
  #   creds = resolver.provider_credentials_for_model(model)
  #
  class ModelResolver
    # Initialize the model resolver
    #
    # @param config_service [Ragdoll::ConfigurationService, nil] Configuration service
    #
    def initialize(config_service = nil)
      @config_service = config_service || Ragdoll::ConfigurationService.new
    end

    # Resolve model for a task type
    #
    # @param task_type [Symbol] Task type (:embedding, :summary, :keywords, :default)
    # @param content_type [Symbol] Content type (unused, for future expansion)
    # @return [Ragdoll::Core::Model] Parsed model object
    # @raise [Ragdoll::Core::ConfigurationError] If no model configured
    #
    def resolve_for_task(task_type, content_type = :text)
      model_string = @config_service.resolve_model(task_type, content_type)

      raise Ragdoll::Core::ConfigurationError, "No model configured for task '#{task_type}'" if model_string.nil?

      Ragdoll::Core::Model.new(model_string)
    end

    # Resolve embedding model with full configuration metadata
    #
    # @param content_type [Symbol] Content type (:text, :image, etc.)
    # @return [OpenStruct] Object with :model, :provider_type, :max_dimensions, :cache_embeddings
    # @raise [Ragdoll::Core::ConfigurationError] If no embedding model configured
    #
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

    # Get provider credentials for a resolved model
    #
    # @param model [Ragdoll::Core::Model] Model object with provider info
    # @return [Hash] Provider credentials (api_key, etc.)
    #
    def provider_credentials_for_model(model)
      provider = model.provider

      if provider.nil?
        # Use default provider if none specified
        provider = @config_service.config.default_provider
      end

      @config_service.provider_credentials(provider)
    end

    # Resolve all configured models for debugging/introspection
    #
    # @return [Hash] All resolved models by category, or partial results with error
    #
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
