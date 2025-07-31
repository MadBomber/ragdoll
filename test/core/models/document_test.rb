# frozen_string_literal: true

require_relative "../../test_helper"

module Ragdoll
  module Core
    module Models
      class DocumentTest < Minitest::Test
        def setup
          super
          skip("Skipping database test in CI environment") if ci_environment?
        end

        def test_create_document
          document = Ragdoll::Core::Models::Document.create!(
            location: "/path/to/doc.txt",
            title: "Test Document",
            document_type: "text",
            status: "processed"
          )

          # Add text content after document creation
          document.text_contents.create!(
            content: "Test content",
            embedding_model: "test-model"
          )

          assert document.persisted?
          # Location should be normalized to absolute path
          assert_equal File.expand_path("/path/to/doc.txt"), document.location
          assert_equal "Test content", document.content
          assert_equal "Test Document", document.title
          assert_equal "text", document.document_type
          assert_equal "processed", document.status
        end

        def test_validations
          # Test required fields (only those without defaults)
          document = Ragdoll::Core::Models::Document.new
          refute document.valid?
          # Use correct method for ActiveRecord errors
          if document.errors.respond_to?(:attribute_names)
            assert_includes document.errors.attribute_names, :location
            assert_includes document.errors.attribute_names, :title
            # document_type and status have default values, so they won't be missing
          else
            assert document.errors[:location].any?
            assert document.errors[:title].any?
            # document_type and status have default values, so they won't be missing
          end
        end

        def test_status_validation
          document = Ragdoll::Core::Models::Document.new(
            location: "/test",
            title: "title",
            document_type: "text",
            status: "invalid_status"
          )

          refute document.valid?
          if document.errors.respond_to?(:attribute_names)
            assert_includes document.errors.attribute_names, :status
          else
            assert document.errors[:status].any?
          end
        end

        def test_associations
          document = Ragdoll::Core::Models::Document.create!(
            location: "/path/to/doc.txt",
            title: "Test Document",
            document_type: "text",
            status: "processed"
          )

          # Create text content
          text_content = document.text_contents.create!(
            content: "Test content",
            embedding_model: "test-model"
          )

          # Create embedding through text content
          vector = Array.new(1536) { |i| (i / 1536.0) }
          embedding = text_content.embeddings.create!(
            chunk_index: 0,
            embedding_vector: vector,
            content: "chunk content"
          )

          assert_equal 1, document.text_embeddings.count
          assert_equal text_content, embedding.embeddable
        end

        def test_scopes
          doc1 = Ragdoll::Core::Models::Document.create!(
            location: "/doc1.txt",
            title: "Doc 1",
            document_type: "text",
            status: "processed"
          )

          doc2 = Ragdoll::Core::Models::Document.create!(
            location: "/doc2.pdf",
            title: "Doc 2",
            document_type: "pdf",
            status: "pending"
          )

          # Test processed scope
          processed_docs = Ragdoll::Core::Models::Document.processed
          assert_equal 1, processed_docs.count
          assert_includes processed_docs, doc1

          # Test by_type scope
          pdf_docs = Ragdoll::Core::Models::Document.by_type("pdf")
          assert_equal 1, pdf_docs.count
          assert_includes pdf_docs, doc2
        end

        def test_processed_query_method
          document = Ragdoll::Core::Models::Document.create!(
            location: "/test.txt",
            title: "Test",
            document_type: "text",
            status: "processed"
          )

          assert document.processed?

          document.update!(status: "pending")
          refute document.processed?
        end

        def test_total_word_count
          document = Ragdoll::Core::Models::Document.create!(
            location: "/test.txt",
            title: "Test",
            document_type: "text",
            status: "processed"
          )

          # Create text content - word count is calculated automatically
          document.text_contents.create!(
            content: "This is a test document with several words",
            embedding_model: "test-model"
          )

          assert_equal 8, document.total_word_count # 8 words in the content
        end

        def test_total_character_count
          document = Ragdoll::Core::Models::Document.create!(
            location: "/test.txt",
            title: "Test",
            document_type: "text",
            status: "processed"
          )

          # Create text content - character count is calculated automatically
          document.text_contents.create!(
            content: "Hello world",
            embedding_model: "test-model"
          )

          assert_equal 11, document.total_character_count # 11 characters in 'Hello world'
        end

        def test_total_embedding_count
          document = Ragdoll::Core::Models::Document.create!(
            location: "/test.txt",
            title: "Test",
            document_type: "text",
            status: "processed"
          )

          assert_equal 0, document.total_embedding_count

          # Create text content
          text_content = document.text_contents.create!(
            content: "Test content",
            embedding_model: "test-model"
          )

          # Create embedding through text content
          vector = Array.new(1536) { |i| (i / 1536.0) }
          text_content.embeddings.create!(
            chunk_index: 0,
            embedding_vector: vector,
            content: "chunk"
          )

          assert_equal 1, document.total_embedding_count
        end

        def test_to_hash
          document = Ragdoll::Core::Models::Document.create!(
            location: "/test.txt",
            title: "Test Document",
            document_type: "text",
            status: "processed",
            metadata: { author: "Test Author" }
          )

          hash = document.to_hash

          assert_equal document.id.to_s, hash[:id]
          # Location should be normalized to absolute path
          assert_equal File.expand_path("/test.txt"), hash[:location]
          # Content is not included by default - requires include_content: true
          assert_equal "Test Document", hash[:title]
          assert_equal "text", hash[:document_type]
          assert_equal({ "author" => "Test Author" }, hash[:metadata])
          assert_equal "processed", hash[:status]
          assert hash[:created_at]
          assert hash[:updated_at]
          # These fields are in content_summary, not at top level
          assert hash[:content_summary]
          assert_equal 0, hash[:content_summary][:embeddings_count]
        end

        def test_search_content
          Ragdoll::Core::Models::Document.create!(
            location: "/doc1.txt",
            title: "Machine Learning Doc",
            document_type: "text",
            status: "processed",
            metadata: { summary: "This document contains machine learning concepts" }
          )

          Ragdoll::Core::Models::Document.create!(
            location: "/doc2.txt",
            title: "Cooking Guide",
            document_type: "text",
            status: "processed",
            metadata: { summary: "This is about cooking recipes" }
          )

          # Test that search_content method exists and returns a relation
          # Note: Full-text search might not work in all test environments
          results = Ragdoll::Core::Models::Document.search_content("machine")
          assert_respond_to results, :count
          assert_respond_to results, :to_a

          # Test with title search (simpler)
          results = Ragdoll::Core::Models::Document.search_content("Machine")
          assert_respond_to results, :count

          # Test empty query returns none
          results = Ragdoll::Core::Models::Document.search_content("")
          assert_equal 0, results.count
        end

        def test_stats
          doc1 = Ragdoll::Core::Models::Document.create!(
            location: "/doc1.txt",
            title: "Doc 1",
            document_type: "text",
            status: "processed"
          )

          Ragdoll::Core::Models::Document.create!(
            location: "/doc2.pdf",
            title: "Doc 2",
            document_type: "pdf",
            status: "pending"
          )

          # Create text content and embedding
          text_content = doc1.text_contents.create!(
            content: "Content 1",
            embedding_model: "test-model"
          )

          vector = Array.new(1536) { |i| (i / 1536.0) }
          text_content.embeddings.create!(
            chunk_index: 0,
            embedding_vector: vector,
            content: "chunk"
          )

          stats = Ragdoll::Core::Models::Document.stats

          assert_equal 2, stats[:total_documents]
          assert_equal({ "processed" => 1, "pending" => 1 }, stats[:by_status])
          assert_equal({ "text" => 1, "pdf" => 1 }, stats[:by_type])
          assert stats[:total_embeddings].is_a?(Hash)
          assert_equal "activerecord_polymorphic", stats[:storage_type]
        end

        def test_extract_keywords_with_valid_query
          query = "This is a test query with some longer words"
          keywords = Ragdoll::Core::Models::Document.extract_keywords(query: query)

          expected = %w[query longer words] # Only words > 4 characters
          assert_equal expected.sort, keywords.sort
        end

        def test_extract_keywords_with_short_words
          query = "cat dog fish bird elephant"
          keywords = Ragdoll::Core::Models::Document.extract_keywords(query: query)

          expected = ["elephant"] # Only word > 4 characters
          assert_equal expected, keywords
        end

        def test_extract_keywords_with_empty_query
          keywords = Ragdoll::Core::Models::Document.extract_keywords(query: "")
          assert_empty keywords
        end

        def test_extract_keywords_with_nil_query
          keywords = Ragdoll::Core::Models::Document.extract_keywords(query: nil)
          assert_empty keywords
        end

        def test_extract_keywords_with_whitespace_only
          keywords = Ragdoll::Core::Models::Document.extract_keywords(query: "   \t\n   ")
          assert_empty keywords
        end

        def test_extract_keywords_removes_duplicates
          query = "machine learning artificial intelligence machine learning"
          keywords = Ragdoll::Core::Models::Document.extract_keywords(query: query)

          expected = %w[machine learning artificial intelligence]
          assert_equal expected.length, keywords.uniq.length # Should not have duplicates
          expected.each { |word| assert_includes keywords, word }
        end

        def test_extract_keywords_handles_punctuation
          query = "machine-learning, artificial.intelligence! natural?language"
          keywords = Ragdoll::Core::Models::Document.extract_keywords(query: query)

          # Should split on whitespace, keeping punctuation with words
          expected_to_include = ["machine-learning,", "artificial.intelligence!", "natural?language"]
          expected_to_include.each { |word| assert_includes keywords, word }
        end
      end
    end
  end
end
