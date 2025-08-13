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
          document = Ragdoll::Document.create!(
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
          document = Ragdoll::Document.new
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
          document = Ragdoll::Document.new(
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
          document = Ragdoll::Document.create!(
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
          doc1 = Ragdoll::Document.create!(
            location: "/doc1.txt",
            title: "Doc 1",
            document_type: "text",
            status: "processed"
          )

          doc2 = Ragdoll::Document.create!(
            location: "/doc2.pdf",
            title: "Doc 2",
            document_type: "pdf",
            status: "pending"
          )

          # Test processed scope
          processed_docs = Ragdoll::Document.processed
          assert_equal 1, processed_docs.count
          assert_includes processed_docs, doc1

          # Test by_type scope
          pdf_docs = Ragdoll::Document.by_type("pdf")
          assert_equal 1, pdf_docs.count
          assert_includes pdf_docs, doc2
        end

        def test_processed_query_method
          document = Ragdoll::Document.create!(
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
          document = Ragdoll::Document.create!(
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
          document = Ragdoll::Document.create!(
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
          document = Ragdoll::Document.create!(
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
          document = Ragdoll::Document.create!(
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
          doc1 = Ragdoll::Document.create!(
            location: "/doc1.txt",
            title: "Machine Learning Doc",
            document_type: "text",
            status: "processed",
            metadata: { summary: "This document contains machine learning concepts" }
          )

          doc2 = Ragdoll::Document.create!(
            location: "/doc2.txt",
            title: "Cooking Guide",
            document_type: "text",
            status: "processed",
            metadata: { summary: "This is about cooking recipes" }
          )

          # Single-word search "machine"
          results = Ragdoll::Document.search_content("machine")
          assert_respond_to results, :count
          assert_equal 1, results.count
          assert_equal doc1.id, results.first.id
          assert_in_delta 1.0, results.first.fulltext_similarity.to_f, 0.0001

          # Case-insensitive search
          results = Ragdoll::Document.search_content("Machine")
          assert_equal 1, results.count
          assert_equal doc1.id, results.first.id

          # Multi-word search "machine cooking"
          results = Ragdoll::Document.search_content("machine cooking")
          assert_equal 2, results.count
          # Both docs match one of two words (similarity 0.5), doc2 is newer so appears first
          assert_equal [doc2.id, doc1.id], results.map(&:id)
          results.each do |rec|
            assert_in_delta 0.5, rec.fulltext_similarity.to_f, 0.0001
          end

          # Empty query returns none
          results = Ragdoll::Document.search_content("")
          assert_equal 0, results.count
        end

        def test_stats
          doc1 = Ragdoll::Document.create!(
            location: "/doc1.txt",
            title: "Doc 1",
            document_type: "text",
            status: "processed"
          )

          Ragdoll::Document.create!(
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

          stats = Ragdoll::Document.stats

          assert_equal 2, stats[:total_documents]
          assert_equal({ "processed" => 1, "pending" => 1 }, stats[:by_status])
          assert_equal({ "text" => 1, "pdf" => 1 }, stats[:by_type])
          assert stats[:total_embeddings].is_a?(Hash)
          assert_equal "activerecord_polymorphic", stats[:storage_type]
        end

        def test_extract_keywords_with_valid_query
          query = "This is a test query with some longer words"
          keywords = Ragdoll::Document.extract_keywords(query: query)

          expected = %w[query longer words] # Only words > 4 characters
          assert_equal expected.sort, keywords.sort
        end

        def test_extract_keywords_with_short_words
          query = "cat dog fish bird elephant"
          keywords = Ragdoll::Document.extract_keywords(query: query)

          expected = ["elephant"] # Only word > 4 characters
          assert_equal expected, keywords
        end

        def test_extract_keywords_with_empty_query
          keywords = Ragdoll::Document.extract_keywords(query: "")
          assert_empty keywords
        end

        def test_extract_keywords_with_nil_query
          keywords = Ragdoll::Document.extract_keywords(query: nil)
          assert_empty keywords
        end

        def test_extract_keywords_with_whitespace_only
          keywords = Ragdoll::Document.extract_keywords(query: "   \t\n   ")
          assert_empty keywords
        end

        def test_extract_keywords_removes_duplicates
          query = "machine learning artificial intelligence machine learning"
          keywords = Ragdoll::Document.extract_keywords(query: query)

          expected = %w[machine learning artificial intelligence]
          assert_equal expected.length, keywords.uniq.length # Should not have duplicates
          expected.each { |word| assert_includes keywords, word }
        end

        def test_extract_keywords_handles_punctuation
          query = "machine-learning, artificial.intelligence! natural?language"
          keywords = Ragdoll::Document.extract_keywords(query: query)

          # Should split on whitespace, keeping punctuation with words
          expected_to_include = ["machine-learning,", "artificial.intelligence!", "natural?language"]
          expected_to_include.each { |word| assert_includes keywords, word }
        end

        def test_search_by_keywords_empty_or_blank
          # Test empty array
          results = Ragdoll::Document.search_by_keywords([])
          assert_equal 0, results.count

          # Test nil
          results = Ragdoll::Document.search_by_keywords(nil)
          assert_equal 0, results.count

          # Test blank string
          results = Ragdoll::Document.search_by_keywords("")
          assert_equal 0, results.count

          # Test array with empty strings
          results = Ragdoll::Document.search_by_keywords(["", "  ", nil])
          assert_equal 0, results.count
        end

        def test_search_by_keywords_basic_functionality
          # Create test documents with keywords
          doc1 = Ragdoll::Document.create!(
            location: "/doc1.txt",
            title: "Machine Learning Guide",
            document_type: "text",
            status: "processed",
            keywords: ["machine", "learning", "ai", "python"]
          )

          doc2 = Ragdoll::Document.create!(
            location: "/doc2.txt", 
            title: "Web Development Tutorial",
            document_type: "text",
            status: "processed",
            keywords: ["web", "javascript", "html", "css"]
          )

          doc3 = Ragdoll::Document.create!(
            location: "/doc3.txt",
            title: "Data Science with Python",
            document_type: "text", 
            status: "processed",
            keywords: ["python", "data", "science", "machine"]
          )

          # Test single keyword search
          results = Ragdoll::Document.search_by_keywords(["python"])
          assert_equal 2, results.count
          result_ids = results.pluck(:id)
          assert_includes result_ids, doc1.id
          assert_includes result_ids, doc3.id

          # Test multiple keyword search - should prioritize by match count
          results = Ragdoll::Document.search_by_keywords(["machine", "python"])
          assert_equal 2, results.count
          
          # Documents should be ordered by match count (both keywords match for both docs)
          # But doc3 might come first due to created_at ordering as tiebreaker
          result_ids = results.pluck(:id) 
          assert_includes result_ids, doc1.id
          assert_includes result_ids, doc3.id

          # Test keyword that matches only one document
          results = Ragdoll::Document.search_by_keywords(["web"])
          assert_equal 1, results.count
          assert_equal doc2.id, results.first.id

          # Test non-existent keyword
          results = Ragdoll::Document.search_by_keywords(["nonexistent"])
          assert_equal 0, results.count
        end

        def test_search_by_keywords_normalization
          doc1 = Ragdoll::Document.create!(
            location: "/doc1.txt",
            title: "Test Document",
            document_type: "text", 
            status: "processed",
            keywords: ["python", "machine", "learning"]
          )

          # Test case normalization (keywords stored as lowercase)
          results = Ragdoll::Document.search_by_keywords(["PYTHON"])
          assert_equal 1, results.count
          assert_equal doc1.id, results.first.id

          # Test mixed case
          results = Ragdoll::Document.search_by_keywords(["Machine", "LEARNING"])
          assert_equal 1, results.count
          assert_equal doc1.id, results.first.id

          # Test string vs array normalization
          results = Ragdoll::Document.search_by_keywords("python")
          assert_equal 1, results.count
          assert_equal doc1.id, results.first.id
        end

        def test_search_by_keywords_match_count_scoring
          # Test that results are properly ordered by match count
          doc1 = Ragdoll::Document.create!(
            location: "/doc1.txt",
            title: "One Match",
            document_type: "text",
            status: "processed", 
            keywords: ["alpha", "beta", "gamma"]
          )

          doc2 = Ragdoll::Document.create!(
            location: "/doc2.txt",
            title: "Two Matches", 
            document_type: "text",
            status: "processed",
            keywords: ["alpha", "delta", "epsilon"] 
          )

          doc3 = Ragdoll::Document.create!(
            location: "/doc3.txt",
            title: "Three Matches",
            document_type: "text", 
            status: "processed",
            keywords: ["alpha", "beta", "delta", "zeta"]
          )

          # Search for keywords that will give different match counts
          results = Ragdoll::Document.search_by_keywords(["alpha", "beta", "delta"])
          
          assert_equal 3, results.count
          
          # Results should be ordered by match count (descending)
          # doc3 has 3 matches: alpha, beta, delta
          # doc1 has 2 matches: alpha, beta  
          # doc2 has 2 matches: alpha, delta
          assert_equal doc3.id, results[0].id  # 3 matches
          
          # doc1 and doc2 both have 2 matches, order determined by created_at (newer first in desc order)
          second_and_third_ids = [results[1].id, results[2].id]
          assert_includes second_and_third_ids, doc1.id
          assert_includes second_and_third_ids, doc2.id

          # TODO: keywords_match_count would require additional SQL for match counting
          # assert_respond_to results.first, :keywords_match_count
          # assert_equal 3, results.first.keywords_match_count
        end

        def test_search_by_keywords_limit_option
          # Create more documents than default limit 
          25.times do |i|
            Ragdoll::Document.create!(
              location: "/doc#{i}.txt",
              title: "Test Doc #{i}",
              document_type: "text", 
              status: "processed",
              keywords: ["common", "keyword#{i}"]
            )
          end

          # Test default limit (20)
          results = Ragdoll::Document.search_by_keywords(["common"])
          assert_equal 20, results.count

          # Test custom limit
          results = Ragdoll::Document.search_by_keywords(["common"], limit: 10)
          assert_equal 10, results.count

          # Test limit larger than available results
          results = Ragdoll::Document.search_by_keywords(["nonexistent"], limit: 100)
          assert_equal 0, results.count
        end

        def test_search_by_keywords_all_basic
          doc1 = Ragdoll::Document.create!(
            location: "/doc1.txt", 
            title: "Partial Match",
            document_type: "text",
            status: "processed",
            keywords: ["ruby", "programming"]
          )

          doc2 = Ragdoll::Document.create!(
            location: "/doc2.txt",
            title: "Full Match",
            document_type: "text", 
            status: "processed", 
            keywords: ["ruby", "programming", "web", "development"]
          )

          doc3 = Ragdoll::Document.create!(
            location: "/doc3.txt",
            title: "Exact Match", 
            document_type: "text",
            status: "processed",
            keywords: ["ruby", "programming"] 
          )

          # Test search_by_keywords_all - should only return docs with ALL keywords
          results = Ragdoll::Document.search_by_keywords_all(["ruby", "programming"])
          assert_equal 3, results.count  # All three docs contain both keywords
          
          # Test with additional keyword that only doc2 has
          results = Ragdoll::Document.search_by_keywords_all(["ruby", "programming", "web"])
          assert_equal 1, results.count
          assert_equal doc2.id, results.first.id

          # Test with keyword that no document has all of
          results = Ragdoll::Document.search_by_keywords_all(["ruby", "programming", "nonexistent"])
          assert_equal 0, results.count
        end

        def test_search_by_keywords_all_ordering
          # Test that results are ordered by total_keywords_count (fewer keywords = more focused)
          doc1 = Ragdoll::Document.create!(
            location: "/doc1.txt",
            title: "Many Keywords",
            document_type: "text",
            status: "processed",
            keywords: ["ruby", "programming", "extra1", "extra2", "extra3", "extra4"]
          )

          doc2 = Ragdoll::Document.create!(
            location: "/doc2.txt", 
            title: "Focused Keywords",
            document_type: "text",
            status: "processed",
            keywords: ["ruby", "programming"]
          )

          results = Ragdoll::Document.search_by_keywords_all(["ruby", "programming"])
          assert_equal 2, results.count
          
          # doc2 should come first (fewer total keywords = more focused)
          assert_equal doc2.id, results[0].id
          assert_equal doc1.id, results[1].id

          # TODO: total_keywords_count would require additional SQL for keyword array length
          # assert_respond_to results.first, :total_keywords_count
          # assert_equal 2, results.first.total_keywords_count
          # assert_equal 6, results.last.total_keywords_count
        end
      end
    end
  end
end
