# frozen_string_literal: true

require "test_helper"

# Verifies the test_helper hook that skips database-backed tests when the
# suite runs without a database (CI=true or RAGDOLL_SKIP_DATABASE_TESTS=true).
class DatabaseSkipTest < Minitest::Test
  def test_missing_connection_is_a_skip_in_ci_mode
    result = run_probe(ci: true)

    assert result.skipped?, "expected a skip, got #{result.failures.map(&:class).inspect}"
  end

  def test_missing_connection_is_an_error_outside_ci_mode
    result = run_probe(ci: false)

    refute result.skipped?
    assert_instance_of Minitest::UnexpectedError, result.failures.first
  end

  private

  # Runs a one-off test case whose body needs a database connection that does not exist.
  def run_probe(ci:)
    probe = Class.new(Minitest::Test) do
      define_method(:ci_environment?) { ci }
      define_method(:setup) {}
      define_method(:teardown) {}
      define_method(:test_needs_database) do
        raise ActiveRecord::ConnectionNotDefined, "No database connection defined."
      end
    end
    Minitest::Runnable.runnables.delete(probe)

    probe.new(:test_needs_database).run
  end
end
