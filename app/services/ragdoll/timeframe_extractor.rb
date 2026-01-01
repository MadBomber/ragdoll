# frozen_string_literal: true

require 'chronic'

module Ragdoll
  # Timeframe Extractor - Extracts temporal expressions from queries
  #
  # This service parses natural language time expressions from search queries
  # and returns both the timeframe and the cleaned query text.
  #
  # Supports:
  # - Standard time expressions via Chronic gem ("yesterday", "last week", etc.)
  # - "few" keyword mapped to FEW constant (e.g., "few days ago" → "3 days ago")
  # - "recent/recently" without units defaults to FEW days
  #
  # @example Basic usage
  #   result = TimeframeExtractor.extract("what documents from last week about PostgreSQL")
  #   result.query     # => "what documents about PostgreSQL"
  #   result.timeframe # => #<Range: 2025-12-24..2025-12-31>
  #
  # @example With "few" keyword
  #   result = TimeframeExtractor.extract("show me notes from a few days ago")
  #   result.timeframe # => Time range for 3 days ago
  #
  # @example With "recently"
  #   result = TimeframeExtractor.extract("what did we recently add")
  #   result.timeframe # => Range from 3 days ago to now
  #
  class TimeframeExtractor
    # The numeric value for "few" and "recently" without units
    FEW = 3

    # Default unit for "recently" when no time unit is specified
    DEFAULT_RECENT_UNIT = :days

    # Time unit patterns for matching
    TIME_UNITS = %w[
      seconds? minutes? hours? days? weeks? months? years?
    ].join('|').freeze

    # Word-to-number mapping for written numbers
    WORD_NUMBERS = {
      'one' => 1, 'two' => 2, 'three' => 3, 'four' => 4, 'five' => 5,
      'six' => 6, 'seven' => 7, 'eight' => 8, 'nine' => 9, 'ten' => 10
    }.freeze

    # Patterns for temporal expressions (order matters - more specific first)
    TEMPORAL_PATTERNS = [
      # "between X and Y" - date ranges
      /\bbetween\s+(.+?)\s+and\s+(.+?)(?=\s+(?:about|regarding|for|on|with)|$)/i,

      # "from X to Y" - date ranges
      /\bfrom\s+(.+?)\s+to\s+(.+?)(?=\s+(?:about|regarding|for|on|with)|$)/i,

      # "since X" - from date to now
      /\bsince\s+(.+?)(?=\s+(?:about|regarding|for|on|with)|$)/i,

      # "before/after X"
      /\b(before|after)\s+(.+?)(?=\s+(?:about|regarding|for|on|with)|$)/i,

      # "in the last/past X units" (including "few", "a few", "several")
      /\bin\s+the\s+(?:last|past)\s+(?:\d+|few|a\s+few|several)\s+(?:#{TIME_UNITS})/i,

      # "weekend before last" / "the weekend before last"
      /\b(?:the\s+)?weekend\s+before\s+last\b/i,

      # "N weekends ago" (numeric or written)
      /\b(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten|few|a\s+few|several)\s+weekends?\s+ago\b/i,

      # "a few X ago" or "few X ago"
      /\b(?:a\s+)?few\s+(?:#{TIME_UNITS})\s+ago\b/i,

      # "X units ago"
      /\b\d+\s+(?:#{TIME_UNITS})\s+ago\b/i,

      # "last/this/next weekend"
      /\b(?:last|this|next)\s+weekend\b/i,

      # "last/this/next X" (week, month, year, monday, etc.)
      /\b(?:last|this|next)\s+(?:week|month|year|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/i,

      # "recently" or "recent" as standalone or with context
      /\b(?:recently|recent)\b/i,

      # Standard time words
      /\b(?:yesterday|today|tonight|this\s+morning|this\s+afternoon|this\s+evening|last\s+night)\b/i
    ].freeze

    # Result structure for extracted timeframe
    Result = Struct.new(:query, :timeframe, :original_expression, keyword_init: true)

    class << self
      # Extract timeframe from a query string
      #
      # @param query [String] The query to parse
      # @param week_start [Symbol] Day to start week (:sunday or :monday)
      # @return [Result] Struct with :query (cleaned), :timeframe, :original_expression
      #
      def extract(query, week_start: :sunday)
        return Result.new(query: query, timeframe: nil, original_expression: nil) if query.nil? || query.strip.empty?

        # Try each pattern against the ORIGINAL query
        TEMPORAL_PATTERNS.each do |pattern|
          match = query.match(pattern)
          next unless match

          original_expression = match[0].strip
          timeframe = parse_expression(original_expression, week_start: week_start)
          next unless timeframe

          # Remove the matched expression from query
          cleaned_query = clean_query(query, original_expression)

          return Result.new(
            query: cleaned_query,
            timeframe: timeframe,
            original_expression: original_expression
          )
        end

        # No temporal expression found
        Result.new(query: query, timeframe: nil, original_expression: nil)
      end

      # Check if query contains a temporal expression
      #
      # @param query [String] The query to check
      # @return [Boolean]
      #
      def temporal?(query)
        return false if query.nil? || query.strip.empty?

        TEMPORAL_PATTERNS.any? { |pattern| query.match?(pattern) }
      end

      private

      # Normalize "few" and "a few" to the FEW constant value
      #
      # @param text [String] Text to normalize
      # @return [String] Normalized text
      #
      def normalize_few_keywords(text)
        text
          .gsub(/\ba\s+few\b/i, FEW.to_s)
          .gsub(/\bfew\b/i, FEW.to_s)
          .gsub(/\bseveral\b/i, FEW.to_s)
      end

      # Parse a temporal expression into a timeframe
      #
      # @param expression [String] The temporal expression
      # @param week_start [Symbol] Day to start week
      # @return [Time, Range, nil] Parsed timeframe
      #
      def parse_expression(expression, week_start: :sunday)
        # Handle "recently/recent" specially - default to FEW days
        return parse_recent if expression.match?(/\b(?:recently|recent)\b/i)

        # Handle "weekend before last" - 2 weekends ago
        return parse_weekends_ago(2) if expression.match?(/\bweekend\s+before\s+last\b/i)

        # Handle "N weekends ago" (numeric or written)
        if (match = expression.match(/\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten|few|a\s+few|several)\s+weekends?\s+ago\b/i))
          count = parse_number(match[1])
          return parse_weekends_ago(count)
        end

        # Normalize "few" to numeric value for Chronic
        normalized = normalize_few_keywords(expression)

        # Handle "in the last/past X units" - create range from X ago to now
        if (match = normalized.match(/(?:in\s+the\s+)?(?:last|past)\s+(\d+)\s+(#{TIME_UNITS})/i))
          return parse_last_x(match[1].to_i, match[2])
        end

        # Strip "in the" prefix for Chronic
        chronic_expr = normalized.gsub(/\bin\s+the\s+/i, '')

        # Try to get a span/range first
        result = Chronic.parse(chronic_expr, guess: false, week_start: week_start)

        # Convert Chronic::Span to Range if needed
        if result.respond_to?(:begin) && result.respond_to?(:end)
          return result.begin..result.end
        end

        # Fall back to point in time
        Chronic.parse(chronic_expr, week_start: week_start)
      end

      # Parse a number from string (numeric or written word)
      #
      # @param str [String] Number as digit or word
      # @return [Integer] Parsed number
      #
      def parse_number(str)
        normalized = str.downcase.strip
        return FEW if ['few', 'a few', 'several'].include?(normalized)
        return WORD_NUMBERS[normalized] if WORD_NUMBERS.key?(normalized)

        normalized.to_i
      end

      # Parse "N weekends ago" to a Saturday-Sunday range
      #
      # @param count [Integer] Number of weekends ago (1 = last weekend)
      # @return [Range] Time range for that weekend (Saturday 00:00 to Monday 00:00)
      #
      def parse_weekends_ago(count)
        now = Time.now

        # Find last Saturday (most recent Saturday before or equal to today)
        days_since_saturday = (now.wday - 6) % 7
        days_since_saturday = 7 if days_since_saturday.zero? && now.wday != 6

        last_saturday = Time.new(now.year, now.month, now.day, 0, 0, 0) - (days_since_saturday * 24 * 60 * 60)

        # Go back (count - 1) more weeks to get to the target weekend
        target_saturday = last_saturday - ((count - 1) * 7 * 24 * 60 * 60)

        # Weekend spans Saturday 00:00 to Monday 00:00
        weekend_start = target_saturday
        weekend_end = target_saturday + (2 * 24 * 60 * 60)

        weekend_start..weekend_end
      end

      # Parse "last X units" or "past X units" to a proper range
      #
      # @param count [Integer] Number of units
      # @param unit [String] Time unit (days, hours, etc.)
      # @return [Range] Time range from count units ago to now
      #
      def parse_last_x(count, unit)
        now = Time.now
        unit_normalized = unit.downcase.sub(/s$/, '')

        seconds = case unit_normalized
                  when 'second' then count
                  when 'minute' then count * 60
                  when 'hour' then count * 60 * 60
                  when 'day' then count * 24 * 60 * 60
                  when 'week' then count * 7 * 24 * 60 * 60
                  when 'month' then count * 30 * 24 * 60 * 60
                  when 'year' then count * 365 * 24 * 60 * 60
                  else count * 24 * 60 * 60
                  end

        (now - seconds)..now
      end

      # Parse "recently" to a range from FEW days ago to now
      #
      # @return [Range] Time range
      #
      def parse_recent
        now = Time.now
        case DEFAULT_RECENT_UNIT
        when :seconds then (now - FEW)..now
        when :minutes then (now - (FEW * 60))..now
        when :hours then (now - (FEW * 60 * 60))..now
        when :days then (now - (FEW * 24 * 60 * 60))..now
        when :weeks then (now - (FEW * 7 * 24 * 60 * 60))..now
        when :months then (now - (FEW * 30 * 24 * 60 * 60))..now
        when :years then (now - (FEW * 365 * 24 * 60 * 60))..now
        else (now - (FEW * 24 * 60 * 60))..now
        end
      end

      # Clean the query by removing the temporal expression
      #
      # @param query [String] Original query
      # @param expression [String] Expression to remove
      # @return [String] Cleaned query
      #
      def clean_query(query, expression)
        escaped = Regexp.escape(expression)

        query
          .sub(/#{escaped}/i, '')
          .gsub(/\s{2,}/, ' ')
          .gsub(/\s+([,.])/, '\1')
          .strip
      end
    end
  end
end
