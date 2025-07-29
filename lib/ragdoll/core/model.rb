# lib/ragdoll/core/model.rb
# frozen_string_literal: true

# Model represents a provider and model name.
# It is initialized with a string in the format "provider/model".
# The provider is optional.
Model = Data.define(:name) do
  # @return [Symbol, nil] the provider part of the name, or nil if not present.
  def provider
    parts = name.split('/', 2)
    return nil if parts.length < 2 || parts.first.empty?
    parts.first.to_sym
  end

  # @return [String] the model part of the name.
  def model
    parts = name.split('/', 2)
    parts.length < 2 ? name : parts.last
  end

  # @return [String] the original name string.
  def to_s
    name
  end

  # @return [Hash] a hash representation of the model.
  def to_h
    { provider: provider, model: model }
  end
end

__END__

# --- Example Usage ---

# With a provider
model_with_provider = Model.new('openai/gpt-4o-mini')
puts "With Provider:"
puts "  Provider: #{model_with_provider.provider.inspect}"
puts "  Model:    #{model_with_provider.model}"
puts "  String:   #{model_with_provider}"
puts "-" * 20

# Without a provider (no slash)
model_without_provider = Model.new('claude-3-opus')
puts "Without Provider (no slash):"
puts "  Provider: #{model_without_provider.provider.inspect}"
puts "  Model:    #{model_without_provider.model}"
puts "  String:   #{model_without_provider}"
puts "-" * 20

# Without a provider (empty string before slash)
model_with_empty_provider = Model.new('/llama3-70b')
puts "Without Provider (empty provider):"
puts "  Provider: #{model_with_empty_provider.provider.inspect}"
puts "  Model:    #{model_with_empty_provider.model}"
puts "  String:   #{model_with_empty_provider}"
puts "-" * 20


# --- Verification ---
puts "Verification:"
puts "  Type for 'openai/gpt-4o-mini' provider: #{model_with_provider.provider.class}"
puts "  Type for 'claude-3-opus' provider:    #{model_without_provider.provider.class}"
puts "  Type for '/llama3-70b' provider:       #{model_with_empty_provider.provider.class}"
