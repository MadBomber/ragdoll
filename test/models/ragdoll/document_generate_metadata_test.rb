# frozen_string_literal: true

require_relative "../../test_helper"

module Ragdoll
  module Core
    module Models
      # Regression coverage for Ragdoll::Document#generate_metadata! (issue #21).
      #
      # The method used to open with a stale `require_relative` pointing at a
      # file that does not exist, so every call raised LoadError. LoadError is a
      # ScriptError, so the method's own `rescue StandardError` could not catch
      # it and it escaped to callers. Ragdoll::MetadataGenerator is already
      # loaded once "ragdoll" is required, so no require is needed at all.
      #
      # This test exercises the method on a stubbed document without a database
      # or LLM, so it runs in CI mode too.
      class DocumentGenerateMetadataTest < Minitest::Test
        def test_generate_metadata_does_not_raise_load_error
          generated = { "summary" => "stubbed summary" }

          dummy_generator = Object.new
          dummy_generator.define_singleton_method(:generate_for_document) { |_doc| generated }

          document = Ragdoll::Document.allocate
          captured_metadata = nil
          saved = false
          document.define_singleton_method(:document_type) { "text" }
          document.define_singleton_method(:metadata) { {} }
          document.define_singleton_method(:metadata=) { |value| captured_metadata = value }
          document.define_singleton_method(:save!) { saved = true }

          with_stubbed_new(Ragdoll::MetadataGenerator, dummy_generator) do
            # Before the fix this raised LoadError before any stub could apply.
            document.generate_metadata!
          end

          assert saved, "expected generate_metadata! to reach save!"
          assert_equal generated, captured_metadata
        end

        private

        def with_stubbed_new(klass, instance)
          original = klass.method(:new)
          klass.define_singleton_method(:new) { |*_args, **_kwargs| instance }
          yield
        ensure
          klass.singleton_class.send(:remove_method, :new)
          klass.define_singleton_method(:new, original)
        end
      end
    end
  end
end
