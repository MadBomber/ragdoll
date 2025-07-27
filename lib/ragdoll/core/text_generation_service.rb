# frozen_string_literal: true

require "ruby_llm"

module Ragdoll
  module Core
    class TextGenerationService
      class GenerationError < StandardError; end

      def initialize(client: nil)
        @configuration = Ragdoll.config
        @client = client
        configure_ruby_llm_if_possible unless @client
      end

      def generate_summary(text, max_length: nil)
        return "" if text.nil? || text.strip.empty?

        # Skip summarization if not enabled
        unless @configuration.summarization_config[:enable]
          puts "⚠️  LLM summarization disabled, using fallback (first 500 chars)"
          return text[0..500]
        end

        # Skip if content is too short
        min_length = @configuration.summarization_config[:min_content_length]
        return text if text.length < min_length

        max_length ||= @configuration.summarization_config[:max_length]

        # Clean and prepare text
        cleaned_text = clean_text(text)

        # Create summarization prompt
        prompt = build_summary_prompt(cleaned_text, max_length)

        begin
          if @client == :ruby_llm_configured
            # Use RubyLLM for text generation
            # Use summary model from models config, fallback to default
            model_string = @configuration.models[:summary] || @configuration.models[:default]
            
            # Parse provider/model - use only the model part for RubyLLM
            parsed = @configuration.parse_provider_model(model_string)
            model = parsed[:model] || model_string
            
            chat = RubyLLM.chat.with_model(model)
                          .with_temperature(0.3)
            chat.add_message(role: "user", content: prompt)
            response = chat.complete

            if response.respond_to?(:content)
              response.content.strip
            elsif response.respond_to?(:message) && response.message.respond_to?(:content)
              response.message.content.strip
            elsif response && response["choices"]&.first
              response["choices"].first["message"]["content"].strip
            elsif response && response["content"]
              response["content"].strip
            else
              raise GenerationError, "Invalid response format from text generation API"
            end
          elsif @client
            # Use custom client for testing
            model = @configuration.models[:summary] || @configuration.models[:default]
            
            response = @client.chat(
              model: model,
              messages: [
                { role: "user", content: prompt }
              ],
              max_tokens: max_length + 50,
              temperature: 0.3
            )

            if response && response["choices"]&.first
              response["choices"].first["message"]["content"].strip
            elsif response && response["content"]
              response["content"].strip
            else
              raise GenerationError, "Invalid response format from text generation API"
            end
          else
            # Fallback to basic summarization for testing/dev environments
            puts "⚠️  No LLM client configured, using fallback summarization"
            generate_basic_summary(cleaned_text, max_length)
          end
        rescue StandardError => e
          # Fall back to basic summarization if API fails
          puts "❌ LLM summary generation failed, using fallback: #{e.message}"
          generate_basic_summary(cleaned_text, max_length)
        end
      end

      def extract_keywords(text, max_keywords: 20)
        return [] if text.nil? || text.strip.empty?

        # Clean and prepare text
        cleaned_text = clean_text(text)

        # Create keyword extraction prompt
        prompt = build_keyword_prompt(cleaned_text, max_keywords)

        begin
          if @client == :ruby_llm_configured
            # Use RubyLLM for keyword extraction
            # Use keywords model from models config, fallback to default
            model_string = @configuration.models[:keywords] || @configuration.models[:default]
            
            # Parse provider/model - use only the model part for RubyLLM
            parsed = @configuration.parse_provider_model(model_string)
            model = parsed[:model] || model_string
            
            chat = RubyLLM.chat.with_model(model).with_temperature(0.1)
            chat.add_message(role: "user", content: prompt)
            response = chat.complete

            if response.respond_to?(:content)
              content = response.content.strip
              parse_keywords_response(content)
            elsif response.respond_to?(:message) && response.message.respond_to?(:content)
              content = response.message.content.strip
              parse_keywords_response(content)
            elsif response && response["choices"]&.first
              content = response["choices"].first["message"]["content"].strip
              parse_keywords_response(content)
            elsif response && response["content"]
              content = response["content"].strip
              parse_keywords_response(content)
            else
              raise GenerationError, "Invalid response format from text generation API"
            end
          elsif @client
            # Use custom client for testing  
            model = @configuration.models[:keywords] || @configuration.models[:default]
            
            response = @client.chat(
              model: model,
              messages: [
                { role: "user", content: prompt }
              ],
              max_tokens: 200,
              temperature: 0.1
            )

            if response && response["choices"]&.first
              content = response["choices"].first["message"]["content"].strip
              parse_keywords_response(content)
            elsif response && response["content"]
              content = response["content"].strip
              parse_keywords_response(content)
            else
              raise GenerationError, "Invalid response format from text generation API"
            end
          else
            # Fallback to basic keyword extraction for testing/dev environments
            puts "⚠️  No LLM client configured, using fallback keyword extraction"
            extract_basic_keywords(cleaned_text, max_keywords)
          end
        rescue StandardError => e
          # Fall back to basic keyword extraction if API fails
          puts "❌ LLM keyword extraction failed, using fallback: #{e.message}"
          puts "Error class: #{e.class}"
          puts "Backtrace: #{e.backtrace.first(3).join(', ')}"
          extract_basic_keywords(cleaned_text, max_keywords)
        end
      end

      private

      def configure_ruby_llm_if_possible
        # Only configure if we have valid configuration
        # Use embedding_config provider, fallback to :openai
        provider = @configuration.embedding_config[:provider] || :openai
        config = @configuration.ruby_llm_config[provider] || {}

        # Check if we have the necessary API key for the provider
        has_api_key = case provider
                      when :openai
                        config[:api_key] && !config[:api_key].empty?
                      when :anthropic
                        config[:api_key] && !config[:api_key].empty?
                      when :google
                        config[:api_key] && !config[:api_key].empty?
                      when :azure
                        config[:api_key] && !config[:api_key].empty?
                      when :ollama
                        true # Ollama doesn't need API key for local setup
                      when :huggingface
                        config[:api_key] && !config[:api_key].empty?
                      when :openrouter
                        config[:api_key] && !config[:api_key].empty?
                      else
                        false
                      end

        return unless has_api_key

        begin
          RubyLLM.configure do |ruby_llm_config|
            case provider
            when :openai
              ruby_llm_config.openai_api_key = config[:api_key]
              ruby_llm_config.openai_organization = config[:organization] if config[:organization]
              ruby_llm_config.openai_project = config[:project] if config[:project]
            when :anthropic
              ruby_llm_config.anthropic_api_key = config[:api_key]
            when :google
              ruby_llm_config.google_api_key = config[:api_key]
              ruby_llm_config.google_project_id = config[:project_id] if config[:project_id]
            when :azure
              ruby_llm_config.azure_api_key = config[:api_key]
              ruby_llm_config.azure_endpoint = config[:endpoint] if config[:endpoint]
              ruby_llm_config.azure_api_version = config[:api_version] if config[:api_version]
            when :ollama
              ruby_llm_config.ollama_endpoint = config[:endpoint] if config[:endpoint]
            when :huggingface
              ruby_llm_config.huggingface_api_key = config[:api_key]
            when :openrouter
              ruby_llm_config.openrouter_api_key = config[:api_key]
            end
          end

          # RubyLLM uses module-level methods, not individual provider classes
          @client = :ruby_llm_configured
        rescue StandardError => e
          # If configuration fails, don't set client (will use fallback)
          puts "❌ RubyLLM configuration failed: #{e.message}"
          puts "   Will use fallback text processing for summaries and keywords"
        end
      end

      def clean_text(text)
        return "" if text.nil?

        # Remove excessive whitespace and normalize
        cleaned = text.strip
                      .gsub(/\s+/, " ")              # Multiple spaces to single space
                      .gsub(/\n+/, "\n")             # Multiple newlines to single newline
                      .gsub(/\t+/, " ")              # Tabs to spaces

        # Truncate if too long (most models have token limits)
        max_chars = 12_000 # Conservative limit for most language models
        cleaned.length > max_chars ? cleaned[0, max_chars] : cleaned
      end

      def build_summary_prompt(text, max_length)
        <<~PROMPT
          Please provide a concise summary of the following text. The summary should:
          - Be approximately #{max_length} characters or less
          - Capture the main topics and key points
          - Be written in clear, professional language
          - Focus on the most important information

          Text to summarize:
          #{text}

          Summary:
        PROMPT
      end

      def build_keyword_prompt(text, max_keywords)
        <<~PROMPT
          Please extract the most important keywords and key phrases from the following text.#{' '}
          Provide up to #{max_keywords} keywords that best represent the content.

          Requirements:
          - Focus on nouns, important concepts, and technical terms
          - Avoid common stop words and articles
          - Include both single words and meaningful phrases
          - Separate keywords with commas
          - Order by importance (most important first)

          Text to analyze:
          #{text}

          Keywords (comma-separated):
        PROMPT
      end

      def parse_keywords_response(content)
        # Extract keywords from the response, handling various formats
        content
          .gsub(/^(keywords?:?\s*)/i, "") # Remove "Keywords:" prefix
          .split(/[,\n]/)                 # Split by commas or newlines
          .map(&:strip)                   # Remove whitespace
          .reject(&:empty?)               # Remove empty strings
          .reject { |k| k.match?(/^\d+\./) } # Remove numbered list items
          .map { |k| k.gsub(/^\d+\.\s*/, "") } # Remove numbering from start
          .reject { |k| k.length < 2 }    # Remove very short words
          .first(20)                      # Limit to 20 keywords
      end

      def generate_basic_summary(text, max_length)
        # Fallback summarization method (same as before)
        clean_text = text.gsub(/\s+/, " ").strip

        # Split into sentences
        sentences = clean_text.split(/[.!?]+/).map(&:strip).reject(&:empty?)

        # If content is short, use the whole thing
        return clean_text if clean_text.length <= max_length

        # Take first 2-3 sentences or up to max_length characters
        summary_sentences = []
        total_length = 0

        sentences.each do |sentence|
          break unless total_length + sentence.length <= max_length && summary_sentences.length < 3

          summary_sentences << sentence
          total_length += sentence.length
        end

        summary = summary_sentences.join(". ")
        summary += "." unless summary.end_with?(".", "!", "?")
        summary
      end

      def extract_basic_keywords(text, max_keywords)
        # Fallback keyword extraction method (same as before)
        stop_words = %w[
          a an and are as at be by for from has he in is it its of on that the
          to was will with the this these those they them their there where when
          what who why how which would could should shall might may can must
          do does did done doing go goes went gone going get gets got gotten
          getting have had having has been being am was were are is was been
          but or not no yes if then else also too very much many most some any
          all each every each other another one two three first second third
          last next previous before after during while until since through
          above below under over between among within without across around
          near far close distant here there everywhere nowhere somewhere anywhere
        ]

        # Clean and normalize text
        cleaned_text = text.downcase
                           .gsub(/[^\w\s]/, " ") # Remove punctuation
                           .gsub(/\s+/, " ") # Normalize whitespace
                           .strip

        # Split into words and filter
        words = cleaned_text.split(" ")
                            .reject { |word| word.length < 3 } # Remove short words
                            .reject { |word| stop_words.include?(word) } # Remove stop words
                            .reject { |word| word.match?(/^\d+$/) } # Remove pure numbers

        # Count word frequencies
        word_counts = Hash.new(0)
        words.each { |word| word_counts[word] += 1 }

        # Get top keywords (words that appear more than once or are significant)
        word_counts
          .select { |word, count| count > 1 || word.length > 6 }
          .sort_by { |word, count| [-count, word] }
          .first(max_keywords) # Limit to max_keywords
          .map { |word, _count| word }
      end
    end
  end
end
