# frozen_string_literal: true

require 'active_support/core_ext/string/inflections'

module Ragdoll
  # Tag Service - Extracts and validates hierarchical tags
  #
  # This service wraps LLM-based tag extraction and provides:
  # - Response parsing (string or array)
  # - Format validation (lowercase, alphanumeric, hyphens, colons)
  # - Depth validation (max 4 levels by default)
  # - Ontology consistency
  # - Circuit breaker protection for external LLM failures
  #
  # @example Extract tags from content
  #   tags = Ragdoll::TagService.extract("PostgreSQL performance tuning guide")
  #   # => ["database:postgresql", "performance:optimization"]
  #
  # @example Add tags to a document
  #   Ragdoll::TagService.add_tags_to_document(doc_id, ["ai:llm", "tutorial"])
  #
  class TagService
    TAG_FORMAT = /^[a-z0-9\-]+(:[a-z0-9\-]+)*$/.freeze
    DEFAULT_MAX_DEPTH = 4

    # Words that should NOT be singularized
    SINGULARIZE_SKIP_LIST = %w[
      rails kubernetes aws gcp azure s3 ios macos redis postgres
      postgresql mysql jenkins travis github gitlab mkdocs devops
      analytics statistics mathematics physics ethics dynamics
      graphics linguistics economics robotics pages windows
    ].freeze

    # Circuit breaker for tag extraction API calls
    @circuit_breaker = nil
    @circuit_breaker_mutex = Mutex.new

    class << self
      # Maximum tag hierarchy depth
      #
      # @return [Integer] Max depth (default 4)
      #
      def max_depth
        DEFAULT_MAX_DEPTH
      end

      # Get or create the circuit breaker for tag service
      #
      # @return [Ragdoll::CircuitBreaker] The circuit breaker instance
      #
      def circuit_breaker
        @circuit_breaker_mutex.synchronize do
          @circuit_breaker ||= Ragdoll::CircuitBreaker.new(
            name: 'tag_service',
            failure_threshold: 3,
            reset_timeout: 30,
            half_open_max_calls: 2
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

      # Extract tags from content using LLM
      #
      # @param content [String] Text to analyze
      # @param existing_ontology [Array<String>] Sample of existing tags for context
      # @param extractor [Proc, nil] Custom extractor proc (default uses LLM)
      # @return [Array<String>] Validated tag names
      # @raise [Ragdoll::Core::CircuitBreakerOpenError] If circuit breaker is open
      #
      def extract(content, existing_ontology: [], extractor: nil)
        extractor ||= default_extractor

        raw_tags = circuit_breaker.call do
          extractor.call(content, existing_ontology)
        end

        parsed_tags = parse_tags(raw_tags)
        validate_and_filter_tags(parsed_tags)
      rescue Ragdoll::Core::CircuitBreakerOpenError
        raise
      rescue Ragdoll::Core::TagError
        raise
      rescue StandardError => e
        log(:error, "Failed to extract tags: #{e.message}")
        raise Ragdoll::Core::TagError, "Tag extraction failed: #{e.message}"
      end

      # Add tags to a document
      #
      # @param document_id [Integer] Document ID
      # @param tags [Array<String>] Tag names to add
      # @param source [String] 'auto' or 'manual'
      # @param confidence [Float] Confidence score (0.0-1.0)
      # @return [Array<Ragdoll::DocumentTag>] Created associations
      #
      def add_tags_to_document(document_id, tags, source: 'auto', confidence: 1.0)
        document = Ragdoll::Document.find(document_id)

        tags.map do |tag_name|
          tag = Ragdoll::Tag.find_or_create_with_hierarchy!(tag_name)

          Ragdoll::DocumentTag.find_or_create_by!(
            document: document,
            tag: tag
          ) do |dt|
            dt.source = source
            dt.confidence = confidence
          end
        end
      end

      # Add tags to an embedding (chunk)
      #
      # @param embedding_id [Integer] Embedding ID
      # @param tags [Array<String>] Tag names to add
      # @param source [String] 'auto' or 'manual'
      # @param confidence [Float] Confidence score (0.0-1.0)
      # @return [Array<Ragdoll::EmbeddingTag>] Created associations
      #
      def add_tags_to_embedding(embedding_id, tags, source: 'auto', confidence: 1.0)
        embedding = Ragdoll::Embedding.find(embedding_id)

        tags.map do |tag_name|
          tag = Ragdoll::Tag.find_or_create_with_hierarchy!(tag_name)

          Ragdoll::EmbeddingTag.find_or_create_by!(
            embedding: embedding,
            tag: tag
          ) do |et|
            et.source = source
            et.confidence = confidence
          end
        end
      end

      # Parse tag response (handles string or array input)
      #
      # @param raw_tags [String, Array] Raw response from extractor
      # @return [Array<String>] Parsed tag strings
      #
      def parse_tags(raw_tags)
        case raw_tags
        when Array
          raw_tags.map(&:to_s).map(&:strip).reject(&:empty?)
        when String
          raw_tags.split("\n").map(&:strip).reject(&:empty?)
        else
          raise Ragdoll::Core::TagError, "Tag response must be Array or String, got #{raw_tags.class}"
        end
      end

      # Validate and filter tags
      #
      # @param tags [Array<String>] Parsed tags
      # @return [Array<String>] Valid tags only
      #
      def validate_and_filter_tags(tags)
        valid_tags = []

        tags.each do |tag|
          # Normalize: convert plural levels to singular
          tag = singularize_tag_levels(tag)

          # Check format
          unless tag.match?(TAG_FORMAT)
            log(:warn, "Invalid tag format, skipping: #{tag}")
            next
          end

          # Check depth
          depth = tag.count(':')
          if depth >= max_depth
            log(:warn, "Tag depth #{depth + 1} exceeds max #{max_depth}, skipping: #{tag}")
            next
          end

          # Parse hierarchy for ontological validation
          levels = tag.split(':')

          # Check for self-containment (root == leaf creates circular reference)
          if levels.size > 1 && levels.first == levels.last
            log(:warn, "Self-containment detected (root == leaf), skipping: #{tag}")
            next
          end

          # Check for duplicate segments in path
          if levels.size != levels.uniq.size
            log(:warn, "Duplicate segment in hierarchy, skipping: #{tag}")
            next
          end

          valid_tags << tag
        end

        valid_tags.uniq
      end

      # Validate single tag format
      #
      # @param tag [String] Tag to validate
      # @return [Boolean] True if valid
      #
      def valid_tag?(tag)
        return false unless tag.is_a?(String)
        return false if tag.empty?
        return false unless tag.match?(TAG_FORMAT)
        return false if tag.count(':') >= max_depth

        levels = tag.split(':')
        return false if levels.size > 1 && levels.first == levels.last
        return false if levels.size != levels.uniq.size

        true
      end

      # Parse hierarchical structure of a tag
      #
      # @param tag [String] Hierarchical tag (e.g., "ai:llm:embedding")
      # @return [Hash] Hierarchy structure
      #
      def parse_hierarchy(tag)
        levels = tag.split(':')

        {
          full: tag,
          root: levels.first,
          parent: levels.size > 1 ? levels[0..-2].join(':') : nil,
          levels: levels,
          depth: levels.size
        }
      end

      # Normalize tag levels to singular form
      #
      # @param tag [String] Tag with potentially plural levels
      # @return [String] Tag with all levels singularized
      #
      def singularize_tag_levels(tag)
        levels = tag.split(':')
        singularized = levels.map { |level| singularize_level(level) }
        singularized.join(':')
      rescue NoMethodError
        tag
      end

      private

      # Default LLM-based tag extractor
      def default_extractor
        lambda do |content, existing_ontology|
          prompt = build_extraction_prompt(content, existing_ontology)

          # Use RubyLLM for extraction
          response = RubyLLM.chat(
            messages: [{ role: 'user', content: prompt }],
            model: 'gpt-4o-mini'
          )

          response.content
        end
      end

      # Build the tag extraction prompt
      def build_extraction_prompt(content, existing_ontology)
        ontology_context = if existing_ontology.any?
                             "\n\nExisting tags in the system (use similar patterns when applicable):\n" +
                               existing_ontology.take(20).join("\n")
                           else
                             ""
                           end

        <<~PROMPT
          Extract hierarchical tags from the following content.

          Rules:
          - Use lowercase letters, numbers, and hyphens only
          - Separate hierarchy levels with colons (e.g., "database:postgresql:jsonb")
          - Maximum 4 levels deep
          - Be specific but not overly granular
          - Return one tag per line
          - No explanations, just tags
          #{ontology_context}

          Content:
          #{content.to_s[0, 2000]}
        PROMPT
      end

      # Singularize a single tag level with safety checks
      def singularize_level(level)
        return level if SINGULARIZE_SKIP_LIST.include?(level.downcase)
        return level if level.end_with?('ics', 'ous', 'ss')
        return level if level.length <= 2
        return level unless level.end_with?('s')

        singular = level.singularize
        return level if singular.length < level.length - 2

        singular
      end

      def log(level, message)
        return unless defined?(Rails) && Rails.logger

        Rails.logger.send(level, "TagService: #{message}")
      end
    end
  end
end
