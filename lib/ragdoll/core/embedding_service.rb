# frozen_string_literal: true

require "ruby_llm"

module Ragdoll
  module Core
    class EmbeddingService
      def initialize(client: nil)
        @client = client
        configure_ruby_llm unless @client
      end

      def generate_embedding(text)
        return nil if text.nil? || text.strip.empty?

        # Clean and prepare text
        cleaned_text = clean_text(text)

        begin
          if @client
            # Use custom client for testing
            # FIXME: embedding_model is not in current config structure
            response = @client.embed(
              input: cleaned_text,
              model: Ragdoll.config.models[:embedding][:text]
            )

            if response && response["embeddings"]&.first
              response["embeddings"].first
            elsif response && response["data"]&.first && response["data"].first["embedding"]
              response["data"].first["embedding"]
            else
              raise EmbeddingError, "Invalid response format from embedding API"
            end
          else
            # Use RubyLLM for real embedding generation
            model_string = Ragdoll.config.models[:embedding][:text] || "openai/text-embedding-3-small"
            # Parse provider/model format and use just the model name for RubyLLM
            parsed = Ragdoll.config.parse_provider_model(model_string)
            model = parsed[:model] || model_string
            response = RubyLLM.embed(cleaned_text, model: model)

            # Extract the embedding vector from RubyLLM::Embedding object
            unless response.respond_to?(:instance_variable_get)
              raise EmbeddingError, "Unexpected response type from RubyLLM: #{response.class}"
            end

            vectors = response.instance_variable_get(:@vectors)
            raise EmbeddingError, "No vectors found in RubyLLM response" unless vectors && vectors.is_a?(Array)

            vectors

          end
        rescue StandardError => e
          raise EmbeddingError, "Failed to generate embedding: #{e.message}"
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
            # FIXME: embedding_model is not in current config structure
            response = @client.embed(
              input: cleaned_texts,
              model: Ragdoll.config.models[:embedding][:text]
            )

            if response && response["embeddings"]
              response["embeddings"]
            elsif response && response["data"]
              response["data"].map { |item| item["embedding"] }
            else
              raise EmbeddingError, "Invalid response format from embedding API"
            end
          else
            # Use RubyLLM for real embedding generation (batch mode)
            model_string = Ragdoll.config.models[:embedding][:text] || "openai/text-embedding-3-small"
            # Parse provider/model format and use just the model name for RubyLLM
            parsed = Ragdoll.config.parse_provider_model(model_string)
            model = parsed[:model] || model_string

            cleaned_texts.map do |text|
              response = RubyLLM.embed(text, model: model)

              # Extract the embedding vector from RubyLLM::Embedding object
              unless response.respond_to?(:instance_variable_get)
                raise EmbeddingError, "Unexpected response type from RubyLLM: #{response.class}"
              end

              vectors = response.instance_variable_get(:@vectors)
              raise EmbeddingError, "No vectors found in RubyLLM response" unless vectors && vectors.is_a?(Array)

              vectors
            end
          end
        rescue StandardError => e
          raise EmbeddingError, "Failed to generate embeddings: #{e.message}"
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
        # FIXME: embedding_provider and llm_provider are not in current config structure
        # FIXME: llm_config is not in current config structure, should use ruby_llm_config directly
        provider = :openai # Default provider
        config = Ragdoll.config.ruby_llm_config[provider] || {}

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
    end
  end
end
