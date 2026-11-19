# frozen_string_literal: true

require "test_helper"

module Ragdoll
  module Workflows
    # Regression for #39: the extract_tags step passed document_id and tags to
    # TagService.add_tags_to_document as keywords, so every call raised ArgumentError.
    class DocumentEnrichmentTagsTest < Minitest::Test
      def test_extracted_tags_are_added_to_the_document
        document = Object.new
        document.define_singleton_method(:id) { 7 }
        document.define_singleton_method(:update!) { |**| true }
        added = nil

        result = with_stubbed_singleton(Ragdoll::Document, :find, ->(_id) { document }) do
          with_stubbed_singleton(Ragdoll::TagService, :extract, ->(_content, **) { ["ruby:gems"] }) do
            add_tags = lambda do |document_id, tags, source: "auto", confidence: 1.0|
              added = [document_id, tags, source]
              []
            end
            with_stubbed_singleton(Ragdoll::TagService, :add_tags_to_document, add_tags) do
              DocumentEnrichmentWorkflow.new(embedding_service: nil, concurrency: :threads).call(
                document_id: 7,
                content: "Ruby gems",
                options: { skip_embeddings: true, skip_summary: true, skip_keywords: true, skip_propositions: true }
              )
            end
          end
        end

        assert_equal({}, result[:errors])
        assert_equal [7, ["ruby:gems"], "auto"], added
      end

      private

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
