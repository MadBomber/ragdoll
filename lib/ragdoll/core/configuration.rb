# frozen_string_literal: true

require "yaml"
require "fileutils"
require "ostruct"

module Ragdoll
  module Core
    class Configuration
      class ConfigurationFileNotFoundError < StandardError; end
      class ConfigurationSaveError < StandardError; end
      class ConfigurationLoadUnknownError < StandardError; end

      DEFAULT = {
        directory: File.join(Dir.home, ".ragdoll"),
        filepath: File.join(Dir.home, ".ragdoll", "config.yml"),
        models: {
          default: "openai/gpt-4o",
          summary: "openai/gpt-4o",
          keywords: "openai/gpt-4o",
          embedding: {
            text: "openai/text-embedding-3-small",
            image: "openai/clip-vit-base-patch32",
            audio: "openai/whisper-1"
          }
        },
        chunking: {
          text: {
            max_tokens: 1000,
            overlap: 200
          },
          image: {
            max_tokens: 4096,
            overlap: 128
          },
          audio: {
            max_tokens: 4096,
            overlap: 128
          },
          default: {
            max_tokens: 4096,
            overlap: 128
          }
        },
        ruby_llm_config: {
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
        embedding_config: {
          provider: :openai,
          cache_embeddings: true,
          max_embedding_dimensions: 3072 # Support up to text-embedding-3-large
        },
        summarization_config: {
          enable: true,
          max_length: 300,
          min_content_length: 300
        },
        database_config: {
          adapter: "postgresql",
          database: "ragdoll_development",
          username: "ragdoll",
          password: -> { ENV["DATABASE_PASSWORD"] },
          host: "localhost",
          port: 5432,
          auto_migrate: true,
          logger: nil # Set to Logger.new(STDOUT) for debugging
        },
        logging_config: {
          log_level: :warn,
          log_directory: File.join(Dir.home, ".ragdoll"),
          log_filepath: File.join(Dir.home, ".ragdoll", "ragdoll.log")
        },
        search: {
          similarity_threshold: 0.7,
          max_results: 10,
          enable_analytics: true,
          enable_usage_tracking: true,
          usage_ranking_enabled: true,
          usage_recency_weight: 0.3,
          usage_frequency_weight: 0.7,
          usage_similarity_weight: 1.0
        }
      }

      def initialize(config = {})
        merged_config = deep_merge(self.class::DEFAULT, config)
        resolved_config = resolve_procs(merged_config)
        @config = OpenStruct.new(resolved_config)
      end

      def self.load(path: nil)
        path ||= DEFAULT[:filepath]

        raise ConfigurationFileNotFoundError, "Configuration file not found: #{path}" unless File.exist?(path)

        new(YAML.safe_load_file(path) || {})
      rescue Errno::ENOENT
        raise ConfigurationFileNotFoundError, "Configuration file not found: #{path}"
      rescue StandardError => e
        raise ConfigurationLoadUnknownError, "Failed to load configuration from #{path}: #{e.message}"
      end

      def save(path: nil)
        if path.nil?
          path = @config.filepath
        else
          save_filepath = @config.filepath
          @config.filepath = path
        end

        FileUtils.mkdir_p(File.dirname(path))

        File.write(path, @config.to_yaml)
      rescue StandardError => e
        @config.filepath = save_filepath unless save_filepath.nil?
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

      # Enable method delegation to the internal OpenStruct
      def method_missing(method_name, *args, &block)
        @config.send(method_name, *args, &block)
      end

      def respond_to_missing?(method_name, include_private = false)
        @config.respond_to?(method_name, include_private) || super
      end

      private

      def resolve_procs(obj)
        case obj
        when Hash
          obj.transform_values { |v| resolve_procs(v) }
        when Proc
          obj.call
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
