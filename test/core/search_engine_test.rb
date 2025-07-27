# frozen_string_literal: true

require_relative "test_helper"

class SearchEngineTest < Minitest::Test
  def setup
    super
    @embedding_service = Minitest::Mock.new
    @search_engine = Ragdoll::Core::SearchEngine.new(@embedding_service)
  end

  def teardown
    super
    @embedding_service&.verify
  end

  def test_initialize
    assert_equal @embedding_service.object_id,
                 @search_engine.instance_variable_get(:@embedding_service).object_id
  end

  def test_search_documents_with_default_options
    query = "test query"
    vector = Array.new(1536) { |i| (i / 1536.0) }

    @embedding_service.expect(:generate_embedding, vector, [query])

    # Create a document and text content for search
    document = Ragdoll::Core::Models::Document.create!(
      location: "/test.txt",
      title: "Test",
      document_type: "text",
      status: "processed"
    )

    text_content = document.text_contents.create!(
      content: "Test content",
      embedding_model: "test-model"
    )

    Ragdoll::Core::Models::Embedding.create!(
      embeddable: text_content,
      chunk_index: 0,
      embedding_vector: vector,
      content: "Test content"
    )

    result = @search_engine.search_documents(query)

    assert_instance_of Array, result
    assert result.length.positive?
    assert result.first[:content]
    assert result.first[:similarity]
  end

  def test_search_documents_with_nil_embedding
    query = "test query"

    @embedding_service.expect(:generate_embedding, nil, [query])

    result = @search_engine.search_documents(query)
    assert_equal [], result
  end

  def test_search_documents_with_custom_options
    query = "test query"
    vector = Array.new(1536) { |i| (i / 1536.0) }

    @embedding_service.expect(:generate_embedding, vector, [query])

    # Create multiple documents and embeddings
    3.times do |i|
      document = Ragdoll::Core::Models::Document.create!(
        location: "/test#{i}.txt",
        title: "Test #{i}",
        document_type: "text",
        status: "processed"
      )

      text_content = document.text_contents.create!(
        content: "Test content #{i}",
        embedding_model: "test-model"
      )

      Ragdoll::Core::Models::Embedding.create!(
        embeddable: text_content,
        chunk_index: 0,
        embedding_vector: vector.map { |v| v + (i * 0.01) }, # Slight variations
        content: "Test content #{i}"
      )
    end

    result = @search_engine.search_documents(query, limit: 2, threshold: 0.5)

    assert_instance_of Array, result
    assert_operator result.length, :<=, 2 # Should respect limit
  end

  def test_search_similar_content_with_string_query
    query = "test query"
    vector = Array.new(1536) { |i| (i / 1536.0) }

    @embedding_service.expect(:generate_embedding, vector, [query])

    result = @search_engine.search_similar_content(query)
    assert_instance_of Array, result
  end

  def test_search_similar_content_with_embedding_array
    vector = Array.new(1536) { |i| (i / 1536.0) }

    result = @search_engine.search_similar_content(vector)
    assert_instance_of Array, result
  end

  def test_search_similar_content_with_nil_embedding
    query = "test query"

    @embedding_service.expect(:generate_embedding, nil, [query])

    result = @search_engine.search_similar_content(query)
    assert_equal [], result
  end

  def test_search_similar_content_with_custom_options
    vector = Array.new(1536) { |i| (i / 1536.0) }

    # Create test embeddings
    document = Ragdoll::Core::Models::Document.create!(
      location: "/test.txt",
      title: "Test",
      document_type: "text",
      status: "processed"
    )

    text_content = document.text_contents.create!(
      content: "Test content",
      embedding_model: "test-model"
    )

    Ragdoll::Core::Models::Embedding.create!(
      embeddable: text_content,
      chunk_index: 0,
      embedding_vector: vector,
      content: "Test content"
    )

    result = @search_engine.search_similar_content(vector, limit: 5, threshold: 0.8)
    assert_instance_of Array, result
  end

  def test_search_with_filters
    query = "test query"
    vector = Array.new(1536) { |i| (i / 1536.0) }

    @embedding_service.expect(:generate_embedding, vector, [query])

    # Create documents with different types
    doc1 = Ragdoll::Core::Models::Document.create!(
      location: "/test1.txt",
      title: "Test 1",
      document_type: "text",
      status: "processed"
    )

    doc2 = Ragdoll::Core::Models::Document.create!(
      location: "/test2.pdf",
      title: "Test 2",
      document_type: "pdf",
      status: "processed"
    )

    # Create embeddings for both
    [doc1, doc2].each_with_index do |doc, i|
      text_content = doc.text_contents.create!(
        content: "Test content #{i}",
        embedding_model: "test-model"
      )

      Ragdoll::Core::Models::Embedding.create!(
        embeddable: text_content,
        chunk_index: 0,
        embedding_vector: vector,
        content: "Test content #{i}"
      )
    end

    # Search with document_type filter
    result = @search_engine.search_documents(query, filters: { document_type: "text" })

    assert_instance_of Array, result
    # All results should be from text documents
    result.each do |res|
      document = Ragdoll::Core::Models::Document.find(res[:document_id])
      assert_equal "text", document.document_type
    end
  end
end
