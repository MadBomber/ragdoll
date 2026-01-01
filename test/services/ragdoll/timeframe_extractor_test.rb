# frozen_string_literal: true

require "test_helper"

class TimeframeExtractorTest < Minitest::Test
  # ============================================
  # temporal? Tests
  # ============================================

  def test_temporal_with_today_query
    assert Ragdoll::TimeframeExtractor.temporal?("what happened today")
    assert Ragdoll::TimeframeExtractor.temporal?("show me today's updates")
  end

  def test_temporal_with_yesterday_query
    assert Ragdoll::TimeframeExtractor.temporal?("what happened yesterday")
    assert Ragdoll::TimeframeExtractor.temporal?("yesterday's meeting notes")
  end

  def test_temporal_with_week_query
    assert Ragdoll::TimeframeExtractor.temporal?("last week summary")
    assert Ragdoll::TimeframeExtractor.temporal?("what happened last week")
  end

  def test_temporal_with_month_query
    assert Ragdoll::TimeframeExtractor.temporal?("last month report")
  end

  def test_temporal_with_recent_query
    assert Ragdoll::TimeframeExtractor.temporal?("recent emails")
    assert Ragdoll::TimeframeExtractor.temporal?("recently received documents")
  end

  def test_temporal_with_non_temporal_query
    refute Ragdoll::TimeframeExtractor.temporal?("how does authentication work")
    refute Ragdoll::TimeframeExtractor.temporal?("explain the database schema")
    refute Ragdoll::TimeframeExtractor.temporal?("what is a circuit breaker")
  end

  def test_temporal_with_nil_or_empty
    refute Ragdoll::TimeframeExtractor.temporal?(nil)
    refute Ragdoll::TimeframeExtractor.temporal?("")
    refute Ragdoll::TimeframeExtractor.temporal?("   ")
  end

  # ============================================
  # extract Tests - Returns Result struct
  # ============================================

  def test_extract_returns_result_struct
    result = Ragdoll::TimeframeExtractor.extract("what happened today")

    assert_instance_of Ragdoll::TimeframeExtractor::Result, result
    assert_respond_to result, :query
    assert_respond_to result, :timeframe
    assert_respond_to result, :original_expression
  end

  def test_extract_today
    result = Ragdoll::TimeframeExtractor.extract("what happened today")

    assert_instance_of Range, result.timeframe
    assert_equal "today", result.original_expression
    refute_includes result.query, "today"
  end

  def test_extract_yesterday
    result = Ragdoll::TimeframeExtractor.extract("show me yesterday's emails")

    assert_instance_of Range, result.timeframe
    assert_equal "yesterday", result.original_expression
  end

  def test_extract_last_week
    result = Ragdoll::TimeframeExtractor.extract("what happened last week")

    assert_instance_of Range, result.timeframe
    assert_includes result.original_expression.downcase, "last week"
  end

  def test_extract_last_month
    result = Ragdoll::TimeframeExtractor.extract("last month summary")

    assert_instance_of Range, result.timeframe
    assert_includes result.original_expression.downcase, "last month"
  end

  def test_extract_recent
    result = Ragdoll::TimeframeExtractor.extract("recent updates")

    assert_instance_of Range, result.timeframe
    assert_includes result.original_expression.downcase, "recent"
  end

  def test_extract_recently
    result = Ragdoll::TimeframeExtractor.extract("what was recently added")

    assert_instance_of Range, result.timeframe
    assert_includes result.original_expression.downcase, "recent"
  end

  def test_extract_non_temporal_returns_nil_timeframe
    result = Ragdoll::TimeframeExtractor.extract("how does the API work")

    assert_nil result.timeframe
    assert_nil result.original_expression
    assert_equal "how does the API work", result.query
  end

  def test_extract_with_nil_or_empty
    result = Ragdoll::TimeframeExtractor.extract(nil)
    assert_nil result.timeframe

    result = Ragdoll::TimeframeExtractor.extract("")
    assert_nil result.timeframe
  end

  def test_extract_cleans_query
    result = Ragdoll::TimeframeExtractor.extract("what happened yesterday about PostgreSQL")

    assert_instance_of Range, result.timeframe
    # Query should have temporal expression removed
    refute_includes result.query, "yesterday"
    assert_includes result.query, "PostgreSQL"
  end

  def test_extract_days_ago
    result = Ragdoll::TimeframeExtractor.extract("emails from 5 days ago")

    assert_instance_of Range, result.timeframe
    assert_includes result.original_expression, "5 days ago"
  end

  def test_extract_few_days_ago
    result = Ragdoll::TimeframeExtractor.extract("notes from a few days ago")

    assert_instance_of Range, result.timeframe
    assert_includes result.original_expression.downcase, "few"
  end

  def test_extract_last_3_days
    result = Ragdoll::TimeframeExtractor.extract("in the last 3 days")

    assert_instance_of Range, result.timeframe
    # Should be a range from 3 days ago to now
    assert result.timeframe.begin < Time.current
    assert result.timeframe.end <= Time.current + 1.second
  end

  # ============================================
  # Constants Tests
  # ============================================

  def test_few_constant
    assert_equal 3, Ragdoll::TimeframeExtractor::FEW
  end

  def test_default_recent_unit_constant
    assert_equal :days, Ragdoll::TimeframeExtractor::DEFAULT_RECENT_UNIT
  end
end
