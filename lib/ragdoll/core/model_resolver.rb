# frozen_string_literal: true

module Ragdoll
  module Core
    # Service for resolving models with provider/model parsing and inheritance
    class ModelResolver
      def initialize(config_service = nil)
        @config_service = config_service || ConfigurationService.new
      end

      # Resolve model for a task with full provider/model parsing
      def resolve_for_task(task_type, content_type = :text)
        model_string = @config_service.resolve_model(task_type, content_type)
        
        if model_string.nil?
          raise ConfigurationError, "No model configured for task '#{task_type}'"
        end

        parse_model_string(model_string)
      end

      # Resolve embedding model for content type
      def resolve_embedding(content_type = :text)
        embedding_config = @config_service.config.models[:embedding]
        model_string = embedding_config[content_type]

        if model_string.nil?
          raise ConfigurationError, "No embedding model configured for content type '#{content_type}'"
        end

        parsed = parse_model_string(model_string)
        
        # Add embedding-specific metadata
        parsed.merge(
          provider_type: embedding_config[:provider],
          max_dimensions: embedding_config[:max_dimensions],
          cache_embeddings: embedding_config[:cache_embeddings]
        )
      end

      # Get provider credentials for a resolved model
      def provider_credentials_for_model(resolved_model)
        provider = resolved_model[:provider]
        
        if provider.nil?
          # Use default provider if none specified
          provider = @config_service.config.llm_providers[:default_provider]
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
            text: resolve_embedding(:text),
            image: resolve_embedding(:image),
            audio: resolve_embedding(:audio)
          }
        }
      rescue ConfigurationError => e
        # Return partial results with error information
        { error: e.message, partial: true }
      end

      private

      attr_reader :config_service

      # Parse provider/model string with enhanced error handling
      def parse_model_string(model_string)
        return { provider: nil, model: nil, error: "Model string is nil or empty" } if model_string.nil? || model_string.empty?

        parts = model_string.split("/", 2)
        
        if parts.length == 2
          {
            provider: parts[0].to_sym,
            model: parts[1],
            full_name: model_string,
            has_explicit_provider: true
          }
        else
          {
            provider: nil,
            model: model_string,
            full_name: model_string,
            has_explicit_provider: false
          }
        end
      end
    end
  end
end