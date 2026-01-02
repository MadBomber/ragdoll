# frozen_string_literal: true

require "anyway_config"
require "yaml"

require_relative "config/section"

module Ragdoll
  module Core
    # Ragdoll Configuration using Anyway Config
    #
    # Schema is defined in lib/ragdoll/core/config/defaults.yml (single source of truth)
    # Configuration uses nested sections for better organization:
    #   - Ragdoll.config.database.host
    #   - Ragdoll.config.embedding.provider
    #   - Ragdoll.config.providers.openai.api_key
    #
    # Configuration sources (lowest to highest priority):
    # 1. Bundled defaults: lib/ragdoll/core/config/defaults.yml (ships with gem)
    # 2. XDG user config:
    #    - ~/Library/Application Support/ragdoll/ragdoll.yml (macOS only)
    #    - ~/.config/ragdoll/ragdoll.yml (XDG default)
    #    - $XDG_CONFIG_HOME/ragdoll/ragdoll.yml (if XDG_CONFIG_HOME is set)
    # 3. Project config: ./config/ragdoll.yml (environment-specific)
    # 4. Local overrides: ./config/ragdoll.local.yml (gitignored)
    # 5. Environment variables (RAGDOLL_*)
    # 6. Explicit values passed to configure block
    #
    # @example Configure with environment variables
    #   export RAGDOLL_EMBEDDING__PROVIDER=openai
    #   export RAGDOLL_EMBEDDING__MODEL=text-embedding-3-small
    #   export RAGDOLL_PROVIDERS__OPENAI__API_KEY=sk-xxx
    #
    # @example Configure with XDG user config (~/.config/ragdoll/ragdoll.yml)
    #   embedding:
    #     provider: ollama
    #     model: nomic-embed-text:latest
    #   providers:
    #     ollama:
    #       url: http://localhost:11434
    #
    # @example Configure with Ruby block
    #   Ragdoll.configure do |config|
    #     config.embedding.provider = :openai
    #     config.embedding.model = 'text-embedding-3-small'
    #   end
    #
    class Config < Anyway::Config
      config_name :ragdoll
      env_prefix :ragdoll

      # ==========================================================================
      # Schema Definition (loaded from defaults.yml - single source of truth)
      # ==========================================================================

      # Path to bundled defaults file (defines both schema and default values)
      DEFAULTS_PATH = File.expand_path("config/defaults.yml", __dir__).freeze

      # Load schema from defaults.yml at class definition time
      begin
        defaults_content = File.read(DEFAULTS_PATH)
        raw_yaml = YAML.safe_load(
          defaults_content,
          permitted_classes: [Symbol],
          symbolize_names: true,
          aliases: true
        ) || {}
        SCHEMA = raw_yaml[:defaults] || {}
      rescue StandardError => e
        warn "Ragdoll: Could not load schema from #{DEFAULTS_PATH}: #{e.message}"
        SCHEMA = {}
      end

      # Nested section attributes (defined as hashes, converted to ConfigSection)
      attr_config :database, :embedding, :generation, :chunking, :search,
                  :analytics, :hybrid_search, :summarization, :tagging,
                  :propositions, :circuit_breaker, :timeframe, :logging,
                  :prompts, :providers

      # Custom environment detection: RAGDOLL_ENV > RAILS_ENV > RACK_ENV > 'development'
      class << self
        def env
          Anyway::Settings.current_environment ||
            ENV["RAGDOLL_ENV"] ||
            ENV["RAILS_ENV"] ||
            ENV["RACK_ENV"] ||
            "development"
        end
      end

      # ==========================================================================
      # Type Coercion
      # ==========================================================================

      TO_SYMBOL = ->(v) { v.nil? ? nil : v.to_s.to_sym }

      # Create a coercion that merges incoming value with SCHEMA defaults for a section.
      # This ensures env vars like RAGDOLL_DATABASE__URL don't lose other defaults.
      def self.config_section_with_defaults(section_key)
        defaults = SCHEMA[section_key] || {}
        ->(v) {
          return v if v.is_a?(ConfigSection)
          incoming = v || {}
          # Deep merge: defaults first, then overlay incoming values
          merged = deep_merge_hashes(defaults.dup, incoming)
          ConfigSection.new(merged)
        }
      end

      # Deep merge helper for coercion
      def self.deep_merge_hashes(base, overlay)
        base.merge(overlay) do |_key, old_val, new_val|
          if old_val.is_a?(Hash) && new_val.is_a?(Hash)
            deep_merge_hashes(old_val, new_val)
          else
            new_val.nil? ? old_val : new_val
          end
        end
      end

      coerce_types(
        # Nested sections -> ConfigSection objects (with SCHEMA defaults merged)
        database: config_section_with_defaults(:database),
        embedding: config_section_with_defaults(:embedding),
        generation: config_section_with_defaults(:generation),
        chunking: config_section_with_defaults(:chunking),
        search: config_section_with_defaults(:search),
        analytics: config_section_with_defaults(:analytics),
        hybrid_search: config_section_with_defaults(:hybrid_search),
        summarization: config_section_with_defaults(:summarization),
        tagging: config_section_with_defaults(:tagging),
        propositions: config_section_with_defaults(:propositions),
        circuit_breaker: config_section_with_defaults(:circuit_breaker),
        timeframe: config_section_with_defaults(:timeframe),
        logging: config_section_with_defaults(:logging),
        prompts: config_section_with_defaults(:prompts),
        providers: config_section_with_defaults(:providers)
      )

      # ==========================================================================
      # Default embedding dimensions by provider
      # ==========================================================================
      DEFAULT_DIMENSIONS = {
        openai: 1536,
        anthropic: 1024,
        gemini: 768,
        azure: 1536,
        ollama: 768,
        huggingface: 768,
        openrouter: 1536,
        bedrock: 1536,
        deepseek: 1536
      }.freeze

      on_load :coerce_nested_types, :setup_defaults

      # ==========================================================================
      # Instance Methods
      # ==========================================================================

      def initialize(...)
        super
        @ollama_models_refreshed = false
        @ollama_refresh_mutex = Mutex.new
      end

      # ==========================================================================
      # Convenience Accessors (for common nested values)
      # ==========================================================================

      # Embedding convenience accessors
      def embedding_provider
        provider = embedding.provider
        provider.is_a?(Symbol) ? provider : provider&.to_sym
      end

      def embedding_model
        embedding.model
      end

      def embedding_dimensions
        embedding.dimensions.to_i
      end

      def embedding_timeout
        embedding.timeout.to_i
      end

      def max_embedding_dimension
        embedding.max_dimensions.to_i
      end

      def cache_embeddings?
        embedding.cache_embeddings
      end

      # Generation convenience accessors
      def default_model
        generation.default_model
      end

      def summary_model
        generation.summary_model || default_model
      end

      def keywords_model
        generation.keywords_model || default_model
      end

      # Chunking convenience accessors
      def chunk_size
        chunking.size.to_i
      end

      def chunk_overlap
        chunking.overlap.to_i
      end

      # Search convenience accessors
      def similarity_threshold
        search.similarity_threshold.to_f
      end

      def max_results
        search.max_results.to_i
      end

      # Analytics convenience accessors
      def analytics_enabled?
        analytics.enabled
      end

      def usage_tracking?
        analytics.usage_tracking
      end

      # Hybrid search convenience accessors
      def hybrid_search_enabled?
        hybrid_search.enabled
      end

      def rrf_k
        hybrid_search.rrf_k.to_i
      end

      # Summarization convenience accessors
      def summarization_enabled?
        summarization.enabled
      end

      # Tagging convenience accessors
      def tagging_enabled?
        tagging.enabled
      end

      def auto_extract_tags?
        tagging.auto_extract
      end

      def max_tag_depth
        tagging.max_depth.to_i
      end

      # Propositions convenience accessors
      def propositions_enabled?
        propositions.enabled
      end

      def auto_extract_propositions?
        propositions.auto_extract
      end

      # Circuit breaker convenience accessors
      def circuit_breaker_failure_threshold
        circuit_breaker.failure_threshold.to_i
      end

      def circuit_breaker_reset_timeout
        circuit_breaker.reset_timeout.to_i
      end

      def circuit_breaker_half_open_max_calls
        circuit_breaker.half_open_max_calls.to_i
      end

      # Timeframe convenience accessors
      def week_start
        (timeframe.week_start || "sunday").to_sym
      end

      def default_recent_days
        timeframe.default_recent_days.to_i
      end

      # Logging convenience accessor
      def log_level
        (logging.level || "info").to_sym
      end

      # Prompt template accessor
      def prompt_template(name = :rag_enhancement)
        prompts[name]
      end

      # Provider credential convenience accessors
      def default_provider
        (providers.default_provider || "openai").to_sym
      end

      def openai_api_key
        providers.openai&.api_key
      end

      def openai_organization
        providers.openai&.organization
      end

      def openai_project
        providers.openai&.project
      end

      def anthropic_api_key
        providers.anthropic&.api_key
      end

      def gemini_api_key
        providers.gemini&.api_key
      end

      def google_api_key
        providers.google&.api_key
      end

      def google_project_id
        providers.google&.project_id
      end

      def azure_api_key
        providers.azure&.api_key
      end

      def azure_endpoint
        providers.azure&.endpoint
      end

      def azure_api_version
        providers.azure&.api_version
      end

      def ollama_url
        providers.ollama&.url || "http://localhost:11434"
      end

      def huggingface_api_key
        providers.huggingface&.api_key
      end

      def openrouter_api_key
        providers.openrouter&.api_key
      end

      def bedrock_access_key
        providers.bedrock&.access_key
      end

      def bedrock_secret_key
        providers.bedrock&.secret_key
      end

      def bedrock_region
        providers.bedrock&.region || "us-east-1"
      end

      def deepseek_api_key
        providers.deepseek&.api_key
      end

      # Get credentials for a specific provider
      def provider_credentials(provider_name = nil)
        provider_name ||= default_provider
        provider_name = provider_name.to_sym
        providers[provider_name]&.to_h || {}
      end

      # ==========================================================================
      # Database Configuration Helpers
      # ==========================================================================

      # Build ActiveRecord compatible database configuration hash
      def database_config
        {
          adapter: database.adapter || "postgresql",
          host: database.host || "localhost",
          port: database.port || 5432,
          database: database.name,
          username: database.user,
          password: database.password,
          pool: database.pool_size || 5,
          timeout: database.timeout || 5000,
          sslmode: database.sslmode
        }.compact
      end

      def auto_migrate?
        database.auto_migrate
      end

      # ==========================================================================
      # Environment Helpers
      # ==========================================================================

      def test?
        self.class.env == "test"
      end

      def development?
        self.class.env == "development"
      end

      def production?
        self.class.env == "production"
      end

      def environment
        self.class.env
      end

      # ==========================================================================
      # Environment Validation
      # ==========================================================================

      # Returns list of valid environment names from bundled defaults
      #
      # @return [Array<Symbol>] valid environment names (e.g., [:development, :production, :test])
      def self.valid_environments
        Ragdoll::Core::Loaders::DefaultsLoader.valid_environments
      end

      # Check if current environment is valid (defined in config)
      #
      # @return [Boolean] true if environment has a config section
      def self.valid_environment?
        Ragdoll::Core::Loaders::DefaultsLoader.valid_environment?(env)
      end

      # Validate that the current environment is configured
      #
      # @raise [Ragdoll::Core::ConfigurationError] if environment is invalid
      # @return [true] if environment is valid
      def self.validate_environment!
        current = env
        return true if Ragdoll::Core::Loaders::DefaultsLoader.valid_environment?(current)

        valid = valid_environments.map(&:to_s).join(", ")
        raise Ragdoll::Core::ConfigurationError,
          "Invalid environment '#{current}'. " \
          "Valid environments are: #{valid}. " \
          "Set RAGDOLL_ENV to a valid environment or add a '#{current}:' section to your config."
      end

      # Instance method delegates
      def valid_environment?
        self.class.valid_environment?
      end

      def validate_environment!
        self.class.validate_environment!
      end

      # ==========================================================================
      # XDG Config Path Helpers
      # ==========================================================================

      def self.xdg_config_paths
        Ragdoll::Core::Loaders::XdgConfigLoader.config_paths
      end

      def self.xdg_config_file
        xdg_home = ENV["XDG_CONFIG_HOME"]
        base = if xdg_home && !xdg_home.empty?
          xdg_home
        else
          File.expand_path("~/.config")
        end
        File.join(base, "ragdoll", "ragdoll.yml")
      end

      def self.active_xdg_config_file
        Ragdoll::Core::Loaders::XdgConfigLoader.find_config_file("ragdoll")
      end

      # ==========================================================================
      # Ollama Helpers
      # ==========================================================================

      def normalize_ollama_model(model_name)
        return model_name if model_name.nil? || model_name.empty?
        return model_name if model_name.include?(":")

        "#{model_name}:latest"
      end

      def configure_ruby_llm(provider = nil)
        require "ruby_llm"

        provider ||= embedding_provider

        RubyLLM.configure do |config|
          case provider
          when :openai
            config.openai_api_key = openai_api_key if openai_api_key
            config.openai_organization = openai_organization if openai_organization && config.respond_to?(:openai_organization=)
            config.openai_project = openai_project if openai_project && config.respond_to?(:openai_project=)
          when :anthropic
            config.anthropic_api_key = anthropic_api_key if anthropic_api_key
          when :gemini
            config.gemini_api_key = gemini_api_key if gemini_api_key
          when :azure
            config.azure_api_key = azure_api_key if azure_api_key && config.respond_to?(:azure_api_key=)
            config.azure_endpoint = azure_endpoint if azure_endpoint && config.respond_to?(:azure_endpoint=)
            config.azure_api_version = azure_api_version if azure_api_version && config.respond_to?(:azure_api_version=)
          when :ollama
            ollama_api_base = if ollama_url.end_with?("/v1") || ollama_url.end_with?("/v1/")
              ollama_url.sub(%r{/+$}, "")
            else
              "#{ollama_url.sub(%r{/+$}, '')}/v1"
            end
            config.ollama_api_base = ollama_api_base
          when :huggingface
            config.huggingface_api_key = huggingface_api_key if huggingface_api_key && config.respond_to?(:huggingface_api_key=)
          when :openrouter
            config.openrouter_api_key = openrouter_api_key if openrouter_api_key && config.respond_to?(:openrouter_api_key=)
          when :bedrock
            config.bedrock_api_key = bedrock_access_key if bedrock_access_key && config.respond_to?(:bedrock_api_key=)
            config.bedrock_secret_key = bedrock_secret_key if bedrock_secret_key && config.respond_to?(:bedrock_secret_key=)
            config.bedrock_region = bedrock_region if bedrock_region && config.respond_to?(:bedrock_region=)
          when :deepseek
            config.deepseek_api_key = deepseek_api_key if deepseek_api_key && config.respond_to?(:deepseek_api_key=)
          end
        end
      end

      def refresh_ollama_models!
        @ollama_refresh_mutex.synchronize do
          unless @ollama_models_refreshed
            require "ruby_llm"
            RubyLLM.models.refresh!
            @ollama_models_refreshed = true
          end
        end
      end

      # ==========================================================================
      # Backward Compatibility Methods (for old Configuration API)
      # ==========================================================================

      # These methods provide the old hash-based API for backward compatibility
      # @deprecated Use the new method-based API instead

      def models
        @models_compat ||= build_models_compat
      end

      def processing
        @processing_compat ||= build_processing_compat
      end

      def llm_providers
        @llm_providers_compat ||= build_llm_providers_compat
      end

      def base_directory
        File.join(Dir.home, ".config", "ragdoll")
      end

      def config_filepath
        File.join(base_directory, "config.yml")
      end

      def prompt_templates
        @prompt_templates_compat ||= {
          rag_enhancement: @prompts&.rag_enhancement || prompt_template(:rag_enhancement)
        }
      end

      private

      def build_models_compat
        {
          text_generation: {
            default: default_model ? Core::Model.new(default_model) : nil,
            summary: summary_model ? Core::Model.new(summary_model) : nil,
            keywords: keywords_model ? Core::Model.new(keywords_model) : nil
          },
          embedding: {
            provider: embedding_provider,
            text: embedding_model ? Core::Model.new(embedding_model) : nil,
            image: nil,
            audio: nil,
            max_dimensions: max_embedding_dimension,
            cache_embeddings: cache_embeddings?
          }
        }
      end

      def build_processing_compat
        {
          text: {
            chunking: {
              max_tokens: chunk_size,
              overlap: chunk_overlap
            }
          },
          default: {
            chunking: {
              max_tokens: 4096,
              overlap: 128
            }
          },
          search: {
            similarity_threshold: similarity_threshold,
            max_results: max_results,
            analytics: {
              enable: analytics_enabled?,
              usage_tracking_enabled: usage_tracking?,
              ranking_enabled: analytics.ranking_enabled,
              recency_weight: analytics.recency_weight,
              frequency_weight: analytics.frequency_weight,
              similarity_weight: analytics.similarity_weight
            }
          }
        }
      end

      def build_llm_providers_compat
        result = {
          default_provider: default_provider,
          openai: providers.openai&.to_h || {},
          anthropic: providers.anthropic&.to_h || {},
          google: providers.google&.to_h || {},
          azure: providers.azure&.to_h || {},
          ollama: providers.ollama&.to_h || {},
          huggingface: providers.huggingface&.to_h || {},
          openrouter: providers.openrouter&.to_h || {}
        }
        # Add endpoint alias for ollama
        result[:ollama][:endpoint] = ollama_url if result[:ollama]
        result
      end

      public

      # ==========================================================================
      # Type Coercion Callback
      # ==========================================================================

      def coerce_nested_types
        # Ensure nested provider sections are ConfigSections
        if providers.is_a?(ConfigSection)
          %i[openai anthropic gemini google azure ollama huggingface openrouter bedrock deepseek].each do |provider|
            value = providers[provider]
            providers[provider] = ConfigSection.new(value) if value.is_a?(Hash)
          end
        end

        # Coerce database numeric fields to integers (env vars are always strings)
        if database&.port && !database.port.is_a?(Integer)
          database.port = database.port.to_i
        end
        if database&.pool_size && !database.pool_size.is_a?(Integer)
          database.pool_size = database.pool_size.to_i
        end
        if database&.timeout && !database.timeout.is_a?(Integer)
          database.timeout = database.timeout.to_i
        end
      end

      # ==========================================================================
      # Setup Defaults Callback
      # ==========================================================================

      def setup_defaults
        # Any additional runtime defaults setup can go here
      end
    end
  end
end

# Register custom loaders after Config class is defined
# Order matters: defaults (lowest priority) -> XDG -> project config -> ENV (highest)
require_relative "loaders/defaults_loader"
require_relative "loaders/xdg_config_loader"

module Ragdoll
  module Core
    # Backward compatibility alias - Configuration is now Config
    # @deprecated Use Config instead
    Configuration = Config
  end
end
