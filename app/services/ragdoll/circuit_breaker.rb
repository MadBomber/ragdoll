# frozen_string_literal: true

module Ragdoll
  # Circuit Breaker - Prevents cascading failures from external LLM services
  #
  # Implements the circuit breaker pattern to protect against repeated failures
  # when calling external LLM APIs for embeddings, tag extraction, or propositions.
  #
  # States:
  # - :closed - Normal operation, requests flow through
  # - :open - Circuit tripped, requests fail fast with CircuitBreakerOpenError
  # - :half_open - Testing if service recovered, allows limited requests
  #
  # @example Basic usage
  #   breaker = Ragdoll::CircuitBreaker.new(name: 'embedding')
  #   result = breaker.call { external_api_call }
  #
  # @example With custom thresholds
  #   breaker = Ragdoll::CircuitBreaker.new(
  #     name: 'tag_extraction',
  #     failure_threshold: 3,
  #     reset_timeout: 30
  #   )
  #
  class CircuitBreaker
    attr_reader :name, :state, :failure_count, :last_failure_time

    # Default configuration
    DEFAULT_FAILURE_THRESHOLD = 5      # Failures before opening circuit
    DEFAULT_RESET_TIMEOUT = 60         # Seconds before trying half-open
    DEFAULT_HALF_OPEN_MAX_CALLS = 3    # Successful calls to close circuit

    # Initialize a new circuit breaker
    #
    # @param name [String] Identifier for this circuit breaker (for logging)
    # @param failure_threshold [Integer] Number of failures before opening circuit
    # @param reset_timeout [Integer] Seconds to wait before attempting recovery
    # @param half_open_max_calls [Integer] Successful calls needed to close circuit
    # @param logger [Logger] Optional logger instance (defaults to Rails.logger if available)
    #
    def initialize(
      name:,
      failure_threshold: DEFAULT_FAILURE_THRESHOLD,
      reset_timeout: DEFAULT_RESET_TIMEOUT,
      half_open_max_calls: DEFAULT_HALF_OPEN_MAX_CALLS,
      logger: nil
    )
      @name = name
      @failure_threshold = failure_threshold
      @reset_timeout = reset_timeout
      @half_open_max_calls = half_open_max_calls
      @logger = logger

      @state = :closed
      @failure_count = 0
      @success_count = 0
      @last_failure_time = nil
      @mutex = Mutex.new
    end

    # Execute a block with circuit breaker protection
    #
    # @yield Block containing the protected operation
    # @return [Object] Result of the block if successful
    # @raise [Ragdoll::Core::CircuitBreakerOpenError] If circuit is open
    # @raise [StandardError] If the block raises an error (after recording failure)
    #
    def call
      @mutex.synchronize do
        case @state
        when :open
          check_reset_timeout
          if @state == :open
            log(:warn, "Circuit is OPEN, failing fast")
            raise Ragdoll::Core::CircuitBreakerOpenError,
                  "Circuit breaker '#{@name}' is open. Service unavailable."
          end
        end
      end

      begin
        result = yield
        record_success
        result
      rescue StandardError => e
        record_failure(e)
        raise
      end
    end

    # Check if circuit is currently open
    #
    # @return [Boolean] true if circuit is open
    #
    def open?
      @mutex.synchronize { @state == :open }
    end

    # Check if circuit is currently closed (normal operation)
    #
    # @return [Boolean] true if circuit is closed
    #
    def closed?
      @mutex.synchronize { @state == :closed }
    end

    # Check if circuit is in half-open state (testing recovery)
    #
    # @return [Boolean] true if circuit is half-open
    #
    def half_open?
      @mutex.synchronize { @state == :half_open }
    end

    # Manually reset the circuit breaker to closed state
    #
    # @return [void]
    #
    def reset!
      @mutex.synchronize do
        @state = :closed
        @failure_count = 0
        @success_count = 0
        @last_failure_time = nil
        log(:info, "Manually reset to CLOSED")
      end
    end

    # Get current circuit breaker statistics
    #
    # @return [Hash] Statistics including state, failure count, etc.
    #
    def stats
      @mutex.synchronize do
        {
          name: @name,
          state: @state,
          failure_count: @failure_count,
          success_count: @success_count,
          last_failure_time: @last_failure_time,
          failure_threshold: @failure_threshold,
          reset_timeout: @reset_timeout
        }
      end
    end

    private

    # Record a successful call
    def record_success
      @mutex.synchronize do
        case @state
        when :half_open
          @success_count += 1
          if @success_count >= @half_open_max_calls
            @state = :closed
            @failure_count = 0
            @success_count = 0
            log(:info, "Service recovered, circuit CLOSED")
          end
        when :closed
          # Reset failure count on success in closed state
          @failure_count = 0 if @failure_count.positive?
        end
      end
    end

    # Record a failed call
    def record_failure(error)
      @mutex.synchronize do
        @failure_count += 1
        @last_failure_time = Time.now
        @success_count = 0

        log(:warn, "Failure ##{@failure_count} - #{error.class}: #{error.message}")

        case @state
        when :closed
          if @failure_count >= @failure_threshold
            @state = :open
            log(:error, "Threshold reached (#{@failure_threshold}), circuit OPEN")
          end
        when :half_open
          @state = :open
          log(:warn, "Failed during recovery test, circuit OPEN")
        end
      end
    end

    # Check if reset timeout has elapsed and transition to half-open
    def check_reset_timeout
      return unless @state == :open && @last_failure_time

      elapsed = Time.now - @last_failure_time
      return unless elapsed >= @reset_timeout

      @state = :half_open
      @success_count = 0
      log(:info, "Reset timeout elapsed (#{@reset_timeout}s), circuit HALF-OPEN")
    end

    # Log a message with the circuit breaker name prefix
    def log(level, message)
      return unless logger

      logger.send(level, "CircuitBreaker[#{@name}]: #{message}")
    end

    # Get the logger instance
    def logger
      @logger || (defined?(Rails) && Rails.logger)
    end
  end
end
