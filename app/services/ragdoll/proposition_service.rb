# frozen_string_literal: true

module Ragdoll
  # Proposition Service - Extracts atomic factual propositions from text
  #
  # This service breaks complex text into simple, self-contained factual
  # statements that can be stored as independent retrievable units.
  #
  # Each proposition:
  # - Expresses a single fact
  # - Is understandable without context
  # - Uses full names, not pronouns
  # - Includes relevant dates/qualifiers
  # - Contains one subject-predicate relationship
  #
  # @example
  #   propositions = Ragdoll::PropositionService.extract(
  #     "In 1969, Neil Armstrong became the first person to walk on the Moon."
  #   )
  #   # => ["Neil Armstrong walked on the Moon in 1969.",
  #   #     "Neil Armstrong was the first person to walk on the Moon.",
  #   #     "The Apollo 11 mission occurred in 1969."]
  #
  class PropositionService
    # Default configuration
    DEFAULT_MIN_LENGTH = 10
    DEFAULT_MAX_LENGTH = 1000
    DEFAULT_MIN_WORDS = 5

    # Patterns that indicate meta-responses (LLM asking for input instead of extracting)
    META_RESPONSE_PATTERNS = [
      /please provide/i,
      /provide the text/i,
      /provide me with/i,
      /I need the text/i,
      /I am ready/i,
      /waiting for/i,
      /send me the/i,
      /what text would you/i,
      /what would you like/i,
      /cannot extract.*without/i,
      /no text provided/i
    ].freeze

    # Circuit breaker for proposition extraction API calls
    @circuit_breaker = nil
    @circuit_breaker_mutex = Mutex.new

    class << self
      # Get or create the circuit breaker for proposition service
      #
      # @return [Ragdoll::CircuitBreaker] The circuit breaker instance
      #
      def circuit_breaker
        @circuit_breaker_mutex.synchronize do
          @circuit_breaker ||= Ragdoll::CircuitBreaker.new(
            name: 'proposition_service',
            failure_threshold: 5,
            reset_timeout: 60
          )
        end
      end

      # Reset the circuit breaker (useful for testing)
      #
      # @return [void]
      #
      def reset_circuit_breaker!
        @circuit_breaker_mutex.synchronize do
          @circuit_breaker&.reset!
        end
      end

      # Extract propositions from text content
      #
      # @param content [String] Text to analyze
      # @param extractor [Proc, nil] Custom extractor proc (default uses LLM)
      # @return [Array<String>] Array of atomic propositions
      # @raise [Ragdoll::Core::CircuitBreakerOpenError] If circuit breaker is open
      # @raise [Ragdoll::Core::PropositionError] If extraction fails
      #
      def extract(content, extractor: nil)
        extractor ||= default_extractor

        raw_propositions = circuit_breaker.call do
          extractor.call(content)
        end

        parsed_propositions = parse_propositions(raw_propositions)
        validate_and_filter_propositions(parsed_propositions)
      rescue Ragdoll::Core::CircuitBreakerOpenError
        raise
      rescue Ragdoll::Core::PropositionError
        raise
      rescue StandardError => e
        log(:error, "Failed to extract propositions: #{e.message}")
        raise Ragdoll::Core::PropositionError, "Proposition extraction failed: #{e.message}"
      end

      # Extract propositions and store them for a document
      #
      # @param document_id [Integer] Document ID
      # @param embedding_service [Ragdoll::EmbeddingService] For generating embeddings
      # @return [Array<Ragdoll::Proposition>] Created propositions
      #
      def extract_and_store(document_id, embedding_service: nil)
        document = Ragdoll::Document.find(document_id)

        # Get all text content from the document's embeddings
        document.text_embeddings.find_each do |embedding|
          propositions = extract(embedding.content)

          propositions.each do |prop_content|
            # Create proposition
            prop = Ragdoll::Proposition.create!(
              document: document,
              source_embedding: embedding,
              content: prop_content,
              metadata: { extracted_at: Time.current.iso8601 }
            )

            # Generate embedding if service provided
            next unless embedding_service

            vector = embedding_service.generate_embedding(prop_content)
            prop.update!(embedding_vector: vector) if vector
          end
        end

        document.propositions
      end

      # Parse proposition response (handles string or array input)
      #
      # @param raw_propositions [String, Array] Raw response from extractor
      # @return [Array<String>] Parsed proposition strings
      #
      def parse_propositions(raw_propositions)
        case raw_propositions
        when Array
          raw_propositions.map(&:to_s).map(&:strip).reject(&:empty?)
        when String
          raw_propositions
            .split("\n")
            .map(&:strip)
            .map { |line| line.sub(/^[-*•]\s*/, '') }
            .map { |line| line.sub(/^\d+\.\s*/, '') }
            .map(&:strip)
            .reject(&:empty?)
        else
          raise Ragdoll::Core::PropositionError,
                "Proposition response must be Array or String, got #{raw_propositions.class}"
        end
      end

      # Validate and filter propositions
      #
      # @param propositions [Array<String>] Parsed propositions
      # @return [Array<String>] Valid propositions only
      #
      def validate_and_filter_propositions(propositions)
        valid_propositions = []

        propositions.each do |proposition|
          # Check minimum length (characters)
          next if proposition.length < min_length

          # Check maximum length
          if proposition.length > max_length
            log(:warn, "Proposition too long, skipping: #{proposition[0..50]}...")
            next
          end

          # Check for actual content (not just punctuation/whitespace)
          next unless proposition.match?(/[a-zA-Z]{3,}/)

          # Check minimum word count
          word_count = proposition.split.size
          if word_count < min_words
            log(:debug, "Proposition too short (#{word_count} words), skipping: #{proposition}")
            next
          end

          # Filter out meta-responses (LLM asking for more input)
          if meta_response?(proposition)
            log(:warn, "Filtered meta-response: #{proposition[0..50]}...")
            next
          end

          valid_propositions << proposition
        end

        valid_propositions.uniq
      end

      # Validate single proposition
      #
      # @param proposition [String] Proposition to validate
      # @return [Boolean] True if valid
      #
      def valid_proposition?(proposition)
        return false unless proposition.is_a?(String)
        return false if proposition.length < min_length
        return false if proposition.length > max_length
        return false unless proposition.match?(/[a-zA-Z]{3,}/)
        return false if proposition.split.size < min_words
        return false if meta_response?(proposition)

        true
      end

      # Check if proposition is a meta-response (LLM asking for input)
      #
      # @param proposition [String] Proposition to check
      # @return [Boolean] True if it's a meta-response
      #
      def meta_response?(proposition)
        META_RESPONSE_PATTERNS.any? { |pattern| proposition.match?(pattern) }
      end

      # Configuration accessors
      def min_length
        DEFAULT_MIN_LENGTH
      end

      def max_length
        DEFAULT_MAX_LENGTH
      end

      def min_words
        DEFAULT_MIN_WORDS
      end

      private

      # Default LLM-based proposition extractor
      def default_extractor
        lambda do |content|
          prompt = build_extraction_prompt(content)

          response = RubyLLM.chat(
            messages: [{ role: 'user', content: prompt }],
            model: 'gpt-4o-mini'
          )

          response.content
        end
      end

      # Build the proposition extraction prompt
      def build_extraction_prompt(content)
        <<~PROMPT
          Extract atomic factual propositions from the following text.

          Rules for each proposition:
          - Express a single, complete fact
          - Be self-contained and understandable without context
          - Use full names instead of pronouns (he, she, it, they)
          - Include relevant dates, locations, and qualifiers
          - One subject-predicate relationship per proposition
          - Return one proposition per line
          - No bullet points or numbering
          - No explanations or meta-commentary

          Text:
          #{content.to_s[0, 3000]}
        PROMPT
      end

      def log(level, message)
        return unless defined?(Rails) && Rails.logger

        Rails.logger.send(level, "PropositionService: #{message}")
      end
    end
  end
end
