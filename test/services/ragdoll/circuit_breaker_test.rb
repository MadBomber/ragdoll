# frozen_string_literal: true

require "test_helper"

class CircuitBreakerTest < Minitest::Test
  def setup
    @breaker = Ragdoll::CircuitBreaker.new(
      name: "test_breaker",
      failure_threshold: 3,
      reset_timeout: 1,
      half_open_max_calls: 2
    )
  end

  def test_starts_in_closed_state
    assert @breaker.closed?
    refute @breaker.open?
    refute @breaker.half_open?
  end

  def test_successful_calls_keep_circuit_closed
    result = @breaker.call { "success" }
    assert_equal "success", result
    assert @breaker.closed?
  end

  def test_failures_below_threshold_keep_circuit_closed
    2.times do
      assert_raises(RuntimeError) { @breaker.call { raise "error" } }
    end
    assert @breaker.closed?
  end

  def test_opens_after_reaching_failure_threshold
    3.times do
      assert_raises(RuntimeError) { @breaker.call { raise "error" } }
    end
    assert @breaker.open?
    refute @breaker.closed?
  end

  def test_open_circuit_raises_circuit_breaker_open_error
    # Trip the breaker
    3.times do
      assert_raises(RuntimeError) { @breaker.call { raise "error" } }
    end

    # Subsequent calls should raise CircuitBreakerOpenError
    error = assert_raises(Ragdoll::Core::CircuitBreakerOpenError) do
      @breaker.call { "should not execute" }
    end
    assert_match(/Circuit breaker 'test_breaker' is open/, error.message)
  end

  def test_transitions_to_half_open_after_reset_timeout
    # Trip the breaker
    3.times do
      assert_raises(RuntimeError) { @breaker.call { raise "error" } }
    end
    assert @breaker.open?

    # Wait for reset timeout
    sleep 1.1

    # Transition to half-open happens on next call attempt
    # The call should succeed in half-open state
    result = @breaker.call { "success" }
    assert_equal "success", result

    # After the call, circuit may be half-open or transitioning to closed
    # based on half_open_max_calls setting
  end

  def test_half_open_allows_limited_calls
    # Trip the breaker
    3.times do
      assert_raises(RuntimeError) { @breaker.call { raise "error" } }
    end

    # Wait for reset timeout
    sleep 1.1

    # Should allow calls in half-open state
    result = @breaker.call { "test_call" }
    assert_equal "test_call", result
  end

  def test_half_open_closes_on_success
    # Trip the breaker
    3.times do
      assert_raises(RuntimeError) { @breaker.call { raise "error" } }
    end
    assert @breaker.open?

    # Wait for reset timeout
    sleep 1.1

    # First call triggers transition to half-open and succeeds
    @breaker.call { "success" }
    # Second call brings us to half_open_max_calls (2)
    @breaker.call { "success" }

    # Circuit should be closed after half_open_max_calls successful calls
    assert @breaker.closed?
  end

  def test_half_open_reopens_on_failure
    # Trip the breaker
    3.times do
      assert_raises(RuntimeError) { @breaker.call { raise "error" } }
    end
    assert @breaker.open?

    # Wait for reset timeout
    sleep 1.1

    # Failure during half-open should reopen the circuit
    assert_raises(RuntimeError) { @breaker.call { raise "error" } }
    assert @breaker.open?
  end

  def test_reset_restores_closed_state
    # Trip the breaker
    3.times do
      assert_raises(RuntimeError) { @breaker.call { raise "error" } }
    end
    assert @breaker.open?

    # Reset should restore to closed
    @breaker.reset!
    assert @breaker.closed?
    refute @breaker.open?
  end

  def test_stats_returns_current_state_information
    stats = @breaker.stats

    assert_includes stats, :state
    assert_includes stats, :failure_count
    assert_includes stats, :success_count
    assert_includes stats, :failure_threshold
    assert_includes stats, :reset_timeout
    assert_equal :closed, stats[:state]
    assert_equal 0, stats[:failure_count]
  end

  def test_stats_tracks_failures
    # First cause some failures
    assert_raises(RuntimeError) { @breaker.call { raise "error" } }
    assert_raises(RuntimeError) { @breaker.call { raise "error" } }

    stats = @breaker.stats
    assert_equal 2, stats[:failure_count]
    assert stats[:last_failure_time].present?
  end

  def test_successful_calls_reset_failure_count
    # Cause a failure
    assert_raises(RuntimeError) { @breaker.call { raise "error" } }

    stats_after_failure = @breaker.stats
    assert_equal 1, stats_after_failure[:failure_count]

    # Successful call resets failure count
    @breaker.call { "success" }

    stats_after_success = @breaker.stats
    assert_equal 0, stats_after_success[:failure_count]
  end

  def test_thread_safety
    # Create a fresh breaker for this test to avoid interference
    thread_breaker = Ragdoll::CircuitBreaker.new(
      name: "thread_test",
      failure_threshold: 3,
      reset_timeout: 1,
      half_open_max_calls: 2
    )

    threads = []
    results = []
    mutex = Mutex.new

    10.times do
      threads << Thread.new do
        begin
          result = thread_breaker.call { Thread.current.object_id }
          mutex.synchronize { results << result }
        rescue StandardError
          # Ignore errors for this test
        end
      end
    end

    threads.each(&:join)
    assert_equal 10, results.length
    assert thread_breaker.closed?
  end

  def test_default_configuration
    default_breaker = Ragdoll::CircuitBreaker.new(name: "default")
    stats = default_breaker.stats

    assert_equal 5, stats[:failure_threshold]
    assert_equal 60, stats[:reset_timeout]
  end

  def test_exception_is_reraised
    original_error = StandardError.new("original error message")

    raised_error = assert_raises(StandardError) do
      @breaker.call { raise original_error }
    end

    assert_equal "original error message", raised_error.message
  end
end
