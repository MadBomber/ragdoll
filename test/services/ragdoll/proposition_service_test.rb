# frozen_string_literal: true

require "test_helper"

class PropositionServiceTest < Minitest::Test
  # ============================================
  # Valid Proposition Tests
  # ============================================

  def test_valid_proposition_with_proper_content
    proposition = "Neil Armstrong walked on the Moon in 1969."
    assert Ragdoll::PropositionService.valid_proposition?(proposition)
  end

  def test_valid_proposition_rejects_nil
    refute Ragdoll::PropositionService.valid_proposition?(nil)
  end

  def test_valid_proposition_rejects_non_string
    refute Ragdoll::PropositionService.valid_proposition?(123)
    refute Ragdoll::PropositionService.valid_proposition?([])
    refute Ragdoll::PropositionService.valid_proposition?({})
  end

  def test_valid_proposition_rejects_too_short
    refute Ragdoll::PropositionService.valid_proposition?("Hi")
  end

  def test_valid_proposition_rejects_too_few_words
    refute Ragdoll::PropositionService.valid_proposition?("Hello world")
  end

  def test_valid_proposition_rejects_too_long
    long_proposition = "This is a very long proposition. " * 100
    refute Ragdoll::PropositionService.valid_proposition?(long_proposition)
  end

  def test_valid_proposition_rejects_only_punctuation
    refute Ragdoll::PropositionService.valid_proposition?("... --- !!!")
  end

  def test_valid_proposition_requires_letters
    refute Ragdoll::PropositionService.valid_proposition?("123 456 789 0 0 0")
  end

  # ============================================
  # Meta Response Detection Tests
  # ============================================

  def test_meta_response_detects_please_provide
    assert Ragdoll::PropositionService.meta_response?("Please provide the text you want me to analyze.")
  end

  def test_meta_response_detects_provide_the_text
    assert Ragdoll::PropositionService.meta_response?("Provide the text for extraction.")
  end

  def test_meta_response_detects_i_need
    assert Ragdoll::PropositionService.meta_response?("I need the text to extract propositions from.")
  end

  def test_meta_response_detects_waiting_for
    assert Ragdoll::PropositionService.meta_response?("I am waiting for your input.")
  end

  def test_meta_response_detects_no_text_provided
    assert Ragdoll::PropositionService.meta_response?("No text provided for analysis.")
  end

  def test_meta_response_returns_false_for_normal_content
    refute Ragdoll::PropositionService.meta_response?("Neil Armstrong walked on the Moon in 1969.")
    refute Ragdoll::PropositionService.meta_response?("PostgreSQL supports full-text search.")
    refute Ragdoll::PropositionService.meta_response?("The circuit breaker pattern prevents cascading failures.")
  end

  # ============================================
  # Parse Propositions Tests
  # ============================================

  def test_parse_propositions_from_array
    input = [
      "Neil Armstrong walked on the Moon in 1969.",
      "The Apollo 11 mission was successful."
    ]
    result = Ragdoll::PropositionService.parse_propositions(input)

    assert_equal 2, result.length
    assert_includes result, "Neil Armstrong walked on the Moon in 1969."
    assert_includes result, "The Apollo 11 mission was successful."
  end

  def test_parse_propositions_from_string_newlines
    input = "Neil Armstrong walked on the Moon in 1969.\nThe Apollo 11 mission was successful."
    result = Ragdoll::PropositionService.parse_propositions(input)

    assert_equal 2, result.length
  end

  def test_parse_propositions_strips_bullet_points
    input = "- Neil Armstrong walked on the Moon.\n• The mission was successful.\n* NASA launched Apollo."
    result = Ragdoll::PropositionService.parse_propositions(input)

    assert_includes result, "Neil Armstrong walked on the Moon."
    assert_includes result, "The mission was successful."
    assert_includes result, "NASA launched Apollo."
  end

  def test_parse_propositions_strips_numbering
    input = "1. Neil Armstrong walked on the Moon.\n2. The mission was successful.\n3. NASA launched Apollo."
    result = Ragdoll::PropositionService.parse_propositions(input)

    assert_includes result, "Neil Armstrong walked on the Moon."
    assert_includes result, "The mission was successful."
    assert_includes result, "NASA launched Apollo."
  end

  def test_parse_propositions_removes_empty_lines
    input = "Neil Armstrong walked on the Moon.\n\n\nThe mission was successful."
    result = Ragdoll::PropositionService.parse_propositions(input)

    assert_equal 2, result.length
  end

  def test_parse_propositions_raises_for_invalid_type
    assert_raises(Ragdoll::Core::PropositionError) do
      Ragdoll::PropositionService.parse_propositions(123)
    end

    assert_raises(Ragdoll::Core::PropositionError) do
      Ragdoll::PropositionService.parse_propositions({})
    end
  end

  # ============================================
  # Validate and Filter Tests
  # ============================================

  def test_validate_and_filter_keeps_valid_propositions
    input = [
      "Neil Armstrong walked on the Moon in 1969.",
      "The Apollo 11 mission was the first to land humans on the Moon."
    ]
    result = Ragdoll::PropositionService.validate_and_filter_propositions(input)

    assert_equal 2, result.length
  end

  def test_validate_and_filter_removes_short_propositions
    input = [
      "Hi",
      "Neil Armstrong walked on the Moon in 1969."
    ]
    result = Ragdoll::PropositionService.validate_and_filter_propositions(input)

    assert_equal 1, result.length
    assert_includes result, "Neil Armstrong walked on the Moon in 1969."
  end

  def test_validate_and_filter_removes_meta_responses
    input = [
      "Please provide the text for analysis.",
      "Neil Armstrong walked on the Moon in 1969."
    ]
    result = Ragdoll::PropositionService.validate_and_filter_propositions(input)

    assert_equal 1, result.length
    assert_includes result, "Neil Armstrong walked on the Moon in 1969."
  end

  def test_validate_and_filter_removes_duplicates
    input = [
      "Neil Armstrong walked on the Moon in 1969.",
      "The Apollo 11 mission was the first successful lunar landing.",
      "Neil Armstrong walked on the Moon in 1969."
    ]
    result = Ragdoll::PropositionService.validate_and_filter_propositions(input)

    # Should have 2 unique propositions (the duplicate removed)
    assert_equal 2, result.length
    assert_includes result, "Neil Armstrong walked on the Moon in 1969."
    assert_includes result, "The Apollo 11 mission was the first successful lunar landing."
  end

  def test_validate_and_filter_removes_no_letter_content
    input = [
      "1234 5678 9012 3456 7890",
      "Neil Armstrong walked on the Moon in 1969."
    ]
    result = Ragdoll::PropositionService.validate_and_filter_propositions(input)

    assert_equal 1, result.length
  end

  # ============================================
  # Configuration Tests
  # ============================================

  def test_min_length_default
    assert_equal 10, Ragdoll::PropositionService.min_length
  end

  def test_max_length_default
    assert_equal 1000, Ragdoll::PropositionService.max_length
  end

  def test_min_words_default
    assert_equal 5, Ragdoll::PropositionService.min_words
  end

  # ============================================
  # Circuit Breaker Integration Tests
  # ============================================

  def test_circuit_breaker_exists
    breaker = Ragdoll::PropositionService.circuit_breaker

    assert_instance_of Ragdoll::CircuitBreaker, breaker
    assert breaker.closed?
  end

  def test_reset_circuit_breaker
    # Trip the breaker
    breaker = Ragdoll::PropositionService.circuit_breaker
    5.times do
      begin
        breaker.call { raise "test error" }
      rescue StandardError
        # expected
      end
    end

    # Reset
    Ragdoll::PropositionService.reset_circuit_breaker!

    # Should be closed again
    assert Ragdoll::PropositionService.circuit_breaker.closed?
  end

  # ============================================
  # Extract with Custom Extractor Tests
  # ============================================

  def test_extract_with_custom_extractor
    custom_extractor = ->(_content) do
      [
        "Neil Armstrong walked on the Moon in 1969.",
        "The Apollo 11 mission was the first lunar landing mission."
      ]
    end

    result = Ragdoll::PropositionService.extract("some content", extractor: custom_extractor)

    assert_includes result, "Neil Armstrong walked on the Moon in 1969."
    assert_includes result, "The Apollo 11 mission was the first lunar landing mission."
  end

  def test_extract_filters_invalid_propositions
    custom_extractor = ->(_content) do
      [
        "Hi",
        "Neil Armstrong walked on the Moon in 1969.",
        "Please provide the text for analysis."
      ]
    end

    result = Ragdoll::PropositionService.extract("some content", extractor: custom_extractor)

    assert_equal 1, result.length
    assert_includes result, "Neil Armstrong walked on the Moon in 1969."
  end

  def test_extract_handles_string_response
    custom_extractor = ->(_content) do
      "Neil Armstrong walked on the Moon in 1969.\nThe Apollo 11 mission was successful with a lunar landing."
    end

    result = Ragdoll::PropositionService.extract("some content", extractor: custom_extractor)

    assert_equal 2, result.length
  end

  def test_extract_raises_on_circuit_breaker_open
    # Trip the circuit breaker
    breaker = Ragdoll::PropositionService.circuit_breaker
    5.times do
      begin
        breaker.call { raise "test error" }
      rescue StandardError
        # expected
      end
    end

    assert breaker.open?

    # Now extract should raise CircuitBreakerOpenError
    assert_raises(Ragdoll::Core::CircuitBreakerOpenError) do
      Ragdoll::PropositionService.extract("test content")
    end

    # Reset for other tests
    Ragdoll::PropositionService.reset_circuit_breaker!
  end
end
