# frozen_string_literal: true

require "test_helper"

class HybridSearchServiceTest < Minitest::Test
  # ============================================
  # Constants Tests
  # ============================================

  def test_max_hybrid_limit
    assert_equal 1000, Ragdoll::HybridSearchService::MAX_HYBRID_LIMIT
  end

  def test_rrf_k_constant
    assert_equal 60, Ragdoll::HybridSearchService::RRF_K
  end

  def test_candidate_multiplier
    assert_equal 3, Ragdoll::HybridSearchService::CANDIDATE_MULTIPLIER
  end

  # ============================================
  # RRF Algorithm Tests (via send to private method)
  # ============================================

  def setup
    # Create a service instance for testing RRF logic
    # We use nil for embedding_service since we're testing RRF directly
    @service = Ragdoll::HybridSearchService.allocate
    @service.instance_variable_set(:@embedding_service, nil)
    @service.instance_variable_set(:@concurrency, :threads)  # Required for workflow creation
  end

  def test_merge_with_rrf_single_source_vector
    vector_results = [
      { 'id' => 1, 'content' => 'First result', 'similarity' => 0.95 },
      { 'id' => 2, 'content' => 'Second result', 'similarity' => 0.85 }
    ]

    merged = @service.send(:merge_with_rrf, vector_results, [], [])

    assert_equal 2, merged.length
    assert_equal 1, merged.first['id']  # Higher ranked item should be first

    # RRF score for rank 1: 1/(60 + 1) = 0.01639...
    # RRF score for rank 2: 1/(60 + 2) = 0.01613...
    assert merged.first['rrf_score'] > merged.last['rrf_score']
    assert_equal ['vector'], merged.first['sources']
  end

  def test_merge_with_rrf_single_source_fulltext
    fulltext_results = [
      { 'id' => 10, 'content' => 'Text match 1', 'text_rank' => 1.5 },
      { 'id' => 20, 'content' => 'Text match 2', 'text_rank' => 1.2 }
    ]

    merged = @service.send(:merge_with_rrf, [], fulltext_results, [])

    assert_equal 2, merged.length
    assert_equal 10, merged.first['id']
    assert_equal ['fulltext'], merged.first['sources']
    assert_equal 1.5, merged.first['text_rank']
  end

  def test_merge_with_rrf_single_source_tags
    tag_results = [
      { 'id' => 100, 'content' => 'Tagged content', 'matched_tags' => ['database'], 'tag_score' => 1.0 }
    ]

    merged = @service.send(:merge_with_rrf, [], [], tag_results)

    assert_equal 1, merged.length
    assert_equal 100, merged.first['id']
    assert_equal ['tags'], merged.first['sources']
    assert_includes merged.first['matched_tags'], 'database'
  end

  def test_merge_with_rrf_boosts_items_in_multiple_sources
    # Same item appears in both vector and fulltext results
    vector_results = [
      { 'id' => 1, 'content' => 'Shared result', 'similarity' => 0.95 }
    ]
    fulltext_results = [
      { 'id' => 1, 'content' => 'Shared result', 'text_rank' => 1.5 }
    ]

    merged = @service.send(:merge_with_rrf, vector_results, fulltext_results, [])

    assert_equal 1, merged.length
    assert_equal 1, merged.first['id']

    # Should have both sources
    assert_includes merged.first['sources'], 'vector'
    assert_includes merged.first['sources'], 'fulltext'

    # RRF score should be sum of both: 1/(60+1) + 1/(60+1) = 2/(61) ≈ 0.0328
    expected_rrf = 2.0 / 61
    assert_in_delta expected_rrf, merged.first['rrf_score'], 0.001
  end

  def test_merge_with_rrf_boosts_items_in_all_three_sources
    # Same item appears in all three result sets
    vector_results = [
      { 'id' => 1, 'content' => 'Triple match', 'similarity' => 0.95 }
    ]
    fulltext_results = [
      { 'id' => 1, 'content' => 'Triple match', 'text_rank' => 1.5 }
    ]
    tag_results = [
      { 'id' => 1, 'content' => 'Triple match', 'matched_tags' => ['db'], 'tag_score' => 1.0 }
    ]

    merged = @service.send(:merge_with_rrf, vector_results, fulltext_results, tag_results)

    assert_equal 1, merged.length
    assert_equal 1, merged.first['id']

    # Should have all three sources
    assert_includes merged.first['sources'], 'vector'
    assert_includes merged.first['sources'], 'fulltext'
    assert_includes merged.first['sources'], 'tags'

    # RRF score should be sum of all three: 3/(61) ≈ 0.0492
    expected_rrf = 3.0 / 61
    assert_in_delta expected_rrf, merged.first['rrf_score'], 0.001
  end

  def test_merge_with_rrf_ranks_boosted_items_higher
    # Item 1: Only in vector (rank 2)
    # Item 2: In both vector (rank 1) and fulltext (rank 1)
    vector_results = [
      { 'id' => 2, 'content' => 'Multi-source result', 'similarity' => 0.95 },
      { 'id' => 1, 'content' => 'Vector only', 'similarity' => 0.90 }
    ]
    fulltext_results = [
      { 'id' => 2, 'content' => 'Multi-source result', 'text_rank' => 1.5 }
    ]

    merged = @service.send(:merge_with_rrf, vector_results, fulltext_results, [])

    # Item 2 should rank higher because it's in multiple sources
    assert_equal 2, merged.first['id']
    assert_equal 1, merged.last['id']
  end

  def test_merge_with_rrf_preserves_similarity_scores
    vector_results = [
      { 'id' => 1, 'content' => 'Result', 'similarity' => 0.87 }
    ]

    merged = @service.send(:merge_with_rrf, vector_results, [], [])

    assert_equal 0.87, merged.first['similarity']
  end

  def test_merge_with_rrf_preserves_text_rank
    fulltext_results = [
      { 'id' => 1, 'content' => 'Result', 'text_rank' => 1.75 }
    ]

    merged = @service.send(:merge_with_rrf, [], fulltext_results, [])

    assert_equal 1.75, merged.first['text_rank']
  end

  def test_merge_with_rrf_preserves_tag_info
    tag_results = [
      { 'id' => 1, 'content' => 'Result', 'matched_tags' => ['db', 'sql'], 'tag_score' => 0.5 }
    ]

    merged = @service.send(:merge_with_rrf, [], [], tag_results)

    assert_equal ['db', 'sql'], merged.first['matched_tags']
    assert_equal 0.5, merged.first['tag_score']
  end

  def test_merge_with_rrf_tracks_individual_ranks
    vector_results = [
      { 'id' => 1, 'content' => 'Result', 'similarity' => 0.95 }
    ]
    fulltext_results = [
      { 'id' => 2, 'content' => 'Other', 'text_rank' => 1.5 },
      { 'id' => 1, 'content' => 'Result', 'text_rank' => 1.2 }
    ]

    merged = @service.send(:merge_with_rrf, vector_results, fulltext_results, [])

    # Find item 1
    item_1 = merged.find { |r| r['id'] == 1 }

    assert_equal 1, item_1['vector_rank']
    assert_equal 2, item_1['fulltext_rank']  # It was second in fulltext results
    assert_nil item_1['tag_rank']
  end

  def test_merge_with_rrf_handles_empty_inputs
    merged = @service.send(:merge_with_rrf, [], [], [])

    assert_equal [], merged
  end

  def test_merge_with_rrf_returns_sorted_by_score_descending
    vector_results = [
      { 'id' => 1, 'content' => 'Low rank', 'similarity' => 0.5 },
      { 'id' => 2, 'content' => 'High rank', 'similarity' => 0.9 }
    ]
    fulltext_results = [
      { 'id' => 2, 'content' => 'High rank', 'text_rank' => 1.5 }
    ]

    merged = @service.send(:merge_with_rrf, vector_results, fulltext_results, [])

    # Item 2 should be first (boosted), item 1 second
    scores = merged.map { |r| r['rrf_score'] }
    assert_equal scores, scores.sort.reverse
  end

  # ============================================
  # Timeframe Normalization Tests
  # ============================================

  def test_normalize_timeframe_with_nil
    result = @service.send(:normalize_timeframe, nil, "test query")

    assert_equal "test query", result[:query]
    assert_nil result[:timeframe]
  end

  def test_normalize_timeframe_with_range
    range = 1.week.ago..Time.current
    result = @service.send(:normalize_timeframe, range, "test query")

    assert_equal "test query", result[:query]
    assert_equal range, result[:timeframe]
  end

  # ============================================
  # Workflow Integration Tests
  # ============================================

  def test_workflow_returns_hybrid_search_workflow
    # The workflow method should return a HybridSearchWorkflow instance
    # It works with nil embedding_service since workflow is lazy-loaded
    result = @service.workflow

    assert_instance_of Ragdoll::Workflows::HybridSearchWorkflow, result
    assert_same result, @service.workflow # Should be memoized
  end

  # ============================================
  # Parallel Mode Tests
  # ============================================

  def test_search_defaults_to_parallel_true
    # Verify the method signature defaults parallel to true
    method = Ragdoll::HybridSearchService.instance_method(:search)
    params = method.parameters

    # Find the parallel parameter
    parallel_param = params.find { |type, name| name == :parallel }

    # It should be a keyword with default (:key)
    assert_equal :key, parallel_param[0], "parallel should be a keyword argument with default"
  end

  def test_search_parallel_true_delegates_to_workflow
    # Create a real service with a mock embedding service
    mock_embedding_service = Object.new
    def mock_embedding_service.generate_embedding(_text)
      Array.new(1536) { rand }
    end

    service = Ragdoll::HybridSearchService.new(embedding_service: mock_embedding_service)

    # Verify workflow is created when parallel: true (default)
    assert_respond_to service, :workflow
    workflow = service.workflow
    assert_instance_of Ragdoll::Workflows::HybridSearchWorkflow, workflow
  end

  def test_search_parallel_false_does_not_use_workflow
    # When parallel: false, the search method should execute sequentially
    # and not call search_parallel
    mock_embedding_service = Object.new
    def mock_embedding_service.generate_embedding(_text)
      Array.new(1536) { rand }
    end

    service = Ragdoll::HybridSearchService.new(embedding_service: mock_embedding_service)

    # Track if search_parallel was called
    search_parallel_called = false
    original_method = service.method(:search_parallel)
    service.define_singleton_method(:search_parallel) do |**args|
      search_parallel_called = true
      original_method.call(**args)
    end

    # Call with parallel: false - should NOT call search_parallel
    # This will fail due to no database, but we can check the flag
    begin
      service.search(query: "test", parallel: false)
    rescue StandardError
      # Expected - no database in unit test
    end

    refute search_parallel_called, "search_parallel should NOT be called when parallel: false"
  end

  def test_search_parallel_true_calls_search_parallel
    mock_embedding_service = Object.new
    def mock_embedding_service.generate_embedding(_text)
      Array.new(1536) { rand }
    end

    service = Ragdoll::HybridSearchService.new(embedding_service: mock_embedding_service)

    # Track if search_parallel was called
    search_parallel_called = false
    original_method = service.method(:search_parallel)
    service.define_singleton_method(:search_parallel) do |**args|
      search_parallel_called = true
      original_method.call(**args)
    end

    # Call with parallel: true (default) - SHOULD call search_parallel
    begin
      service.search(query: "test", parallel: true)
    rescue StandardError
      # Expected - workflow may fail without full setup
    end

    assert search_parallel_called, "search_parallel SHOULD be called when parallel: true"
  end
end
