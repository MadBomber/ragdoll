# frozen_string_literal: true

require "test_helper"

class ModelTest < Minitest::Test
  # Initialization tests
  def test_model_can_be_created_with_full_name
    model = Ragdoll::Core::Model.new(name: "openai/gpt-4")
    assert_equal "openai/gpt-4", model.name
  end

  def test_model_can_be_created_with_model_only
    model = Ragdoll::Core::Model.new(name: "gpt-4")
    assert_equal "gpt-4", model.name
  end

  def test_model_can_be_created_with_nil
    model = Ragdoll::Core::Model.new(name: nil)
    assert_nil model.name
  end

  def test_model_can_be_created_with_empty_string
    model = Ragdoll::Core::Model.new(name: "")
    assert_equal "", model.name
  end

  def test_model_can_be_created_from_another_model
    original = Ragdoll::Core::Model.new(name: "openai/gpt-4")
    copy = Ragdoll::Core::Model.new(name: original)
    assert_equal "openai/gpt-4", copy.name
  end

  # Provider extraction tests
  def test_provider_returns_symbol_when_present
    model = Ragdoll::Core::Model.new(name: "openai/gpt-4")
    assert_equal :openai, model.provider
  end

  def test_provider_returns_nil_when_no_slash
    model = Ragdoll::Core::Model.new(name: "gpt-4")
    assert_nil model.provider
  end

  def test_provider_returns_nil_for_nil_name
    model = Ragdoll::Core::Model.new(name: nil)
    assert_nil model.provider
  end

  def test_provider_returns_nil_for_empty_name
    model = Ragdoll::Core::Model.new(name: "")
    assert_nil model.provider
  end

  def test_provider_returns_nil_for_empty_provider_part
    model = Ragdoll::Core::Model.new(name: "/gpt-4")
    assert_nil model.provider
  end

  # Model extraction tests
  def test_model_returns_model_part_when_provider_present
    model = Ragdoll::Core::Model.new(name: "openai/gpt-4")
    assert_equal "gpt-4", model.model
  end

  def test_model_returns_full_name_when_no_provider
    model = Ragdoll::Core::Model.new(name: "gpt-4")
    assert_equal "gpt-4", model.model
  end

  def test_model_returns_nil_for_nil_name
    model = Ragdoll::Core::Model.new(name: nil)
    assert_nil model.model
  end

  def test_model_returns_nil_for_empty_name
    model = Ragdoll::Core::Model.new(name: "")
    assert_nil model.model
  end

  def test_model_handles_multiple_slashes
    model = Ragdoll::Core::Model.new(name: "anthropic/claude-3/opus")
    assert_equal :anthropic, model.provider
    assert_equal "claude-3/opus", model.model
  end

  # to_s tests
  def test_to_s_returns_name
    model = Ragdoll::Core::Model.new(name: "openai/gpt-4")
    assert_equal "openai/gpt-4", model.to_s
  end

  def test_to_s_returns_empty_string_for_nil
    model = Ragdoll::Core::Model.new(name: nil)
    assert_equal "", model.to_s
  end

  # empty? tests
  def test_empty_returns_true_for_nil
    model = Ragdoll::Core::Model.new(name: nil)
    assert model.empty?
  end

  def test_empty_returns_true_for_empty_string
    model = Ragdoll::Core::Model.new(name: "")
    assert model.empty?
  end

  def test_empty_returns_false_for_name
    model = Ragdoll::Core::Model.new(name: "gpt-4")
    refute model.empty?
  end

  # to_h tests
  def test_to_h_returns_hash_with_provider_and_model
    model = Ragdoll::Core::Model.new(name: "openai/gpt-4")
    result = model.to_h
    assert_kind_of Hash, result
    assert result.key?(:provider)
    assert result.key?(:model)
  end

  def test_to_h_includes_correct_provider
    model = Ragdoll::Core::Model.new(name: "openai/gpt-4")
    assert_equal :openai, model.to_h[:provider]
  end

  def test_to_h_includes_correct_model
    model = Ragdoll::Core::Model.new(name: "openai/gpt-4")
    assert_equal "gpt-4", model.to_h[:model]
  end

  def test_to_h_handles_no_provider
    model = Ragdoll::Core::Model.new(name: "gpt-4")
    result = model.to_h
    assert_nil result[:provider]
    assert_equal "gpt-4", result[:model]
  end

  # Real-world model name tests
  def test_ollama_model
    model = Ragdoll::Core::Model.new(name: "ollama/nomic-embed-text")
    assert_equal :ollama, model.provider
    assert_equal "nomic-embed-text", model.model
  end

  def test_anthropic_model
    model = Ragdoll::Core::Model.new(name: "anthropic/claude-3-opus-20240229")
    assert_equal :anthropic, model.provider
    assert_equal "claude-3-opus-20240229", model.model
  end

  def test_openai_embedding_model
    model = Ragdoll::Core::Model.new(name: "openai/text-embedding-3-large")
    assert_equal :openai, model.provider
    assert_equal "text-embedding-3-large", model.model
  end

  # Data class behavior tests
  def test_model_is_immutable
    model = Ragdoll::Core::Model.new(name: "openai/gpt-4")
    assert_raises(FrozenError) do
      model.instance_variable_set(:@name, "changed")
    end
  end

  def test_model_equality
    model1 = Ragdoll::Core::Model.new(name: "openai/gpt-4")
    model2 = Ragdoll::Core::Model.new(name: "openai/gpt-4")
    assert_equal model1, model2
  end

  def test_model_inequality
    model1 = Ragdoll::Core::Model.new(name: "openai/gpt-4")
    model2 = Ragdoll::Core::Model.new(name: "anthropic/claude")
    refute_equal model1, model2
  end
end
