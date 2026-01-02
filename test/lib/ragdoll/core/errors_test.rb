# frozen_string_literal: true

require "test_helper"

class ErrorsTest < Minitest::Test
  # Base Error tests
  def test_error_inherits_from_standard_error
    assert_equal StandardError, Ragdoll::Core::Error.superclass
  end

  def test_error_can_be_raised
    error = Ragdoll::Core::Error.new("Test error")
    assert_equal "Test error", error.message
  end

  def test_error_can_be_rescued
    assert_raises(Ragdoll::Core::Error) do
      raise Ragdoll::Core::Error, "Test"
    end
  end

  # EmbeddingError tests
  def test_embedding_error_inherits_from_error
    assert_equal Ragdoll::Core::Error, Ragdoll::Core::EmbeddingError.superclass
  end

  def test_embedding_error_can_be_raised
    error = Ragdoll::Core::EmbeddingError.new("Embedding failed")
    assert_equal "Embedding failed", error.message
  end

  def test_embedding_error_can_be_rescued_as_error
    assert_raises(Ragdoll::Core::Error) do
      raise Ragdoll::Core::EmbeddingError, "Test"
    end
  end

  # SearchError tests
  def test_search_error_inherits_from_error
    assert_equal Ragdoll::Core::Error, Ragdoll::Core::SearchError.superclass
  end

  def test_search_error_can_be_raised
    error = Ragdoll::Core::SearchError.new("Search failed")
    assert_equal "Search failed", error.message
  end

  # DocumentError tests
  def test_document_error_inherits_from_error
    assert_equal Ragdoll::Core::Error, Ragdoll::Core::DocumentError.superclass
  end

  def test_document_error_can_be_raised
    error = Ragdoll::Core::DocumentError.new("Document failed")
    assert_equal "Document failed", error.message
  end

  # ConfigurationError tests
  def test_configuration_error_inherits_from_error
    assert_equal Ragdoll::Core::Error, Ragdoll::Core::ConfigurationError.superclass
  end

  def test_configuration_error_can_be_raised
    error = Ragdoll::Core::ConfigurationError.new("Configuration failed")
    assert_equal "Configuration failed", error.message
  end

  # CircuitBreakerOpenError tests
  def test_circuit_breaker_open_error_inherits_from_error
    assert_equal Ragdoll::Core::Error, Ragdoll::Core::CircuitBreakerOpenError.superclass
  end

  def test_circuit_breaker_open_error_can_be_raised
    error = Ragdoll::Core::CircuitBreakerOpenError.new("Circuit breaker open")
    assert_equal "Circuit breaker open", error.message
  end

  # TagError tests
  def test_tag_error_inherits_from_error
    assert_equal Ragdoll::Core::Error, Ragdoll::Core::TagError.superclass
  end

  def test_tag_error_can_be_raised
    error = Ragdoll::Core::TagError.new("Tag error")
    assert_equal "Tag error", error.message
  end

  # PropositionError tests
  def test_proposition_error_inherits_from_error
    assert_equal Ragdoll::Core::Error, Ragdoll::Core::PropositionError.superclass
  end

  def test_proposition_error_can_be_raised
    error = Ragdoll::Core::PropositionError.new("Proposition error")
    assert_equal "Proposition error", error.message
  end

  # TimeframeError tests
  def test_timeframe_error_inherits_from_error
    assert_equal Ragdoll::Core::Error, Ragdoll::Core::TimeframeError.superclass
  end

  def test_timeframe_error_can_be_raised
    error = Ragdoll::Core::TimeframeError.new("Timeframe error")
    assert_equal "Timeframe error", error.message
  end

  # Rescue hierarchy tests
  def test_all_errors_can_be_rescued_as_standard_error
    errors = [
      Ragdoll::Core::Error,
      Ragdoll::Core::EmbeddingError,
      Ragdoll::Core::SearchError,
      Ragdoll::Core::DocumentError,
      Ragdoll::Core::ConfigurationError,
      Ragdoll::Core::CircuitBreakerOpenError,
      Ragdoll::Core::TagError,
      Ragdoll::Core::PropositionError,
      Ragdoll::Core::TimeframeError
    ]

    errors.each do |error_class|
      assert_raises(StandardError) do
        raise error_class, "Test"
      end
    end
  end
end
