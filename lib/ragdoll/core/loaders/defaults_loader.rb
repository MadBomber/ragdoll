# frozen_string_literal: true

require "anyway_config"
require "yaml"

module Ragdoll
  module Core
    module Loaders
      # Bundled Defaults Loader for Anyway Config
      #
      # Loads default configuration values from a YAML file bundled with the gem.
      # This ensures defaults are always available regardless of where Ragdoll is installed.
      #
      # The defaults.yml file has this structure:
      #   defaults:      # Base values for all environments
      #     database:
      #       host: localhost
      #       port: 5432
      #   development:   # Overrides for development
      #     database:
      #       name: ragdoll_development
      #   test:          # Overrides for test
      #     database:
      #       name: ragdoll_test
      #   production:    # Overrides for production
      #     database:
      #       sslmode: require
      #
      # This loader deep-merges `defaults` with the current environment's overrides.
      #
      # This loader runs at LOWEST priority (before XDG), so all other sources
      # can override these bundled defaults:
      # 1. Bundled defaults (this loader)
      # 2. XDG user config (~/.config/ragdoll/ragdoll.yml)
      # 3. Project config (./config/ragdoll.yml)
      # 4. Local overrides (./config/ragdoll.local.yml)
      # 5. Environment variables (RAGDOLL_*)
      # 6. Programmatic (configure block)
      #
      class DefaultsLoader < Anyway::Loaders::Base
        DEFAULTS_PATH = File.expand_path("../config/defaults.yml", __dir__).freeze

        class << self
          # Returns the path to the bundled defaults file
          #
          # @return [String] path to defaults.yml
          def defaults_path
            DEFAULTS_PATH
          end

          # Check if defaults file exists
          #
          # @return [Boolean]
          def defaults_exist?
            File.exist?(DEFAULTS_PATH)
          end

          # Load and parse the raw YAML content
          #
          # @return [Hash] parsed YAML with symbolized keys
          def load_raw_yaml
            return {} unless defaults_exist?

            content = File.read(defaults_path)
            YAML.safe_load(
              content,
              permitted_classes: [Symbol],
              symbolize_names: true,
              aliases: true
            ) || {}
          rescue Psych::SyntaxError => e
            warn "Ragdoll: Failed to parse bundled defaults #{defaults_path}: #{e.message}"
            {}
          end

          # Extract the schema (attribute names) from the defaults section
          #
          # @return [Hash] the defaults section containing all attribute definitions
          def schema
            raw = load_raw_yaml
            raw[:defaults] || {}
          end

          # Returns valid environment names from the config file
          #
          # Valid environments are top-level keys in defaults.yml excluding 'defaults'.
          # For example, if defaults.yml has keys: defaults, development, test, production
          # this returns [:development, :test, :production]
          #
          # @return [Array<Symbol>] list of valid environment names
          def valid_environments
            raw = load_raw_yaml
            raw.keys.reject { |k| k == :defaults }.sort
          end

          # Check if a given environment name is valid
          #
          # @param env [String, Symbol] environment name to check
          # @return [Boolean] true if environment is valid
          def valid_environment?(env)
            return false if env.nil? || env.to_s.empty?
            return false if env.to_s == "defaults"

            valid_environments.include?(env.to_sym)
          end
        end

        def call(name:, **_options)
          return {} unless self.class.defaults_exist?

          trace!(:bundled_defaults, path: self.class.defaults_path) do
            load_and_merge_for_environment
          end
        end

        private

        # Load defaults and deep merge with environment-specific overrides
        #
        # @return [Hash] merged configuration for current environment
        def load_and_merge_for_environment
          raw = self.class.load_raw_yaml
          return {} if raw.empty?

          # Start with the defaults section
          defaults = raw[:defaults] || {}

          # Deep merge with environment-specific overrides
          env = current_environment
          env_overrides = raw[env.to_sym] || {}

          deep_merge(defaults, env_overrides)
        end

        # Deep merge two hashes, with overlay taking precedence
        #
        # @param base [Hash] base configuration
        # @param overlay [Hash] overlay configuration (takes precedence)
        # @return [Hash] merged result
        def deep_merge(base, overlay)
          base.merge(overlay) do |_key, old_val, new_val|
            if old_val.is_a?(Hash) && new_val.is_a?(Hash)
              deep_merge(old_val, new_val)
            else
              new_val
            end
          end
        end

        # Determine the current environment
        #
        # Priority: RAGDOLL_ENV > RAILS_ENV > RACK_ENV > 'development'
        #
        # @return [String] current environment name
        def current_environment
          ENV["RAGDOLL_ENV"] || ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
        end
      end
    end
  end
end

# Register the defaults loader at LOWEST priority (before :yml loader)
# This ensures bundled defaults are overridden by all other sources:
# - XDG user config (registered after this, also before :yml)
# - Project config (:yml loader)
# - Environment variables (:env loader)
Anyway.loaders.insert_before :yml, :bundled_defaults, Ragdoll::Core::Loaders::DefaultsLoader
