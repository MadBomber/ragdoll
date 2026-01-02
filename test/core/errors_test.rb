# frozen_string_literal: true

require_relative "../test_helper"

class CoreErrorsTest < Minitest::Test
  def test_base_error_class
    error = Ragdoll::Core::Error.new("test message")

    assert_instance_of Ragdoll::Core::Error, error
    assert_kind_of StandardError, error
    assert_equal "test message", error.message
  end

  def test_embedding_error_inheritance
    error = Ragdoll::Core::EmbeddingError.new("embedding failed")

    assert_instance_of Ragdoll::Core::EmbeddingError, error
    assert_kind_of Ragdoll::Core::Error, error
    assert_kind_of StandardError, error
    assert_equal "embedding failed", error.message
  end

  def test_search_error_inheritance
    error = Ragdoll::Core::SearchError.new("search failed")

    assert_instance_of Ragdoll::Core::SearchError, error
    assert_kind_of Ragdoll::Core::Error, error
    assert_equal "search failed", error.message
  end

  def test_document_error_inheritance
    error = Ragdoll::Core::DocumentError.new("document processing failed")

    assert_instance_of Ragdoll::Core::DocumentError, error
    assert_kind_of Ragdoll::Core::Error, error
    assert_equal "document processing failed", error.message
  end

  def test_configuration_error_inheritance
    error = Ragdoll::Core::ConfigurationError.new("configuration invalid")

    assert_instance_of Ragdoll::Core::ConfigurationError, error
    assert_kind_of Ragdoll::Core::Error, error
    assert_equal "configuration invalid", error.message
  end

  def test_error_raising_and_catching
    assert_raises(Ragdoll::Core::EmbeddingError) do
      raise Ragdoll::Core::EmbeddingError, "test"
    end

    # Should be catchable as the base error class
    assert_raises(Ragdoll::Core::Error) do
      raise Ragdoll::Core::EmbeddingError, "test"
    end

    # Should be catchable as StandardError
    assert_raises(StandardError) do
      raise Ragdoll::Core::EmbeddingError, "test"
    end
  end

  def test_error_without_message
    error = Ragdoll::Core::Error.new

    assert_instance_of Ragdoll::Core::Error, error
    assert_equal "Ragdoll::Core::Error", error.message
  end

  def test_all_error_classes_exist
    error_classes = [
      Ragdoll::Core::Error,
      Ragdoll::Core::EmbeddingError,
      Ragdoll::Core::SearchError,
      Ragdoll::Core::DocumentError,
      Ragdoll::Core::ConfigurationError
    ]

    error_classes.each do |error_class|
      assert_respond_to error_class, :new
      assert error_class < StandardError
    end
  end

  def test_error_hierarchy
    # Test that all specific errors inherit from base Error
    specific_errors = [
      Ragdoll::Core::EmbeddingError,
      Ragdoll::Core::SearchError,
      Ragdoll::Core::DocumentError,
      Ragdoll::Core::ConfigurationError
    ]

    specific_errors.each do |error_class|
      assert error_class < Ragdoll::Core::Error, "#{error_class} should inherit from Ragdoll::Core::Error"
    end
  end
end
