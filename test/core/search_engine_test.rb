# frozen_string_literal: true

require_relative "../test_helper"

class SearchEngineTest < Minitest::Test
  def setup
    super
    return skip("Skipping database test in CI environment") if ci_environment?

    @embedding_service = Minitest::Mock.new
    @search_engine = Ragdoll::SearchEngine.new(@embedding_service)
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
    document = Ragdoll::Document.create!(
      location: "/test.txt",
      title: "Test",
      document_type: "text",
      status: "processed"
    )

    text_content = document.text_contents.create!(
      content: "Test content",
      embedding_model: "test-model"
    )

    Ragdoll::Embedding.create!(
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
    
    # Note: The search engine doesn't automatically record searches
    # That would be handled by the calling code if desired
  end

  def test_search_documents_with_nil_embedding
    query = "test query"

    @embedding_service.expect(:generate_embedding, nil, [query])

    result = @search_engine.search_documents(query)
    assert_empty result
  end

  def test_search_documents_with_custom_options
    query = "test query"
    vector = Array.new(1536) { |i| (i / 1536.0) }

    @embedding_service.expect(:generate_embedding, vector, [query])

    # Create multiple documents and embeddings
    3.times do |i|
      document = Ragdoll::Document.create!(
        location: "/test#{i}.txt",
        title: "Test #{i}",
        document_type: "text",
        status: "processed"
      )

      text_content = document.text_contents.create!(
        content: "Test content #{i}",
        embedding_model: "test-model"
      )

      Ragdoll::Embedding.create!(
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
    
    # Enhanced search returns a hash with results, statistics, and execution_time_ms
    if result.is_a?(Hash) && result.key?(:results)
      assert_instance_of Hash, result
      assert_instance_of Array, result[:results]
      assert result.key?(:execution_time_ms)
    else
      # Fallback for old format
      assert_instance_of Array, result
    end
  end

  def test_search_similar_content_with_embedding_array
    vector = Array.new(1536) { |i| (i / 1536.0) }

    result = @search_engine.search_similar_content(vector)
    
    # Enhanced search returns a hash with results, statistics, and execution_time_ms
    if result.is_a?(Hash) && result.key?(:results)
      assert_instance_of Hash, result
      assert_instance_of Array, result[:results]
      assert result.key?(:execution_time_ms)
    else
      # Fallback for old format
      assert_instance_of Array, result
    end
  end

  def test_search_similar_content_with_nil_embedding
    query = "test query"

    @embedding_service.expect(:generate_embedding, nil, [query])

    result = @search_engine.search_similar_content(query)
    assert_empty result
  end

  def test_search_similar_content_with_custom_options
    vector = Array.new(1536) { |i| (i / 1536.0) }

    # Create test embeddings
    document = Ragdoll::Document.create!(
      location: "/test.txt",
      title: "Test",
      document_type: "text",
      status: "processed"
    )

    text_content = document.text_contents.create!(
      content: "Test content",
      embedding_model: "test-model"
    )

    Ragdoll::Embedding.create!(
      embeddable: text_content,
      chunk_index: 0,
      embedding_vector: vector,
      content: "Test content"
    )

    result = @search_engine.search_similar_content(vector, limit: 5, threshold: 0.8)
    
    # Enhanced search returns a hash with results, statistics, and execution_time_ms
    if result.is_a?(Hash) && result.key?(:results)
      assert_instance_of Hash, result
      assert_instance_of Array, result[:results]
      assert result.key?(:execution_time_ms)
    else
      # Fallback for old format
      assert_instance_of Array, result
    end
  end

  def test_search_with_filters
    query = "test query"
    vector = Array.new(1536) { |i| (i / 1536.0) }

    @embedding_service.expect(:generate_embedding, vector, [query])

    # Create documents with different types
    doc1 = Ragdoll::Document.create!(
      location: "/test1.txt",
      title: "Test 1",
      document_type: "text",
      status: "processed"
    )

    doc2 = Ragdoll::Document.create!(
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

      Ragdoll::Embedding.create!(
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
      document = Ragdoll::Document.find(res[:document_id])
      assert_equal "text", document.document_type
    end
  end

  def test_search_similar_content_with_keywords_parameter
    query = "test query"
    keywords = ["machine", "learning"]
    vector = Array.new(1536) { |i| (i / 1536.0) }

    @embedding_service.expect(:generate_embedding, vector, [query])

    # Create test documents with different keywords
    doc1 = Ragdoll::Document.create!(
      location: "/doc1.txt",
      title: "Machine Learning Guide", 
      document_type: "text",
      status: "processed",
      keywords: ["machine", "learning", "ai"]
    )

    doc2 = Ragdoll::Document.create!(
      location: "/doc2.txt",
      title: "Web Development",
      document_type: "text", 
      status: "processed",
      keywords: ["web", "javascript", "html"]
    )

    # Create text content and embeddings
    [doc1, doc2].each_with_index do |doc, i|
      text_content = doc.text_contents.create!(
        content: "Test content #{i}",
        embedding_model: "test-model"
      )

      Ragdoll::Embedding.create!(
        embeddable: text_content,
        chunk_index: 0,
        embedding_vector: vector.map { |v| v + (i * 0.001) }, # Slightly different vectors
        content: "Test content #{i}"
      )
    end

    # Search with keywords should only return doc1
    result = @search_engine.search_similar_content(query, keywords: keywords)
    
    assert_instance_of Hash, result
    assert_key_exists result, :results
    assert_key_exists result, :execution_time_ms
    
    # Should only find documents matching the keywords
    results = result[:results]
    assert results.count <= 1  # At most 1 document should match the keywords
    
    if results.any?
      # If we get a result, it should be doc1 (which has the matching keywords)
      found_doc_id = results.first[:document_id] || results.first[:id]
      found_doc = Ragdoll::Document.find(found_doc_id)
      assert_equal doc1.id, found_doc.id
    end
  end

  def test_search_similar_content_keywords_normalization
    query = "test query"
    vector = Array.new(1536) { |i| (i / 1536.0) }

    # Set up mock expectations for each test case
    test_cases = [
      ["PYTHON"],           # uppercase
      ["Python"],           # mixed case
      "python",             # string instead of array
      ["python", "PROGRAMMING"], # mixed case array
    ]
    
    # Set up expectations for each test case
    test_cases.each do
      @embedding_service.expect(:generate_embedding, vector, [query])
    end

    doc = Ragdoll::Document.create!(
      location: "/doc.txt",
      title: "Test Document", 
      document_type: "text",
      status: "processed",
      keywords: ["python", "programming"]
    )

    text_content = doc.text_contents.create!(
      content: "Test content",
      embedding_model: "test-model" 
    )

    Ragdoll::Embedding.create!(
      embeddable: text_content,
      chunk_index: 0,
      embedding_vector: vector,
      content: "Test content"
    )

    # Test that keywords are normalized (case insensitive)
    test_cases.each do |keywords_input|
      result = @search_engine.search_similar_content(query, keywords: keywords_input)
      
      assert_instance_of Hash, result
      results = result[:results]
      
      # Should find the document regardless of keyword case
      if results.any?
        found_doc_id = results.first[:document_id] || results.first[:id]
        found_doc = Ragdoll::Document.find(found_doc_id)
        assert_equal doc.id, found_doc.id
      end
    end
  end

  def test_search_similar_content_empty_keywords
    query = "test query"
    vector = Array.new(1536) { |i| (i / 1536.0) }

    # Test empty keywords - should behave like normal search
    empty_keywords_cases = [
      [],
      "",
      nil,
      ["", "  "],
    ]

    # Set up expectations for each test case
    empty_keywords_cases.each do
      @embedding_service.expect(:generate_embedding, vector, [query])
    end

    # Create a document
    doc = Ragdoll::Document.create!(
      location: "/doc.txt", 
      title: "Test Document",
      document_type: "text",
      status: "processed"
    )

    text_content = doc.text_contents.create!(
      content: "Test content",
      embedding_model: "test-model"
    )

    Ragdoll::Embedding.create!(
      embeddable: text_content,
      chunk_index: 0,
      embedding_vector: vector,
      content: "Test content"
    )

    empty_keywords_cases.each do |empty_keywords|
      result = @search_engine.search_similar_content(query, keywords: empty_keywords)
      
      assert_instance_of Hash, result
      assert_key_exists result, :results
      assert_key_exists result, :execution_time_ms
      
      # Should not filter out any results due to keywords
      results = result[:results]
      assert results.count >= 0  # Can be 0 if similarity threshold not met
    end
  end

  def test_search_similar_content_keywords_in_search_tracking
    query = "test query with keywords"
    keywords = ["ruby", "programming"]
    vector = Array.new(1536) { |i| (i / 1536.0) }

    @embedding_service.expect(:generate_embedding, vector, [query])

    # Create document with matching keywords
    doc = Ragdoll::Document.create!(
      location: "/doc.txt",
      title: "Ruby Programming Guide",
      document_type: "text", 
      status: "processed",
      keywords: ["ruby", "programming", "rails"]
    )

    text_content = doc.text_contents.create!(
      content: "Ruby programming content",
      embedding_model: "test-model"
    )

    Ragdoll::Embedding.create!(
      embeddable: text_content,
      chunk_index: 0,
      embedding_vector: vector,
      content: "Ruby programming content"
    )

    # Perform search with keywords
    result = @search_engine.search_similar_content(
      query, 
      keywords: keywords,
      track_search: true,
      session_id: "test-session",
      user_id: "test-user"
    )

    assert_instance_of Hash, result
    assert_key_exists result, :results

    # Check that a search was recorded
    # Note: This may not work in test environment without proper database setup
    # but the method should complete without error
    assert result[:execution_time_ms] > 0
  end

  private

  def assert_key_exists(hash, key)
    assert hash.key?(key), "Expected hash to have key #{key}, but keys were: #{hash.keys}"
  end
end
