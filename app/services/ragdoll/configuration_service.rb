# frozen_string_literal: true

module Ragdoll
  # Service class for centralized configuration logic
  # Provides a clean interface for accessing configuration with validation
  class ConfigurationService
    def initialize(config = nil)
      @config = config || Ragdoll.config
    end

    # Expose config as a public method as well for backward compatibility
    def config
      @config
    end

    # Resolve model for a task with inheritance support
    def resolve_model(task_type, content_type = :text)
      case task_type
      when :embedding
        @config.embedding_model(content_type)
      when :summary, :keywords
        # Check for task-specific model, fall back to default
        task_model = @config.models.text_generation[task_type]
        task_model || @config.models.text_generation[:default]
      else
        @config.models.text_generation[:default]
      end
    end

    # Get provider credentials with fallback to default provider
    def provider_credentials(provider = nil)
      provider ||= @config.llm_providers[:default_provider]
      credentials = @config.llm_providers[provider]
      
      if credentials.nil?
        raise Ragdoll::ConfigurationError, "Provider '#{provider}' not configured"
      end
      
      credentials
    end

    # Get chunking configuration for content type
    def chunking_config(content_type = :text)
      @config.processing[content_type]&.dig(:chunking) || 
      @config.processing[:default][:chunking]
    end

    # Get search configuration
    def search_config
      @config.processing[:search]
    end

    # Get prompt template with validation
    def prompt_template(template_name = :rag_enhancement)
      template = @config.prompt_templates[template_name]
      
      if template.nil?
        raise Ragdoll::ConfigurationError, "Prompt template '#{template_name}' not found"
      end
      
      template
    end

    # Validate configuration completeness
    def validate!
      errors = []

      # Check required database configuration
      errors << "Database password not configured" if @config.database[:password].nil?
      
      # Check default LLM provider configuration
      default_provider = @config.llm_providers[:default_provider]
      if default_provider.nil?
        errors << "Default LLM provider not specified"
      else
        provider_config = @config.llm_providers[default_provider]
        if provider_config.nil?
          errors << "Default provider '#{default_provider}' not configured"
        elsif provider_config[:api_key].nil?
          errors << "API key for default provider '#{default_provider}' not configured"
        end
      end

      # Check embedding configuration
      if @config.models.embedding[:text].nil?
        errors << "Text embedding model not configured"
      end

      # Ensure log directory can be created
      log_dir = File.dirname(@config.logging[:filepath])
      unless Dir.exist?(log_dir) || File.writable?(File.dirname(log_dir))
        errors << "Cannot create log directory '#{log_dir}'"
      end

      unless errors.empty?
        raise Ragdoll::ConfigurationError, "Configuration validation failed:\n  - #{errors.join("\n  - ")}"
      end

      true
    end

    # Check if configuration is valid without raising
    def valid?
      validate!
      true
    rescue Ragdoll::ConfigurationError
      false
    end

    # Expose config for access
    attr_reader :config
  end
end