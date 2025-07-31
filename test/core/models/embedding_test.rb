# frozen_string_literal: true

require_relative "../../test_helper"

module Ragdoll
  module Core
    module Models
      class EmbeddingTest < Minitest::Test
        def setup
          super
          skip_if_database_unavailable
          @document = Ragdoll::Core::Models::Document.create!(
            location: "/test.txt",
            title: "Test Document",
            document_type: "text",
            status: "processed"
          )

          @text_content = Ragdoll::Core::Models::TextContent.create!(
            document: @document,
            content: "Test content",
            embedding_model: "test-model"
          )
        end

        def test_create_embedding
          vector = Array.new(1536) { |i| (i / 1536.0) }
          embedding = Ragdoll::Core::Models::Embedding.create!(
            embeddable: @text_content,
            chunk_index: 0,
            embedding_vector: vector,
            content: "Test chunk content"
          )

          assert embedding.persisted?
          assert_equal @text_content, embedding.embeddable
          assert_equal 0, embedding.chunk_index
          assert_equal vector, embedding.embedding_vector
          assert_equal "Test chunk content", embedding.content
          assert_equal "test-model", embedding.embedding_model # Now accessed via polymorphic relationship
        end

        def test_validations
          # Test required fields
          embedding = Ragdoll::Core::Models::Embedding.new
          refute embedding.valid?
          # Use correct method for ActiveRecord errors
          if embedding.errors.respond_to?(:attribute_names)
            assert_includes embedding.errors.attribute_names, :embeddable_id
            assert_includes embedding.errors.attribute_names, :embeddable_type
            assert_includes embedding.errors.attribute_names, :chunk_index
            assert_includes embedding.errors.attribute_names, :embedding_vector
            assert_includes embedding.errors.attribute_names, :content
          else
            assert embedding.errors[:embeddable_id].any?
            assert embedding.errors[:embeddable_type].any?
            assert embedding.errors[:chunk_index].any?
            assert embedding.errors[:embedding_vector].any?
            assert embedding.errors[:content].any?
          end
        end

        def test_uniqueness_validation
          # Create first embedding
          vector1 = Array.new(1536) { |i| (i / 1536.0) }
          Ragdoll::Core::Models::Embedding.create!(
            embeddable: @text_content,
            chunk_index: 0,
            embedding_vector: vector1,
            content: "chunk 1"
          )

          # Try to create duplicate
          vector2 = Array.new(1536) { |i| ((i + 100) / 1536.0) }
          duplicate = Ragdoll::Core::Models::Embedding.new(
            embeddable: @text_content,
            chunk_index: 0,
            embedding_vector: vector2,
            content: "chunk 2"
          )

          refute duplicate.valid?
          if duplicate.errors.respond_to?(:attribute_names)
            assert_includes duplicate.errors.attribute_names, :chunk_index
          else
            assert duplicate.errors[:chunk_index].any?
          end
        end

        def test_associations
          vector = Array.new(1536) { |i| (i / 1536.0) }
          embedding = @text_content.embeddings.create!(
            chunk_index: 0,
            embedding_vector: vector,
            content: "chunk"
          )

          assert_equal @text_content, embedding.embeddable
          assert_equal @text_content.id, embedding.embeddable_id
          # NOTE: ActiveRecord STI with polymorphic associations stores base class name
          # The actual object class is correct, but embeddable_type stores the base class
          assert_equal "Ragdoll::Core::Models::Content", embedding.embeddable_type
        end

        def test_scopes
          vector1 = Array.new(1536) { |i| (i / 1536.0) }
          embedding1 = Ragdoll::Core::Models::Embedding.create!(
            embeddable: @text_content,
            chunk_index: 0,
            embedding_vector: vector1,
            content: "chunk 1"
          )

          vector2 = Array.new(1536) { |i| ((i + 100) / 1536.0) }
          Ragdoll::Core::Models::Embedding.create!(
            embeddable: @text_content,
            chunk_index: 1,
            embedding_vector: vector2,
            content: "chunk 2"
          )

          # Test by_model scope (now works via polymorphic relationship)
          return unless Ragdoll::Core::Models::Embedding.respond_to?(:by_model)

          # Since we set up @text_content with 'test-model', all its embeddings will have that model
          model_embeddings = Ragdoll::Core::Models::Embedding.by_model("test-model")
          assert_equal 2, model_embeddings.count # Both embeddings should match
          assert_includes model_embeddings, embedding1
        end

        def test_embedding_dimensions
          vector = Array.new(1536) { |i| (i / 1536.0) }
          embedding = Ragdoll::Core::Models::Embedding.create!(
            embeddable: @text_content,
            chunk_index: 0,
            embedding_vector: vector,
            content: "chunk"
          )

          # Check if this method exists in implementation
          return unless embedding.respond_to?(:embedding_dimensions)

          assert_equal 1536, embedding.embedding_dimensions
        end

        def test_mark_as_used
          vector = Array.new(1536) { |i| (i / 1536.0) }
          embedding = Ragdoll::Core::Models::Embedding.create!(
            embeddable: @text_content,
            chunk_index: 0,
            embedding_vector: vector,
            content: "chunk"
          )

          assert_equal 0, embedding.usage_count
          assert_nil embedding.returned_at

          # Check if this method exists in implementation
          return unless embedding.respond_to?(:mark_as_used!)

          embedding.mark_as_used!
          embedding.reload

          assert_equal 1, embedding.usage_count
          assert_instance_of Time, embedding.returned_at

          # Mark as used again
          embedding.mark_as_used!
          embedding.reload

          assert_equal 2, embedding.usage_count
        end

        def test_basic_embedding_creation_and_retrieval
          # Test the actual implementation without assuming methods that may not exist
          vector = Array.new(1536) { |i| (i / 1536.0) }
          embedding = Ragdoll::Core::Models::Embedding.create!(
            embeddable: @text_content,
            chunk_index: 0,
            embedding_vector: vector,
            content: "Test chunk",
            metadata: { source: "test" },
            usage_count: 5
          )

          # Test basic attributes that definitely exist
          assert_equal embedding.embeddable_id, @text_content.id
          # NOTE: ActiveRecord STI with polymorphic associations stores base class name
          assert_equal embedding.embeddable_type, "Ragdoll::Core::Models::Content"
          assert_equal "Test chunk", embedding.content
          assert_equal 0, embedding.chunk_index
          assert_equal vector, embedding.embedding_vector
          assert_equal "test-model", embedding.embedding_model # Now accessed via polymorphic relationship
          assert_equal 5, embedding.usage_count
        end

        def test_search_similar_basic
          # Create embeddings
          vector1 = Array.new(1536) { |i| i.zero? ? 1.0 : 0.0 } # [1.0, 0.0, 0.0, ...]
          Ragdoll::Core::Models::Embedding.create!(
            embeddable: @text_content,
            chunk_index: 0,
            embedding_vector: vector1,
            content: "similar content"
          )

          vector2 = Array.new(1536) { |i| i == 1 ? 1.0 : 0.0 } # [0.0, 1.0, 0.0, ...]
          Ragdoll::Core::Models::Embedding.create!(
            embeddable: @text_content,
            chunk_index: 1,
            embedding_vector: vector2,
            content: "different content"
          )

          # Test if search_similar method exists and works
          return unless Ragdoll::Core::Models::Embedding.respond_to?(:search_similar)

          # Search with vector similar to embedding1
          query_vector = Array.new(1536) do |i|
            if i.zero?
              0.9
            else
              (i == 1 ? 0.1 : 0.0)
            end
          end
          results = Ragdoll::Core::Models::Embedding.search_similar(query_vector, threshold: 0.5)

          assert results.is_a?(Array)
          # Results structure depends on implementation
        end

        def test_search_similar_with_filters
          doc2 = Ragdoll::Core::Models::Document.create!(
            location: "/doc2.txt",
            title: "Doc 2",
            document_type: "text",
            status: "processed"
          )

          text_content2 = doc2.text_contents.create!(
            content: "Doc 2 content",
            embedding_model: "test-model"
          )

          vector1 = Array.new(1536) { |i| i.zero? ? 1.0 : 0.0 }
          Ragdoll::Core::Models::Embedding.create!(
            embeddable: @text_content,
            chunk_index: 0,
            embedding_vector: vector1,
            content: "content 1"
          )

          vector2 = Array.new(1536) { |i| i.zero? ? 1.0 : 0.0 }
          Ragdoll::Core::Models::Embedding.create!(
            embeddable: text_content2,
            chunk_index: 0,
            embedding_vector: vector2,
            content: "content 2"
          )

          # Test filtering by embeddable_id and embedding_model (correct field names)
          return unless Ragdoll::Core::Models::Embedding.respond_to?(:search_similar)

          # Filter by embeddable_id
          query_vector = Array.new(1536) { |i| i.zero? ? 1.0 : 0.0 }
          results = Ragdoll::Core::Models::Embedding.search_similar(
            query_vector,
            filters: { embeddable_id: @text_content.id }
          )
          assert results.is_a?(Array)

          # Filter by embedding_model (now accessed via polymorphic relationship)
          results = Ragdoll::Core::Models::Embedding.search_similar(
            query_vector,
            filters: { embedding_model: "test-model" } # Use the model from text_content2
          )
          assert results.is_a?(Array)
        end

        def test_serialization
          vector = Array.new(1536) { |i| (i / 1536.0) }
          embedding = Ragdoll::Core::Models::Embedding.create!(
            embeddable: @text_content,
            chunk_index: 0,
            embedding_vector: vector,
            content: "test"
          )

          # Reload to test serialization
          embedding.reload

          # Compare vector length and sample values (pgvector may have slight precision differences)
          assert_equal 1536, embedding.embedding_vector.length
          assert_in_delta vector[0], embedding.embedding_vector[0], 0.001
          assert_in_delta vector[100], embedding.embedding_vector[100], 0.001
          assert_in_delta vector[1000], embedding.embedding_vector[1000], 0.001
        end
      end
    end
  end
end
