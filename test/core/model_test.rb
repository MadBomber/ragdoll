# frozen_string_literal: true

require_relative "../test_helper"

class CoreModelTest < Minitest::Test
  def test_model_with_provider
    model = Ragdoll::Core::Model.new("openai/gpt-4o-mini")

    assert_equal :openai, model.provider
    assert_equal "gpt-4o-mini", model.model
    assert_equal "openai/gpt-4o-mini", model.to_s
    assert_equal "openai/gpt-4o-mini", model.name
    assert_equal({ provider: :openai, model: "gpt-4o-mini" }, model.to_h)
  end

  def test_model_without_provider_no_slash
    model = Ragdoll::Core::Model.new("claude-3-opus")

    assert_nil model.provider
    assert_equal "claude-3-opus", model.model
    assert_equal "claude-3-opus", model.to_s
    assert_equal "claude-3-opus", model.name
    assert_equal({ provider: nil, model: "claude-3-opus" }, model.to_h)
  end

  def test_model_with_empty_provider
    model = Ragdoll::Core::Model.new("/llama3-70b")

    assert_nil model.provider
    assert_equal "llama3-70b", model.model
    assert_equal "/llama3-70b", model.to_s
    assert_equal "/llama3-70b", model.name
    assert_equal({ provider: nil, model: "llama3-70b" }, model.to_h)
  end

  def test_model_with_complex_provider_and_model
    model = Ragdoll::Core::Model.new("anthropic/claude-3-5-sonnet-20241022")

    assert_equal :anthropic, model.provider
    assert_equal "claude-3-5-sonnet-20241022", model.model
    assert_equal "anthropic/claude-3-5-sonnet-20241022", model.to_s
    assert_equal({ provider: :anthropic, model: "claude-3-5-sonnet-20241022" }, model.to_h)
  end

  def test_model_with_multiple_slashes
    model = Ragdoll::Core::Model.new("huggingface-hub/microsoft/DialoGPT-medium")

    assert_equal :"huggingface-hub", model.provider
    assert_equal "microsoft/DialoGPT-medium", model.model
    assert_equal "huggingface-hub/microsoft/DialoGPT-medium", model.to_s
    assert_equal({ provider: :"huggingface-hub", model: "microsoft/DialoGPT-medium" }, model.to_h)
  end

  def test_model_with_empty_string
    model = Ragdoll::Core::Model.new("")

    assert_nil model.provider
    assert_nil model.model
    assert_equal "", model.to_s
    assert_equal({ provider: nil, model: nil }, model.to_h)
  end

  def test_model_with_nil
    model = Ragdoll::Core::Model.new(nil)

    assert_nil model.provider
    assert_nil model.model
    assert_equal "", model.to_s
    assert_equal({ provider: nil, model: nil }, model.to_h)
  end

  def test_model_with_only_slash
    model = Ragdoll::Core::Model.new("/")

    assert_nil model.provider
    assert_equal "", model.model
    assert_equal "/", model.to_s
    assert_equal({ provider: nil, model: "" }, model.to_h)
  end

  def test_model_provider_returns_symbol
    model = Ragdoll::Core::Model.new("openai/gpt-4")

    assert_instance_of Symbol, model.provider
    assert_equal :openai, model.provider
  end

  def test_model_provider_returns_nil_for_no_provider
    model = Ragdoll::Core::Model.new("gpt-4")

    assert_nil model.provider
    assert_instance_of NilClass, model.provider
  end

  def test_model_equality
    model1 = Ragdoll::Core::Model.new("openai/gpt-4")
    model2 = Ragdoll::Core::Model.new("openai/gpt-4")
    model3 = Ragdoll::Core::Model.new("anthropic/claude-3")

    assert_equal model1, model2
    refute_equal model1, model3
  end

  def test_model_hash_equality
    model1 = Ragdoll::Core::Model.new("openai/gpt-4")
    model2 = Ragdoll::Core::Model.new("openai/gpt-4")

    assert_equal model1.hash, model2.hash
  end

  def test_model_immutable
    model = Ragdoll::Core::Model.new("openai/gpt-4")

    # Data.define creates immutable objects
    assert_raises(FrozenError) do
      model.instance_variable_set(:@name, "changed")
    end
  end

  def test_model_inspect
    model = Ragdoll::Core::Model.new("openai/gpt-4o-mini")

    # Data.define provides a nice inspect method
    assert_includes model.inspect, "openai/gpt-4o-mini"
    assert_includes model.inspect, "Model"
  end

  def test_edge_cases_with_whitespace
    model = Ragdoll::Core::Model.new(" openai/gpt-4 ")

    # The class doesn't trim whitespace - it preserves the original string
    assert_equal :" openai", model.provider
    assert_equal "gpt-4 ", model.model
  end

  def test_numeric_provider_and_model
    model = Ragdoll::Core::Model.new("123/456")

    assert_equal :"123", model.provider
    assert_equal "456", model.model
  end

  def test_special_characters_in_model_name
    model = Ragdoll::Core::Model.new("openai/gpt-4-turbo-preview@2024-01-25")

    assert_equal :openai, model.provider
    assert_equal "gpt-4-turbo-preview@2024-01-25", model.model
  end

  def test_model_with_url_like_structure
    model = Ragdoll::Core::Model.new("https://api.openai.com/v1/gpt-4")

    assert_equal :"https:", model.provider
    assert_equal "/api.openai.com/v1/gpt-4", model.model
  end
end
