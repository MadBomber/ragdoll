# frozen_string_literal: true

require "test_helper"

module Ragdoll
  module Workflows
    class HybridSearchWorkflowTest < Minitest::Test
      # ============================================
      # Constants Tests
      # ============================================

      def test_rrf_k_constant
        assert_equal 60, Ragdoll::Workflows::HybridSearchWorkflow::RRF_K
      end

      def test_candidate_multiplier_constant
        assert_equal 3, Ragdoll::Workflows::HybridSearchWorkflow::CANDIDATE_MULTIPLIER
      end

      def test_max_hybrid_limit_constant
        assert_equal 1000, Ragdoll::Workflows::HybridSearchWorkflow::MAX_HYBRID_LIMIT
      end

      # ============================================
      # RRF Merge Algorithm Tests
      # ============================================

      def setup
        # Create a workflow instance for testing RRF logic
        @workflow = Ragdoll::Workflows::HybridSearchWorkflow.allocate
        @workflow.instance_variable_set(:@embedding_service, nil)
        @workflow.instance_variable_set(:@concurrency, :auto)
      end

      def test_merge_with_rrf_empty_inputs
        merged = @workflow.send(:merge_with_rrf, [], [], [])
        assert_equal [], merged
      end

      def test_merge_with_rrf_single_vector_result
        vector_results = [
          { 'id' => 1, 'content' => 'Test content', 'similarity' => 0.9 }
        ]

        merged = @workflow.send(:merge_with_rrf, vector_results, [], [])

        assert_equal 1, merged.length
        assert_equal 1, merged.first['id']
        assert_equal 0.9, merged.first['similarity']
        assert_equal ['vector'], merged.first['sources']
        assert_equal 1, merged.first['vector_rank']
      end

      def test_merge_with_rrf_single_fulltext_result
        fulltext_results = [
          { 'id' => 2, 'content' => 'Text content', 'text_rank' => 1.5 }
        ]

        merged = @workflow.send(:merge_with_rrf, [], fulltext_results, [])

        assert_equal 1, merged.length
        assert_equal 2, merged.first['id']
        assert_equal 1.5, merged.first['text_rank']
        assert_equal ['fulltext'], merged.first['sources']
      end

      def test_merge_with_rrf_single_tag_result
        tag_results = [
          { 'id' => 3, 'content' => 'Tagged content', 'matched_tags' => ['db'], 'tag_score' => 1.0 }
        ]

        merged = @workflow.send(:merge_with_rrf, [], [], tag_results)

        assert_equal 1, merged.length
        assert_equal 3, merged.first['id']
        assert_equal ['db'], merged.first['matched_tags']
        assert_equal 1.0, merged.first['tag_score']
        assert_equal ['tags'], merged.first['sources']
      end

      def test_merge_with_rrf_boosts_multi_source_items
        # Same ID in multiple sources gets boosted
        vector_results = [{ 'id' => 1, 'content' => 'Content', 'similarity' => 0.9 }]
        fulltext_results = [{ 'id' => 1, 'content' => 'Content', 'text_rank' => 1.5 }]

        merged = @workflow.send(:merge_with_rrf, vector_results, fulltext_results, [])

        assert_equal 1, merged.length

        # RRF score should be 2 * (1 / (60 + 1)) = 2/61
        expected_score = 2.0 / 61
        assert_in_delta expected_score, merged.first['rrf_score'], 0.001

        # Should have both sources
        assert_includes merged.first['sources'], 'vector'
        assert_includes merged.first['sources'], 'fulltext'
      end

      def test_merge_with_rrf_triple_source_boost
        # Same ID in all three sources
        vector_results = [{ 'id' => 1, 'content' => 'Content', 'similarity' => 0.9 }]
        fulltext_results = [{ 'id' => 1, 'content' => 'Content', 'text_rank' => 1.5 }]
        tag_results = [{ 'id' => 1, 'content' => 'Content', 'matched_tags' => ['db'], 'tag_score' => 1.0 }]

        merged = @workflow.send(:merge_with_rrf, vector_results, fulltext_results, tag_results)

        assert_equal 1, merged.length

        # RRF score should be 3 * (1 / (60 + 1)) = 3/61
        expected_score = 3.0 / 61
        assert_in_delta expected_score, merged.first['rrf_score'], 0.001

        # Should have all three sources
        assert_includes merged.first['sources'], 'vector'
        assert_includes merged.first['sources'], 'fulltext'
        assert_includes merged.first['sources'], 'tags'
      end

      def test_merge_with_rrf_sorts_by_score_descending
        # Item in two sources should rank above item in one source
        vector_results = [
          { 'id' => 1, 'content' => 'Boosted', 'similarity' => 0.8 },
          { 'id' => 2, 'content' => 'Single source', 'similarity' => 0.95 }
        ]
        fulltext_results = [
          { 'id' => 1, 'content' => 'Boosted', 'text_rank' => 1.5 }
        ]

        merged = @workflow.send(:merge_with_rrf, vector_results, fulltext_results, [])

        # Item 1 (boosted) should be first despite item 2 having higher similarity
        assert_equal 1, merged.first['id']
        assert_equal 2, merged.last['id']
      end

      def test_merge_with_rrf_tracks_rank_per_source
        vector_results = [
          { 'id' => 1, 'content' => 'First', 'similarity' => 0.9 },
          { 'id' => 2, 'content' => 'Second', 'similarity' => 0.8 }
        ]
        fulltext_results = [
          { 'id' => 2, 'content' => 'Second', 'text_rank' => 1.8 },
          { 'id' => 1, 'content' => 'First', 'text_rank' => 1.5 }
        ]

        merged = @workflow.send(:merge_with_rrf, vector_results, fulltext_results, [])

        # Find items by ID
        item_1 = merged.find { |r| r['id'] == 1 }
        item_2 = merged.find { |r| r['id'] == 2 }

        # Check rank tracking
        assert_equal 1, item_1['vector_rank']
        assert_equal 2, item_1['fulltext_rank']

        assert_equal 2, item_2['vector_rank']
        assert_equal 1, item_2['fulltext_rank']
      end

      # ============================================
      # Helper Method Tests
      # ============================================

      def test_normalize_timeframe_with_nil
        result = @workflow.send(:normalize_timeframe, nil, "test query")

        assert_equal "test query", result[:query]
        assert_nil result[:timeframe]
      end

      def test_normalize_timeframe_with_range
        range = 1.week.ago..Time.current
        result = @workflow.send(:normalize_timeframe, range, "test query")

        assert_equal "test query", result[:query]
        assert_instance_of Range, result[:timeframe]
      end

      def test_apply_timeframe_with_nil
        scope = Object.new
        result = @workflow.send(:apply_timeframe, scope, nil)

        assert_equal scope, result
      end

      def test_timeframe_sql_with_nil
        result = @workflow.send(:timeframe_sql, nil)
        assert_nil result
      end

      def test_timeframe_sql_with_range
        range = 1.week.ago..Time.current
        result = @workflow.send(:timeframe_sql, range)

        # Should produce a SQL BETWEEN clause
        assert_includes result, "ragdoll_embeddings.created_at BETWEEN"
        assert_includes result, "AND"
      end
    end
  end
end
