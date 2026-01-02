# frozen_string_literal: true

require "test_helper"

# Test harness class that includes the hybrid search modules
class HybridSearchTestHarness
  include Ragdoll::HybridSearch::RrfMerger
  include Ragdoll::HybridSearch::Filters

  # Expose private methods for testing
  public :add_results_to_merged, :update_existing_result, :build_new_result

  # Mock log method
  def log(level, message)
    # no-op for testing
  end
end

class HybridSearchModulesTest < Minitest::Test
  def setup
    super
    @harness = HybridSearchTestHarness.new
  end

  # RRF Merger Tests
  def test_merge_with_rrf_returns_array
    vector = []
    fulltext = []
    tags = []

    result = @harness.merge_with_rrf(vector, fulltext, tags)
    assert_kind_of Array, result
  end

  def test_merge_with_rrf_empty_results
    result = @harness.merge_with_rrf([], [], [])
    assert_empty result
  end

  def test_merge_with_rrf_single_vector_result
    vector = [{ "id" => 1, "content" => "Test content", "similarity" => 0.9 }]

    result = @harness.merge_with_rrf(vector, [], [])

    assert_equal 1, result.size
    assert_equal 1, result.first["id"]
    assert_includes result.first["sources"], "vector"
  end

  def test_merge_with_rrf_single_fulltext_result
    fulltext = [{ "id" => 2, "content" => "Test content", "text_rank" => 0.8 }]

    result = @harness.merge_with_rrf([], fulltext, [])

    assert_equal 1, result.size
    assert_equal 2, result.first["id"]
    assert_includes result.first["sources"], "fulltext"
  end

  def test_merge_with_rrf_single_tag_result
    tags = [{ "id" => 3, "content" => "Test content", "tag_score" => 0.7, "matched_tags" => ["ruby"] }]

    result = @harness.merge_with_rrf([], [], tags)

    assert_equal 1, result.size
    assert_equal 3, result.first["id"]
    assert_includes result.first["sources"], "tags"
  end

  def test_merge_with_rrf_combines_same_id_from_multiple_sources
    vector = [{ "id" => 1, "content" => "Test", "similarity" => 0.9 }]
    fulltext = [{ "id" => 1, "content" => "Test", "text_rank" => 0.8 }]
    tags = [{ "id" => 1, "content" => "Test", "tag_score" => 0.7, "matched_tags" => ["ruby"] }]

    result = @harness.merge_with_rrf(vector, fulltext, tags)

    assert_equal 1, result.size
    entry = result.first
    assert_equal 3, entry["sources"].size
    assert_includes entry["sources"], "vector"
    assert_includes entry["sources"], "fulltext"
    assert_includes entry["sources"], "tags"
  end

  def test_merge_with_rrf_boosts_score_for_multiple_sources
    # Same ID appearing in multiple sources should have higher RRF score
    vector = [{ "id" => 1, "content" => "Shared", "similarity" => 0.9 }]
    fulltext = [{ "id" => 1, "content" => "Shared", "text_rank" => 0.8 }]

    combined = @harness.merge_with_rrf(vector, fulltext, [])

    vector_only = [{ "id" => 2, "content" => "Single", "similarity" => 0.9 }]
    single = @harness.merge_with_rrf(vector_only, [], [])

    # Item appearing in 2 sources should have higher RRF score than single source
    assert combined.first["rrf_score"] > single.first["rrf_score"]
  end

  def test_merge_with_rrf_sorts_by_score_descending
    vector = [
      { "id" => 1, "content" => "First", "similarity" => 0.9 },
      { "id" => 2, "content" => "Second", "similarity" => 0.8 }
    ]
    fulltext = [{ "id" => 2, "content" => "Second", "text_rank" => 0.9 }]

    result = @harness.merge_with_rrf(vector, fulltext, [])

    # ID 2 appears in both sources, should rank higher
    assert_equal 2, result.first["id"]
    assert result.first["rrf_score"] >= result.last["rrf_score"]
  end

  def test_merge_preserves_similarity_from_vector
    vector = [{ "id" => 1, "content" => "Test", "similarity" => 0.95 }]

    result = @harness.merge_with_rrf(vector, [], [])

    assert_equal 0.95, result.first["similarity"]
  end

  def test_merge_preserves_text_rank_from_fulltext
    fulltext = [{ "id" => 1, "content" => "Test", "text_rank" => 0.85 }]

    result = @harness.merge_with_rrf([], fulltext, [])

    assert_equal 0.85, result.first["text_rank"]
  end

  def test_merge_preserves_matched_tags_from_tags
    tags = [{ "id" => 1, "content" => "Test", "tag_score" => 0.7, "matched_tags" => ["ruby", "rails"] }]

    result = @harness.merge_with_rrf([], [], tags)

    assert_equal ["ruby", "rails"], result.first["matched_tags"]
  end

  def test_merge_includes_rank_information
    vector = [{ "id" => 1, "content" => "Test", "similarity" => 0.9 }]
    fulltext = [
      { "id" => 2, "content" => "First", "text_rank" => 0.9 },
      { "id" => 3, "content" => "Second", "text_rank" => 0.8 }
    ]

    result = @harness.merge_with_rrf(vector, fulltext, [])

    # Find each result and check rank
    vector_item = result.find { |r| r["id"] == 1 }
    fulltext_first = result.find { |r| r["id"] == 2 }
    fulltext_second = result.find { |r| r["id"] == 3 }

    assert_equal 1, vector_item["vector_rank"]
    assert_equal 1, fulltext_first["fulltext_rank"]
    assert_equal 2, fulltext_second["fulltext_rank"]
  end

  # build_new_result Tests
  def test_build_new_result_for_vector
    result = { "id" => 1, "content" => "Test", "similarity" => 0.9, "embedding" => [0.1, 0.2] }

    entry = @harness.build_new_result(result, :vector, 1, 0.016)

    assert_equal 1, entry["id"]
    assert_equal "Test", entry["content"]
    assert_equal 0.9, entry["similarity"]
    assert_equal [0.1, 0.2], entry["embedding"]
    assert_equal 1, entry["vector_rank"]
    assert_includes entry["sources"], "vector"
  end

  def test_build_new_result_for_fulltext
    result = { "id" => 2, "content" => "Test", "text_rank" => 0.85 }

    entry = @harness.build_new_result(result, :fulltext, 2, 0.016)

    assert_equal 2, entry["id"]
    assert_equal 0.85, entry["text_rank"]
    assert_equal 2, entry["fulltext_rank"]
    assert_includes entry["sources"], "fulltext"
  end

  def test_build_new_result_for_tags
    result = { "id" => 3, "content" => "Test", "tag_score" => 0.7, "matched_tags" => ["ruby"] }

    entry = @harness.build_new_result(result, :tags, 3, 0.016)

    assert_equal 3, entry["id"]
    assert_equal 0.7, entry["tag_score"]
    assert_equal ["ruby"], entry["matched_tags"]
    assert_equal 3, entry["tag_rank"]
    assert_includes entry["sources"], "tags"
  end

  # Filter Tests
  def test_apply_filters_returns_scope_unchanged_when_blank
    scope = Ragdoll::Embedding.all

    result = @harness.apply_filters(scope, nil)
    assert_equal scope, result

    result = @harness.apply_filters(scope, {})
    assert_equal scope, result
  end

  def test_apply_timeframe_returns_scope_unchanged_when_not_range
    scope = Ragdoll::Embedding.all

    result = @harness.apply_timeframe(scope, nil)
    assert_equal scope, result

    result = @harness.apply_timeframe(scope, "not a range")
    assert_equal scope, result
  end

  def test_apply_timeframe_with_range
    scope = Ragdoll::Embedding.all
    timeframe = 1.week.ago..Time.current

    result = @harness.apply_timeframe(scope, timeframe)
    # Should return a new scope with the timeframe condition
    assert result.respond_to?(:to_a)
  end

  def test_timeframe_sql_returns_nil_when_not_range
    result = @harness.timeframe_sql(nil)
    assert_nil result

    result = @harness.timeframe_sql("not a range")
    assert_nil result
  end

  def test_timeframe_sql_returns_sql_string_for_range
    timeframe = Time.new(2024, 1, 1)..Time.new(2024, 12, 31)

    result = @harness.timeframe_sql(timeframe)

    assert_kind_of String, result
    assert_includes result, "ragdoll_embeddings.created_at"
    assert_includes result, "BETWEEN"
  end

  def test_filter_conditions_returns_array
    result = @harness.filter_conditions({})
    assert_kind_of Array, result
  end

  def test_normalize_timeframe_with_nil
    result = @harness.normalize_timeframe(nil, "test query")

    assert_kind_of Hash, result
    assert_equal "test query", result[:query]
    assert_nil result[:timeframe]
  end

  def test_normalize_timeframe_with_range
    timeframe = 1.week.ago..Time.current
    result = @harness.normalize_timeframe(timeframe, "test query")

    assert_kind_of Hash, result
    assert_equal "test query", result[:query]
    assert result[:timeframe].present?
  end

  def test_normalize_timeframe_with_auto
    result = @harness.normalize_timeframe(:auto, "documents from last week about ruby")

    assert_kind_of Hash, result
    assert result[:query].present?
    # Timeframe may or may not be extracted depending on Ragdoll::Timeframe implementation
  end

  # RRF_K constant test
  def test_rrf_k_constant_is_60
    assert_equal 60, Ragdoll::HybridSearch::RrfMerger::RRF_K
  end

  # Edge cases
  def test_merge_handles_missing_similarity
    vector = [{ "id" => 1, "content" => "Test" }]  # No similarity key

    result = @harness.merge_with_rrf(vector, [], [])

    assert_equal 0.0, result.first["similarity"]
  end

  def test_merge_handles_missing_text_rank
    fulltext = [{ "id" => 1, "content" => "Test" }]  # No text_rank key

    result = @harness.merge_with_rrf([], fulltext, [])

    assert_equal 0.0, result.first["text_rank"]
  end

  def test_merge_handles_missing_matched_tags
    tags = [{ "id" => 1, "content" => "Test", "tag_score" => 0.5 }]  # No matched_tags key

    result = @harness.merge_with_rrf([], [], tags)

    assert_equal [], result.first["matched_tags"]
  end

  def test_merge_with_large_result_sets
    vector = (1..100).map { |i| { "id" => i, "content" => "Content #{i}", "similarity" => 1.0 / i } }
    fulltext = (50..150).map { |i| { "id" => i, "content" => "Content #{i}", "text_rank" => 1.0 / i } }

    result = @harness.merge_with_rrf(vector, fulltext, [])

    # Should have 150 unique IDs (1-150)
    assert_equal 150, result.size

    # Items 50-100 appear in both sources, should rank higher
    top_10_ids = result.first(10).map { |r| r["id"] }
    # Most of the top 10 should be from the overlap
    overlap_count = top_10_ids.count { |id| id >= 50 && id <= 100 }
    assert overlap_count >= 5, "Expected more overlap items in top 10"
  end
end
