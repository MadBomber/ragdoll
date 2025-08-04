# frozen_string_literal: true

require "ruby_llm"

module Ragdoll
  class EmbeddingService
    def initialize(client: nil, config_service: nil, model_resolver: nil)
      @client = client
      @config_service = config_service || Ragdoll::ConfigurationService.new
      @model_resolver = model_resolver || Ragdoll::Core::ModelResolver.new(@config_service)
      configure_ruby_llm unless @client
    end

    def generate_embedding(text)
      return nil if text.nil? || text.strip.empty?

      # Clean and prepare text
      cleaned_text = clean_text(text)

      begin
        if @client
          # Use custom client for testing
          embedding_config = @model_resolver.resolve_embedding(:text)
          response = @client.embed(
            input: cleaned_text,
            model: embedding_config.model.to_s
          )

          if response && response["embeddings"]&.first
            response["embeddings"].first
          elsif response && response["data"]&.first && response["data"].first["embedding"]
            response["data"].first["embedding"]
          else
            raise Ragdoll::Core::EmbeddingError, "Invalid response format from embedding API"
          end
        else
          # Use RubyLLM for real embedding generation
          embedding_config = @model_resolver.resolve_embedding(:text)
          # Use just the model name for RubyLLM
          model = embedding_config.model.model

          begin
            response = RubyLLM.embed(cleaned_text, model: model)

            # Extract the embedding vector from RubyLLM::Embedding object
            return generate_fallback_embedding unless response.respond_to?(:instance_variable_get)

            vectors = response.instance_variable_get(:@vectors)
            return generate_fallback_embedding unless vectors && vectors.is_a?(Array)

            vectors
          rescue StandardError
            # If RubyLLM fails, use fallback
            generate_fallback_embedding
          end
        end
      rescue StandardError => e
        # Only use fallback if no client was provided (RubyLLM failures)
        # If a client was provided, we should raise the error for proper test behavior
        raise Ragdoll::Core::EmbeddingError, "Failed to generate embedding: #{e.message}" if @client

        # No client - this is a RubyLLM configuration issue, use fallback
        puts "Warning: Embedding generation failed (#{e.message}), using fallback"
        generate_fallback_embedding
      end
    end

    def generate_embeddings_batch(texts)
      return [] if texts.empty?

      # Clean all texts
      cleaned_texts = texts.map { |text| clean_text(text) }.reject { |t| t.nil? || t.strip.empty? }
      return [] if cleaned_texts.empty?

      begin
        if @client
          # Use custom client for testing
          embedding_config = @model_resolver.resolve_embedding(:text)
          response = @client.embed(
            input: cleaned_texts,
            model: embedding_config.model.to_s
          )

          if response && response["embeddings"]
            response["embeddings"]
          elsif response && response["data"]
            response["data"].map { |item| item["embedding"] }
          else
            raise Ragdoll::Core::EmbeddingError, "Invalid response format from embedding API"
          end
        else
          # Use RubyLLM for real embedding generation (batch mode)
          embedding_config = @model_resolver.resolve_embedding(:text)
          # Use just the model name for RubyLLM
          model = embedding_config.model.model

          cleaned_texts.map do |text|
            response = RubyLLM.embed(text, model: model)

            # Extract the embedding vector from RubyLLM::Embedding object
            next generate_fallback_embedding unless response.respond_to?(:instance_variable_get)

            vectors = response.instance_variable_get(:@vectors)
            next generate_fallback_embedding unless vectors && vectors.is_a?(Array)

            vectors
          rescue StandardError
            # If RubyLLM fails, use fallback
            generate_fallback_embedding
          end
        end
      rescue StandardError => e
        # Only use fallback if no client was provided (RubyLLM failures)
        # If a client was provided, we should raise the error for proper test behavior
        raise Ragdoll::Core::EmbeddingError, "Failed to generate embeddings: #{e.message}" if @client

        # No client - this is a RubyLLM configuration issue, use fallback
        puts "Warning: Batch embedding generation failed (#{e.message}), using fallback"
        texts.map { generate_fallback_embedding }
      end
    end

    def cosine_similarity(embedding1, embedding2)
      return 0.0 if embedding1.nil? || embedding2.nil?
      return 0.0 if embedding1.length != embedding2.length

      dot_product = embedding1.zip(embedding2).sum { |a, b| a * b }
      magnitude1 = Math.sqrt(embedding1.sum { |a| a * a })
      magnitude2 = Math.sqrt(embedding2.sum { |a| a * a })

      return 0.0 if magnitude1 == 0.0 || magnitude2 == 0.0

      dot_product / (magnitude1 * magnitude2)
    end

    private

    def configure_ruby_llm
      # Configure ruby_llm based on Ragdoll configuration
      provider = @config_service.config.llm_providers[:default_provider]
      config = @config_service.provider_credentials(provider)

      RubyLLM.configure do |ruby_llm_config|
        case provider
        when :openai
          ruby_llm_config.openai_api_key = config[:api_key]
          # Set organization and project if methods exist
          if config[:organization] && ruby_llm_config.respond_to?(:openai_organization=)
            ruby_llm_config.openai_organization = config[:organization]
          end
          ruby_llm_config.openai_project = config[:project] if config[:project] && ruby_llm_config.respond_to?(:openai_project=)
        when :anthropic
          ruby_llm_config.anthropic_api_key = config[:api_key] if ruby_llm_config.respond_to?(:anthropic_api_key=)
        when :google
          ruby_llm_config.google_api_key = config[:api_key] if ruby_llm_config.respond_to?(:google_api_key=)
          if config[:project_id] && ruby_llm_config.respond_to?(:google_project_id=)
            ruby_llm_config.google_project_id = config[:project_id]
          end
        when :azure
          ruby_llm_config.azure_api_key = config[:api_key] if ruby_llm_config.respond_to?(:azure_api_key=)
          ruby_llm_config.azure_endpoint = config[:endpoint] if config[:endpoint] && ruby_llm_config.respond_to?(:azure_endpoint=)
          if config[:api_version] && ruby_llm_config.respond_to?(:azure_api_version=)
            ruby_llm_config.azure_api_version = config[:api_version]
          end
        when :ollama
          if config[:endpoint] && ruby_llm_config.respond_to?(:ollama_endpoint=)
            ruby_llm_config.ollama_endpoint = config[:endpoint]
          end
        when :huggingface
          ruby_llm_config.huggingface_api_key = config[:api_key] if ruby_llm_config.respond_to?(:huggingface_api_key=)
        when :openrouter
          ruby_llm_config.openrouter_api_key = config[:api_key] if ruby_llm_config.respond_to?(:openrouter_api_key=)
        else
          # Don't raise error for unsupported providers in case RubyLLM doesn't support them yet
          puts "Warning: Unsupported embedding provider: #{provider}"
        end
      end
    end

    def clean_text(text)
      return "" if text.nil?

      # Remove excessive whitespace and normalize
      cleaned = text.strip
                    .gsub(/\s+/, " ")              # Multiple spaces to single space
                    .gsub(/\n+/, "\n")             # Multiple newlines to single newline
                    .gsub(/\t+/, " ")              # Tabs to spaces

      # Truncate if too long (most embedding models have token limits)
      max_chars = 8000 # Conservative limit for most embedding models
      cleaned.length > max_chars ? cleaned[0, max_chars] : cleaned
    end

    # Generate a fallback embedding for testing/development when LLM services are unavailable
    def generate_fallback_embedding(dimensions = 1536)
      # Generate deterministic pseudo-random embeddings based on the object_id
      # This ensures consistent results for testing while providing different embeddings for different instances
      rng = Random.new(object_id)
      dimensions.times.map { rng.rand * 2.0 - 1.0 }
    end
  end
end