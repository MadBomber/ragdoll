# frozen_string_literal: true

require "test_helper"

module Ragdoll
  module Workflows
    class DocumentEnrichmentWorkflowTest < Minitest::Test
      # Regression for #40: the summary and keyword steps called class methods
      # TextGenerationService does not define, so nothing was ever stored.
      def test_summary_and_keywords_are_stored
        document = fake_document
        generator = Object.new
        generator.define_singleton_method(:generate_summary) { |_content| "stubbed summary" }
        generator.define_singleton_method(:extract_keywords) { |_content| %w[ruby rag] }

        result = with_stubbed_singleton(Ragdoll::Document, :find, ->(_id) { document }) do
          with_stubbed_singleton(Ragdoll::TextGenerationService, :new, ->(**) { generator }) do
            workflow = DocumentEnrichmentWorkflow.new(embedding_service: nil, concurrency: :threads)
            workflow.call(
              document_id: 1,
              content: "Ruby retrieval augmented generation. " * 20,
              options: { skip_embeddings: true, skip_tags: true, skip_propositions: true }
            )
          end
        end

        assert_equal({}, result[:errors])
        assert result[:summary_generated]
        assert_equal 2, result[:keywords_count]
        assert_includes document.updates, { summary: "stubbed summary" }
        assert_includes document.updates, { keywords: %w[ruby rag] }
      end

      private

      def fake_document
        updates = []
        lock = Mutex.new
        Object.new.tap do |doc|
          doc.define_singleton_method(:id) { 1 }
          doc.define_singleton_method(:update!) { |**attrs| lock.synchronize { updates << attrs } }
          doc.define_singleton_method(:updates) { updates }
        end
      end

      def with_stubbed_singleton(klass, name, impl)
        original = klass.method(name)
        klass.define_singleton_method(name, &impl)
        yield
      ensure
        klass.singleton_class.send(:remove_method, name)
        klass.define_singleton_method(name, original)
      end
    end
  end
end
