# frozen_string_literal: true

module Ragdoll
  # Centralized configuration access with validation
  #
  # Provides a clean interface for accessing Ragdoll configuration values.
  # Acts as a compatibility wrapper around the anyway_config-based Config class,
  # offering method-based access to configuration with validation and defaults.
  #
  # @example Access configuration
  #   service = Ragdoll::ConfigurationService.new
  #   service.embedding_config[:provider]  # => :ollama
  #   service.search_config[:max_results]  # => 10
  #
  # @example Validate configuration
  #   service.validate!  # raises ConfigurationError if invalid
  #   service.valid?     # => true/false
  #
  class ConfigurationService
    # Initialize with optional custom config
    #
    # @param config [Ragdoll::Core::Config, nil] Custom config or use global
    #
    def initialize(config = nil)
      @config = config || Ragdoll.config
    end

    # @return [Ragdoll::Core::Config] The underlying configuration object
    attr_reader :config

    # Resolve the appropriate model for a task type
    #
    # @param task_type [Symbol] Task type (:embedding, :summary, :keywords)
    # @param content_type [Symbol] Content type (unused, for future expansion)
    # @return [String] Model identifier
    #
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
    #
    # @param provider [Symbol, nil] Provider name or nil for default
    # @return [Hash] Provider credentials
    # @raise [Ragdoll::Core::ConfigurationError] If provider not configured
    #
    def provider_credentials(provider = nil)
      provider ||= @config.default_provider
      credentials = @config.provider_credentials(provider)

      if credentials.nil? || credentials.empty?
        raise Ragdoll::Core::ConfigurationError, "Provider '#{provider}' not configured"
      end

      credentials
    end

    # Get chunking configuration for text processing
    #
    # @param _content_type [Symbol] Content type (reserved for future use)
    # @return [Hash] Chunking config with :max_tokens and :overlap
    #
    def chunking_config(_content_type = :text)
      {
        max_tokens: @config.chunk_size,
        overlap: @config.chunk_overlap
      }
    end

    # Get search configuration including analytics settings
    #
    # @return [Hash] Search config with :similarity_threshold, :max_results, :analytics
    #
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

    # Get a named prompt template
    #
    # @param template_name [Symbol] Template name (default: :rag_enhancement)
    # @return [String] Prompt template string
    # @raise [Ragdoll::Core::ConfigurationError] If template not found
    #
    def prompt_template(template_name = :rag_enhancement)
      template = @config.prompt_template(template_name)

      if template.nil?
        raise Ragdoll::Core::ConfigurationError, "Prompt template '#{template_name}' not found"
      end

      template
    end

    # Get embedding configuration
    #
    # @return [Hash] Embedding config with :provider, :model, :dimensions, :timeout, etc.
    #
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
    #
    # @return [Hash] Database connection configuration
    #
    def database_config
      @config.database_config
    end

    # Get circuit breaker configuration for resilience
    #
    # @return [Hash] Circuit breaker config with :failure_threshold, :reset_timeout, etc.
    #
    def circuit_breaker_config
      {
        failure_threshold: @config.circuit_breaker_failure_threshold,
        reset_timeout: @config.circuit_breaker_reset_timeout,
        half_open_max_calls: @config.circuit_breaker_half_open_max_calls
      }
    end

    # Get hybrid search configuration (RRF fusion settings)
    #
    # @return [Hash] Hybrid search config with :enabled, :rrf_k, :weights
    #
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
    #
    # @return [Hash] Tagging config with :enabled, :max_depth, :auto_extract
    #
    def tagging_config
      {
        enabled: @config.tagging_enabled?,
        max_depth: @config.max_tag_depth,
        auto_extract: @config.auto_extract_tags?,
        tag_documents: @config.tagging.tag_documents,
        tag_chunks: @config.tagging.tag_chunks
      }
    end

    # Get propositions extraction configuration
    #
    # @return [Hash] Propositions config with :enabled, :min_length, :max_length
    #
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
    #
    # @return [Boolean] true if valid
    # @raise [Ragdoll::Core::ConfigurationError] If validation fails
    #
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
    #
    # @return [Boolean] true if configuration is valid
    #
    def valid?
      validate!
      true
    rescue Ragdoll::Core::ConfigurationError
      false
    end
  end
end
