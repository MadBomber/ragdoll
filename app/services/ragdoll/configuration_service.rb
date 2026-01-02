# frozen_string_literal: true

module Ragdoll
  # Service class for centralized configuration logic
  # Provides a clean interface for accessing configuration with validation
  #
  # This is a compatibility wrapper around the new anyway_config-based Config class.
  # It provides method-based access to configuration values and validation.
  #
  class ConfigurationService
    def initialize(config = nil)
      @config = config || Ragdoll.config
    end

    # Expose config as a public method for backward compatibility
    attr_reader :config

    # Resolve model for a task with inheritance support
    def resolve_model(task_type, content_type = :text)
      case task_type
      when :embedding
        @config.embedding_model
      when :summary
        @config.summary_model
      when :keywords
        @config.keywords_model
      else
        @config.default_model
      end
    end

    # Get provider credentials with fallback to default provider
    def provider_credentials(provider = nil)
      provider ||= @config.default_provider
      credentials = @config.provider_credentials(provider)

      if credentials.nil? || credentials.empty?
        raise Ragdoll::Core::ConfigurationError, "Provider '#{provider}' not configured"
      end

      credentials
    end

    # Get chunking configuration
    def chunking_config(_content_type = :text)
      {
        max_tokens: @config.chunk_size,
        overlap: @config.chunk_overlap
      }
    end

    # Get search configuration
    def search_config
      {
        similarity_threshold: @config.similarity_threshold,
        max_results: @config.max_results,
        analytics: {
          enable: @config.analytics_enabled?,
          usage_tracking_enabled: @config.usage_tracking?,
          ranking_enabled: @config.analytics.ranking_enabled,
          recency_weight: @config.analytics.recency_weight,
          frequency_weight: @config.analytics.frequency_weight,
          similarity_weight: @config.analytics.similarity_weight
        }
      }
    end

    # Get prompt template with validation
    def prompt_template(template_name = :rag_enhancement)
      template = @config.prompt_template(template_name)

      if template.nil?
        raise Ragdoll::Core::ConfigurationError, "Prompt template '#{template_name}' not found"
      end

      template
    end

    # Get embedding configuration
    def embedding_config
      {
        provider: @config.embedding_provider,
        model: @config.embedding_model,
        dimensions: @config.embedding_dimensions,
        timeout: @config.embedding_timeout,
        max_dimensions: @config.max_embedding_dimension,
        cache_embeddings: @config.cache_embeddings?
      }
    end

    # Get database configuration
    def database_config
      @config.database_config
    end

    # Get circuit breaker configuration
    def circuit_breaker_config
      {
        failure_threshold: @config.circuit_breaker_failure_threshold,
        reset_timeout: @config.circuit_breaker_reset_timeout,
        half_open_max_calls: @config.circuit_breaker_half_open_max_calls
      }
    end

    # Get hybrid search configuration
    def hybrid_search_config
      {
        enabled: @config.hybrid_search_enabled?,
        rrf_k: @config.rrf_k,
        candidate_multiplier: @config.hybrid_search.candidate_multiplier,
        weights: {
          semantic: @config.hybrid_search.semantic_weight,
          fulltext: @config.hybrid_search.fulltext_weight,
          tags: @config.hybrid_search.tags_weight
        }
      }
    end

    # Get tagging configuration
    def tagging_config
      {
        enabled: @config.tagging_enabled?,
        max_depth: @config.max_tag_depth,
        auto_extract: @config.auto_extract_tags?,
        tag_documents: @config.tagging.tag_documents,
        tag_chunks: @config.tagging.tag_chunks
      }
    end

    # Get propositions configuration
    def propositions_config
      {
        enabled: @config.propositions_enabled?,
        auto_extract: @config.auto_extract_propositions?,
        min_length: @config.propositions.min_length,
        max_length: @config.propositions.max_length,
        min_words: @config.propositions.min_words
      }
    end

    # Validate configuration completeness
    def validate!
      errors = []

      # Check default LLM provider configuration for non-ollama providers
      default_provider = @config.default_provider
      if default_provider.nil?
        errors << "Default LLM provider not specified"
      elsif default_provider != :ollama
        credentials = @config.provider_credentials(default_provider)
        if credentials.nil? || credentials.empty?
          errors << "Default provider '#{default_provider}' not configured"
        elsif credentials[:api_key].nil?
          errors << "API key for default provider '#{default_provider}' not configured"
        end
      end

      unless errors.empty?
        raise Ragdoll::Core::ConfigurationError, "Configuration validation failed:\n  - #{errors.join("\n  - ")}"
      end

      true
    end

    # Check if configuration is valid without raising
    def valid?
      validate!
      true
    rescue Ragdoll::Core::ConfigurationError
      false
    end
  end
end
