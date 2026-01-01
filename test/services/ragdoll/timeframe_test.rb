# frozen_string_literal: true

require "test_helper"

class TimeframeTest < Minitest::Test
  def test_normalize_with_nil_returns_nil
    result = Ragdoll::Timeframe.normalize(nil)
    assert_nil result
  end

  def test_normalize_with_range_returns_range
    start_time = 1.week.ago
    end_time = Time.current
    range = start_time..end_time

    result = Ragdoll::Timeframe.normalize(range)
    assert_instance_of Range, result
    assert_equal range, result
  end

  def test_normalize_with_date_returns_day_range
    date = Date.today
    result = Ragdoll::Timeframe.normalize(date)

    assert_instance_of Range, result
    assert_equal date.year, result.begin.year
    assert_equal date.month, result.begin.month
    assert_equal date.day, result.begin.day
    assert_equal 0, result.begin.hour
    assert_equal 23, result.end.hour
    assert_equal 59, result.end.min
    assert_equal 59, result.end.sec
  end

  def test_normalize_with_time_returns_day_range
    time = Time.current
    result = Ragdoll::Timeframe.normalize(time)

    assert_instance_of Range, result
    assert_equal 0, result.begin.hour
    assert_equal 23, result.end.hour
  end

  def test_normalize_with_datetime_returns_day_range
    datetime = DateTime.now
    result = Ragdoll::Timeframe.normalize(datetime)

    assert_instance_of Range, result
  end

  def test_normalize_with_auto_symbol_and_temporal_query
    result = Ragdoll::Timeframe.normalize(:auto, query: "what happened yesterday")

    # Returns a Result struct with :timeframe and :query
    assert_instance_of Ragdoll::Timeframe::Result, result
    assert_instance_of Range, result.timeframe
    refute_includes result.query, "yesterday"
  end

  def test_normalize_with_auto_symbol_and_non_temporal_query
    result = Ragdoll::Timeframe.normalize(:auto, query: "how does authentication work")

    assert_instance_of Ragdoll::Timeframe::Result, result
    assert_nil result.timeframe
    assert_equal "how does authentication work", result.query
  end

  def test_normalize_with_auto_requires_query
    assert_raises(Ragdoll::Core::TimeframeError) do
      Ragdoll::Timeframe.normalize(:auto)
    end
  end

  def test_normalize_with_string_today
    result = Ragdoll::Timeframe.normalize("today")

    assert_instance_of Range, result
    assert_equal Date.today.year, result.begin.year
    assert_equal Date.today.month, result.begin.month
    assert_equal Date.today.day, result.begin.day
  end

  def test_normalize_with_string_yesterday
    result = Ragdoll::Timeframe.normalize("yesterday")

    assert_instance_of Range, result
    yesterday = Date.today - 1
    assert_equal yesterday.year, result.begin.year
    assert_equal yesterday.month, result.begin.month
    assert_equal yesterday.day, result.begin.day
  end

  def test_normalize_with_string_last_week
    result = Ragdoll::Timeframe.normalize("last week")

    assert_instance_of Range, result
    # Should be a range from 7 days ago
    assert result.begin < Time.current
    assert result.end < Time.current
  end

  def test_normalize_with_unsupported_symbol_raises_error
    assert_raises(Ragdoll::Core::TimeframeError) do
      Ragdoll::Timeframe.normalize(:today)
    end
  end

  def test_normalize_with_array_of_ranges
    range1 = 1.week.ago..6.days.ago
    range2 = 3.days.ago..Time.current

    result = Ragdoll::Timeframe.normalize([range1, range2])

    assert_instance_of Array, result
    assert_equal 2, result.length
    assert_instance_of Range, result.first
    assert_instance_of Range, result.last
  end

  def test_normalize_with_empty_array_raises_error
    assert_raises(Ragdoll::Core::TimeframeError) do
      Ragdoll::Timeframe.normalize([])
    end
  end

  def test_valid_with_nil
    assert Ragdoll::Timeframe.valid?(nil)
  end

  def test_valid_with_range
    assert Ragdoll::Timeframe.valid?(1.week.ago..Time.current)
  end

  def test_valid_with_date
    assert Ragdoll::Timeframe.valid?(Date.today)
  end

  def test_valid_with_time
    assert Ragdoll::Timeframe.valid?(Time.current)
  end

  def test_valid_with_auto_symbol
    assert Ragdoll::Timeframe.valid?(:auto)
  end

  def test_valid_with_string
    assert Ragdoll::Timeframe.valid?("today")
    assert Ragdoll::Timeframe.valid?("last week")
  end

  def test_valid_with_array_of_ranges
    assert Ragdoll::Timeframe.valid?([1.week.ago..Time.current])
  end

  def test_valid_with_invalid_type
    refute Ragdoll::Timeframe.valid?(123)
    refute Ragdoll::Timeframe.valid?({})
  end

  def test_valid_with_arbitrary_symbol_is_false
    refute Ragdoll::Timeframe.valid?(:today)
    refute Ragdoll::Timeframe.valid?(:yesterday)
  end
end
