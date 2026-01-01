# frozen_string_literal: true

require "test_helper"

class TagServiceTest < Minitest::Test
  def setup
    # Reset circuit breaker before each test to ensure test isolation
    Ragdoll::TagService.reset_circuit_breaker!
  end

  # ============================================
  # Tag Format Validation Tests
  # ============================================

  def test_valid_tag_with_simple_tag
    assert Ragdoll::TagService.valid_tag?("database")
    assert Ragdoll::TagService.valid_tag?("ruby")
    assert Ragdoll::TagService.valid_tag?("web-development")
  end

  def test_valid_tag_with_hierarchical_tag
    assert Ragdoll::TagService.valid_tag?("database:postgresql")
    assert Ragdoll::TagService.valid_tag?("ai:llm:embedding")
    assert Ragdoll::TagService.valid_tag?("web:frontend:react")
  end

  def test_valid_tag_with_numbers
    assert Ragdoll::TagService.valid_tag?("python3")
    assert Ragdoll::TagService.valid_tag?("es2023")
    assert Ragdoll::TagService.valid_tag?("web:html5")
  end

  def test_valid_tag_rejects_uppercase
    refute Ragdoll::TagService.valid_tag?("Database")
    refute Ragdoll::TagService.valid_tag?("RUBY")
    refute Ragdoll::TagService.valid_tag?("PostgreSQL")
  end

  def test_valid_tag_rejects_spaces
    refute Ragdoll::TagService.valid_tag?("web development")
    refute Ragdoll::TagService.valid_tag?("machine learning")
  end

  def test_valid_tag_rejects_special_characters
    refute Ragdoll::TagService.valid_tag?("data_science")
    refute Ragdoll::TagService.valid_tag?("c++")
    refute Ragdoll::TagService.valid_tag?("node.js")
    refute Ragdoll::TagService.valid_tag?("c#")
  end

  def test_valid_tag_rejects_empty_string
    refute Ragdoll::TagService.valid_tag?("")
  end

  def test_valid_tag_rejects_nil
    refute Ragdoll::TagService.valid_tag?(nil)
  end

  def test_valid_tag_rejects_excessive_depth
    refute Ragdoll::TagService.valid_tag?("a:b:c:d:e")  # 5 levels, max is 4
    assert Ragdoll::TagService.valid_tag?("a:b:c:d")   # 4 levels, valid
    assert Ragdoll::TagService.valid_tag?("a:b:c")     # 3 levels, valid
  end

  def test_valid_tag_rejects_self_containment
    refute Ragdoll::TagService.valid_tag?("ruby:rails:ruby")
    refute Ragdoll::TagService.valid_tag?("ai:ai")
  end

  def test_valid_tag_rejects_duplicate_segments
    refute Ragdoll::TagService.valid_tag?("web:api:api")
    refute Ragdoll::TagService.valid_tag?("database:sql:sql:query")
  end

  # ============================================
  # Parse Hierarchy Tests
  # ============================================

  def test_parse_hierarchy_simple_tag
    result = Ragdoll::TagService.parse_hierarchy("database")

    assert_equal "database", result[:full]
    assert_equal "database", result[:root]
    assert_nil result[:parent]
    assert_equal ["database"], result[:levels]
    assert_equal 1, result[:depth]
  end

  def test_parse_hierarchy_two_level_tag
    result = Ragdoll::TagService.parse_hierarchy("database:postgresql")

    assert_equal "database:postgresql", result[:full]
    assert_equal "database", result[:root]
    assert_equal "database", result[:parent]
    assert_equal ["database", "postgresql"], result[:levels]
    assert_equal 2, result[:depth]
  end

  def test_parse_hierarchy_three_level_tag
    result = Ragdoll::TagService.parse_hierarchy("ai:llm:embedding")

    assert_equal "ai:llm:embedding", result[:full]
    assert_equal "ai", result[:root]
    assert_equal "ai:llm", result[:parent]
    assert_equal ["ai", "llm", "embedding"], result[:levels]
    assert_equal 3, result[:depth]
  end

  def test_parse_hierarchy_four_level_tag
    result = Ragdoll::TagService.parse_hierarchy("cloud:aws:s3:bucket")

    assert_equal "cloud:aws:s3:bucket", result[:full]
    assert_equal "cloud", result[:root]
    assert_equal "cloud:aws:s3", result[:parent]
    assert_equal ["cloud", "aws", "s3", "bucket"], result[:levels]
    assert_equal 4, result[:depth]
  end

  # ============================================
  # Parse Tags Tests
  # ============================================

  def test_parse_tags_from_array
    input = ["database", "postgresql", "performance"]
    result = Ragdoll::TagService.parse_tags(input)

    assert_equal ["database", "postgresql", "performance"], result
  end

  def test_parse_tags_from_string_newlines
    input = "database\npostgresql\nperformance"
    result = Ragdoll::TagService.parse_tags(input)

    assert_equal ["database", "postgresql", "performance"], result
  end

  def test_parse_tags_strips_whitespace
    input = ["  database  ", " postgresql ", "performance "]
    result = Ragdoll::TagService.parse_tags(input)

    assert_equal ["database", "postgresql", "performance"], result
  end

  def test_parse_tags_removes_empty_entries
    input = ["database", "", "postgresql", "  ", "performance"]
    result = Ragdoll::TagService.parse_tags(input)

    assert_equal ["database", "postgresql", "performance"], result
  end

  def test_parse_tags_raises_for_invalid_type
    assert_raises(Ragdoll::Core::TagError) do
      Ragdoll::TagService.parse_tags(123)
    end

    assert_raises(Ragdoll::Core::TagError) do
      Ragdoll::TagService.parse_tags({})
    end
  end

  # ============================================
  # Validate and Filter Tags Tests
  # ============================================

  def test_validate_and_filter_tags_keeps_valid_tags
    input = ["database", "postgresql", "ai:llm"]
    result = Ragdoll::TagService.validate_and_filter_tags(input)

    assert_equal ["database", "postgresql", "ai:llm"], result
  end

  def test_validate_and_filter_tags_removes_invalid_format
    input = ["database", "PostgreSQL", "ai:llm"]
    result = Ragdoll::TagService.validate_and_filter_tags(input)

    assert_equal ["database", "ai:llm"], result
  end

  def test_validate_and_filter_tags_removes_excessive_depth
    input = ["database", "a:b:c:d:e", "ai:llm"]
    result = Ragdoll::TagService.validate_and_filter_tags(input)

    assert_equal ["database", "ai:llm"], result
  end

  def test_validate_and_filter_tags_removes_self_containment
    input = ["database", "ruby:rails:ruby", "ai:llm"]
    result = Ragdoll::TagService.validate_and_filter_tags(input)

    assert_equal ["database", "ai:llm"], result
  end

  def test_validate_and_filter_tags_removes_duplicates
    input = ["database", "postgresql", "database"]
    result = Ragdoll::TagService.validate_and_filter_tags(input)

    assert_equal ["database", "postgresql"], result
  end

  def test_validate_and_filter_tags_singularizes_plural_levels
    input = ["databases", "languages:python"]
    result = Ragdoll::TagService.validate_and_filter_tags(input)

    assert_includes result, "database"
    assert_includes result, "language:python"
  end

  def test_validate_and_filter_tags_preserves_skip_list_words
    input = ["rails", "kubernetes", "analytics"]
    result = Ragdoll::TagService.validate_and_filter_tags(input)

    assert_includes result, "rails"
    assert_includes result, "kubernetes"
    assert_includes result, "analytics"
  end

  # ============================================
  # Singularize Tag Levels Tests
  # ============================================

  def test_singularize_tag_levels_simple
    assert_equal "database", Ragdoll::TagService.singularize_tag_levels("databases")
    assert_equal "language", Ragdoll::TagService.singularize_tag_levels("languages")
  end

  def test_singularize_tag_levels_hierarchical
    assert_equal "database:postgresql", Ragdoll::TagService.singularize_tag_levels("databases:postgresql")
    assert_equal "language:ruby", Ragdoll::TagService.singularize_tag_levels("languages:ruby")
  end

  def test_singularize_tag_levels_preserves_skip_list
    assert_equal "rails", Ragdoll::TagService.singularize_tag_levels("rails")
    assert_equal "kubernetes", Ragdoll::TagService.singularize_tag_levels("kubernetes")
    assert_equal "analytics", Ragdoll::TagService.singularize_tag_levels("analytics")
    assert_equal "postgresql", Ragdoll::TagService.singularize_tag_levels("postgresql")
  end

  def test_singularize_tag_levels_preserves_short_words
    assert_equal "js", Ragdoll::TagService.singularize_tag_levels("js")
    assert_equal "ai", Ragdoll::TagService.singularize_tag_levels("ai")
  end

  # ============================================
  # Max Depth Tests
  # ============================================

  def test_max_depth_returns_default
    assert_equal 4, Ragdoll::TagService.max_depth
  end

  # ============================================
  # Circuit Breaker Integration Tests
  # ============================================

  def test_circuit_breaker_exists
    breaker = Ragdoll::TagService.circuit_breaker

    assert_instance_of Ragdoll::CircuitBreaker, breaker
    assert breaker.closed?
  end

  def test_reset_circuit_breaker
    # Trip the breaker
    breaker = Ragdoll::TagService.circuit_breaker
    3.times do
      begin
        breaker.call { raise "test error" }
      rescue StandardError
        # expected
      end
    end

    # Reset
    Ragdoll::TagService.reset_circuit_breaker!

    # Should be closed again
    assert Ragdoll::TagService.circuit_breaker.closed?
  end

  # ============================================
  # Extract with Custom Extractor Tests
  # ============================================

  def test_extract_with_custom_extractor
    custom_extractor = ->(content, _ontology) { ["database", "postgresql", "performance"] }

    result = Ragdoll::TagService.extract("some content", extractor: custom_extractor)

    assert_includes result, "database"
    assert_includes result, "postgresql"
    assert_includes result, "performance"
  end

  def test_extract_filters_invalid_tags_from_extractor
    custom_extractor = ->(_content, _ontology) { ["database", "PostgreSQL", "valid-tag"] }

    result = Ragdoll::TagService.extract("some content", extractor: custom_extractor)

    assert_includes result, "database"
    assert_includes result, "valid-tag"
    refute_includes result, "PostgreSQL"
  end

  def test_extract_handles_string_response
    custom_extractor = ->(_content, _ontology) { "database\npostgresql\nperformance" }

    result = Ragdoll::TagService.extract("some content", extractor: custom_extractor)

    assert_includes result, "database"
    assert_includes result, "postgresql"
    assert_includes result, "performance"
  end
end
