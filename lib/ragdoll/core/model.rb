# lib/ragdoll/core/model.rb
# frozen_string_literal: true

module Ragdoll
  module Core
    # Model represents a provider and model name.
    # It is initialized with a string in the format "provider/model".
    # The provider is optional.
    # Can be initialized with nil or empty string.
    Model = Data.define(:name) do
      # @return [Symbol, nil] the provider part of the name, or nil if not present.
      def provider
        return nil if name.nil? || name.empty?

        parts = name.split("/", 2)
        return nil if parts.length < 2 || parts.first.empty?

        parts.first.to_sym
      end

      # @return [String, nil] the model part of the name, or nil if name is nil/empty.
      def model
        return nil if name.nil? || name.empty?

        parts = name.split("/", 2)
        parts.length < 2 ? name : parts.last
      end

      # @return [String] the original name string, or empty string if name is nil.
      def to_s
        name.nil? ? "" : name
      end

      # @return [Hash] a hash representation of the model.
      def to_h
        { provider: provider, model: model }
      end

      # YAML serialization - save as string name
      def encode_with(coder)
        coder.scalar = name
      end
    end
  end
end