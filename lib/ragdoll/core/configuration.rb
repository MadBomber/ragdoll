# frozen_string_literal: true

require "yaml"
require "fileutils"
require "ostruct"
require_relative "model"

module Ragdoll
  module Core
    class Configuration
      class ConfigurationFileNotFoundError < StandardError; end
      class ConfigurationSaveError < StandardError; end
      class ConfigurationLoadUnknownError < StandardError; end

      DEFAULT = {
        # Base directory for all Ragdoll files - single source of truth
        base_directory: File.join(Dir.home, ".config", "ragdoll"),

        # Configuration file path derived from base directory
        config_filepath: File.join(Dir.home, ".config", "ragdoll", "config.yml"),

        # Model configurations organized by purpose with inheritance support
        models: {
          text_generation: {
            default: -> { Model.new(ENV["RAGDOLL_DEFAULT_TEXT_MODEL"] || "openai/gpt-4o") },
            summary: -> { Model.new(ENV["RAGDOLL_SUMMARY_MODEL"] || "openai/gpt-4o") },
            keywords: -> { Model.new(ENV["RAGDOLL_KEYWORDS_MODEL"] || "openai/gpt-4o") }
          },
          embedding: {
            provider: :openai,
            text: -> { Model.new(ENV["RAGDOLL_TEXT_EMBEDDING_MODEL"] || "openai/text-embedding-3-small") },
            image: -> { Model.new(ENV["RAGDOLL_IMAGE_EMBEDDING_MODEL"] || "openai/clip-vit-base-patch32") },
            audio: -> { Model.new(ENV["RAGDOLL_AUDIO_EMBEDDING_MODEL"] || "openai/whisper-1") },
            max_dimensions: 3072,
            cache_embeddings: true
          }
        },

        # Processing configuration by content type
        processing: {
          text: {
            chunking: {
              max_tokens: 1000,
              overlap: 200
            }
          },
          default: {
            chunking: {
              max_tokens: 4096,
              overlap: 128
            }
          },
          search: {
            similarity_threshold: 0.7,
            max_results: 10,
            analytics: {
              enable: true,
              usage_tracking_enabled: true,
              ranking_enabled: true,
              recency_weight: 0.3,
              frequency_weight: 0.7,
              similarity_weight: 1.0
            }
          }
        },

        # LLM provider configurations (renamed from ruby_llm_config)
        llm_providers: {
          default_provider: :openai,
          openai: {
            api_key: -> { ENV["OPENAI_API_KEY"] },
            organization: -> { ENV["OPENAI_ORGANIZATION"] },
            project: -> { ENV["OPENAI_PROJECT"] }
          },
          anthropic: {
            api_key: -> { ENV["ANTHROPIC_API_KEY"] }
          },
          google: {
            api_key: -> { ENV["GOOGLE_API_KEY"] },
            project_id: -> { ENV["GOOGLE_PROJECT_ID"] }
          },
          azure: {
            api_key: -> { ENV["AZURE_OPENAI_API_KEY"] },
            endpoint: -> { ENV["AZURE_OPENAI_ENDPOINT"] },
            api_version: -> { ENV["AZURE_OPENAI_API_VERSION"] || "2024-02-01" }
          },
          ollama: {
            endpoint: -> { ENV["OLLAMA_ENDPOINT"] || "http://localhost:11434" }
          },
          huggingface: {
            api_key: -> { ENV["HUGGINGFACE_API_KEY"] }
          },
          openrouter: {
            api_key: -> { ENV["OPENROUTER_API_KEY"] }
          }
        },

        # Summarization configuration
        summarization: {
          enable: true,
          max_length: 300,
          min_content_length: 300
        },

        # Database configuration with standardized ENV variable name
        database: {
          adapter: "postgresql",
          database: "ragdoll_development",
          username: "ragdoll",
          password: -> { ENV["RAGDOLL_DATABASE_PASSWORD"] }, # Fixed ENV variable name
          host: "localhost",
          port: 5432,
          auto_migrate: true,
          logger: nil
        },

        # Logging configuration with corrected key names and path derivation
        logging: {
          level: :warn, # Fixed: was log_level, now matches usage
          directory: File.join(Dir.home, ".config", "ragdoll", "logs"),
          filepath: File.join(Dir.home, ".config", "ragdoll", "logs", "ragdoll.log")
        },

        # Prompt templates for customizable text generation
        prompt_templates: {
          rag_enhancement: <<~TEMPLATE.strip
            You are an AI assistant. Use the following context to help answer the user's question.
            If the context doesn't contain relevant information, say so.

            Context:
            {{context}}

            Question: {{prompt}}

            Answer:
          TEMPLATE
        }

      }.freeze

      def initialize(config = {})
        merged_config = deep_merge(self.class::DEFAULT, config)
        resolved_config = resolve_procs(merged_config, [])
        @config = OpenStruct.new(resolved_config)
      end

      def self.load(path: nil)
        path ||= DEFAULT[:config_filepath]

        raise ConfigurationFileNotFoundError, "Configuration file not found: #{path}" unless File.exist?(path)

        new(YAML.safe_load_file(path) || {})
      rescue Errno::ENOENT
        raise ConfigurationFileNotFoundError, "Configuration file not found: #{path}"
      rescue StandardError => e
        raise ConfigurationLoadUnknownError, "Failed to load configuration from #{path}: #{e.message}"
      end

      def save(path: nil)
        if path.nil?
          path = @config.config_filepath
        else
          save_filepath = @config.config_filepath
          @config.config_filepath = path
        end

        FileUtils.mkdir_p(File.dirname(path))

        File.write(path, @config.to_yaml)
      rescue StandardError => e
        @config.config_filepath = save_filepath unless save_filepath.nil?
        raise ConfigurationSaveError, "Failed to save configuration to #{path}: #{e.message}"
      end

      # SMELL: isn't this method more of a utility?

      # Parse a provider/model string into its components
      # Format: "provider/model" -> { provider: :provider, model: "model" }
      # Format: "model" -> { provider: nil, model: "model" } (RubyLLM determines provider)
      def parse_provider_model(provider_model_string)
        return { provider: nil, model: nil } if provider_model_string.nil? || provider_model_string.empty?

        parts = provider_model_string.split("/", 2)
        if parts.length == 2
          { provider: parts[0].to_sym, model: parts[1] }
        else
          # If no slash, let RubyLLM determine provider from model name
          { provider: nil, model: provider_model_string }
        end
      end

      # Resolve model with inheritance support
      # Returns the model string for a given task, with inheritance from default
      def resolve_model(task_type)
        case task_type
        when :embedding
          @config.models[:embedding]
        when :text, :summary, :keywords, :default
          @config.models[:text_generation][task_type] || @config.models[:text_generation][:default]
        else
          @config.models[:text_generation][:default]
        end
      end

      # Get provider credentials for a given provider
      def provider_credentials(provider = nil)
        provider ||= @config.llm_providers[:default_provider]
        @config.llm_providers[provider] || {}
      end

      # Resolve embedding model for content type
      def embedding_model(content_type = :text)
        @config.models[:embedding][content_type] || @config.models[:embedding][:text]
      end

      # Get prompt template
      def prompt_template(template_name = :rag_enhancement)
        @config.prompt_templates[template_name]
      end

      # Enable method delegation to the internal OpenStruct
      def method_missing(method_name, *args, &block)
        @config.send(method_name, *args, &block)
      end

      def respond_to_missing?(method_name, include_private = false)
        @config.respond_to?(method_name, include_private) || super
      end

      private

      def resolve_procs(obj, path = [])
        case obj
        when Hash
          obj.each_with_object({}) { |(k, v), result| result[k] = resolve_procs(v, path + [k]) }
        when Proc
          obj.call
        when String
          # Convert strings to Model instances in the models configuration section
          if path.length >= 2 && path[0] == :models
            Model.new(obj)
          else
            obj
          end
        else
          obj
        end
      end

      def deep_merge(hash1, hash2)
        hash1.merge(hash2) do |_key, oldval, newval|
          oldval.is_a?(Hash) && newval.is_a?(Hash) ? deep_merge(oldval, newval) : newval
        end
      end
    end
  end
end
