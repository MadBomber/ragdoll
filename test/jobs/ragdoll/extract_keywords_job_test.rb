# frozen_string_literal: true

require_relative "../../test_helper"

module Ragdoll
  class ExtractKeywordsJobTest < Minitest::Test
    def test_perform_stores_extracted_keywords_as_an_array
      document = fake_document(content: "Ruby RAG vectors")
      text_service = fake_text_service(%w[ruby rag vectors])

      with_replaced(Ragdoll::Document, :find, ->(_id) { document }) do
        with_replaced(Ragdoll::TextGenerationService, :new, -> { text_service }) do
          Ragdoll::ExtractKeywordsJob.new.perform(1)
        end
      end

      assert_equal [{ keywords: %w[ruby rag vectors] }], document.updates
    end

    def test_perform_saves_keywords_intact_in_the_database
      skip_if_database_unavailable
      document = Ragdoll::Document.create!(location: "/path/to/doc.txt", title: "Doc", document_type: "text",
                                           status: "processed")
      document.text_contents.create!(content: "Ruby RAG vectors", embedding_model: "test-model")
      keywords = ["ruby", "C, C++", 'the "RAG" pattern', "{vectors}"]
      text_service = fake_text_service(keywords)

      with_replaced(Ragdoll::TextGenerationService, :new, -> { text_service }) do
        Ragdoll::ExtractKeywordsJob.new.perform(document.id)
      end

      assert_equal keywords, document.reload.keywords
    end

    private

    # A document double that records the attributes passed to #update!
    def fake_document(content:)
      Struct.new(:content, :keywords, :updates) do
        def update!(attributes) = updates << attributes
      end.new(content, [], [])
    end

    def fake_text_service(keywords)
      Object.new.tap do |service|
        service.define_singleton_method(:extract_keywords) { |_text| keywords }
      end
    end

    # Replaces the class method +name+ on +klass+ for the duration of the block
    def with_replaced(klass, name, replacement)
      klass.define_singleton_method(name, &replacement)
      begin
        yield
      ensure
        klass.singleton_class.remove_method(name)
      end
    end
  end
end
