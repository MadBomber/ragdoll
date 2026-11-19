# frozen_string_literal: true

require "test_helper"

class TagTest < Minitest::Test
  def setup
    super
  end

  def teardown
    Ragdoll::Tag.delete_all
    super
  end

  # Initialization tests
  def test_tag_can_be_created_with_valid_name
    tag = Ragdoll::Tag.create!(name: "database")
    assert tag.persisted?
    assert_equal "database", tag.name
  end

  def test_tag_can_be_created_with_hierarchical_name
    tag = Ragdoll::Tag.create!(name: "database:postgresql")
    assert tag.persisted?
    assert_equal "database:postgresql", tag.name
  end

  def test_tag_can_be_created_with_deep_hierarchy
    tag = Ragdoll::Tag.create!(name: "ai:llm:embedding:model")
    assert tag.persisted?
    assert_equal "ai:llm:embedding:model", tag.name
  end

  # Validation tests
  def test_tag_requires_name
    tag = Ragdoll::Tag.new
    refute tag.valid?
    assert_includes tag.errors[:name], "can't be blank"
  end

  def test_tag_name_must_be_unique
    Ragdoll::Tag.create!(name: "unique-tag")
    duplicate = Ragdoll::Tag.new(name: "unique-tag")
    refute duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  def test_tag_name_format_allows_lowercase
    tag = Ragdoll::Tag.new(name: "lowercase")
    assert tag.valid?
  end

  def test_tag_name_format_allows_numbers
    tag = Ragdoll::Tag.new(name: "version1")
    assert tag.valid?
  end

  def test_tag_name_format_allows_hyphens
    tag = Ragdoll::Tag.new(name: "my-tag")
    assert tag.valid?
  end

  def test_tag_name_format_allows_colons_for_hierarchy
    tag = Ragdoll::Tag.new(name: "parent:child")
    assert tag.valid?
  end

  def test_tag_name_normalizes_to_lowercase
    tag = Ragdoll::Tag.new(name: "UPPERCASE")
    tag.valid?
    assert_equal "uppercase", tag.name
  end

  def test_tag_name_strips_whitespace
    tag = Ragdoll::Tag.new(name: "  spaced  ")
    tag.valid?
    assert_equal "spaced", tag.name
  end

  # Hierarchy attribute tests
  def test_root_tag_has_depth_zero
    tag = Ragdoll::Tag.create!(name: "root")
    assert_equal 0, tag.depth
  end

  def test_child_tag_has_depth_one
    tag = Ragdoll::Tag.create!(name: "parent:child")
    assert_equal 1, tag.depth
  end

  def test_grandchild_tag_has_depth_two
    tag = Ragdoll::Tag.create!(name: "parent:child:grandchild")
    assert_equal 2, tag.depth
  end

  def test_root_tag_has_nil_parent_name
    tag = Ragdoll::Tag.create!(name: "root")
    assert_nil tag.parent_name
  end

  def test_child_tag_has_parent_name
    tag = Ragdoll::Tag.create!(name: "parent:child")
    assert_equal "parent", tag.parent_name
  end

  def test_grandchild_tag_has_correct_parent_name
    tag = Ragdoll::Tag.create!(name: "parent:child:grandchild")
    assert_equal "parent:child", tag.parent_name
  end

  # Hierarchy method tests
  def test_hierarchy_returns_hash
    tag = Ragdoll::Tag.create!(name: "ai:llm")
    hierarchy = tag.hierarchy
    assert_kind_of Hash, hierarchy
  end

  def test_hierarchy_includes_full_name
    tag = Ragdoll::Tag.create!(name: "ai:llm")
    assert_equal "ai:llm", tag.hierarchy[:full]
  end

  def test_hierarchy_includes_root
    tag = Ragdoll::Tag.create!(name: "ai:llm")
    assert_equal "ai", tag.hierarchy[:root]
  end

  def test_hierarchy_includes_levels
    tag = Ragdoll::Tag.create!(name: "ai:llm:embedding")
    assert_equal %w[ai llm embedding], tag.hierarchy[:levels]
  end

  # root? method tests
  def test_root_tag_is_root
    tag = Ragdoll::Tag.create!(name: "root")
    assert tag.root?
  end

  def test_child_tag_is_not_root
    tag = Ragdoll::Tag.create!(name: "parent:child")
    refute tag.root?
  end

  # ancestors method tests
  def test_root_tag_has_no_ancestors
    tag = Ragdoll::Tag.create!(name: "root")
    assert_empty tag.ancestors
  end

  def test_child_tag_has_parent_as_ancestor
    parent = Ragdoll::Tag.create!(name: "parent")
    child = Ragdoll::Tag.create!(name: "parent:child")
    ancestors = child.ancestors
    assert_equal 1, ancestors.count
    assert_equal parent.id, ancestors.first.id
  end

  def test_grandchild_tag_has_ancestors_in_order
    parent = Ragdoll::Tag.create!(name: "parent")
    child = Ragdoll::Tag.create!(name: "parent:child")
    grandchild = Ragdoll::Tag.create!(name: "parent:child:grandchild")
    ancestors = grandchild.ancestors
    assert_equal 2, ancestors.count
    assert_equal parent.id, ancestors.first.id
    assert_equal child.id, ancestors.last.id
  end

  # children method tests
  def test_root_tag_with_no_children
    parent = Ragdoll::Tag.create!(name: "lonely")
    assert_empty parent.children
  end

  def test_root_tag_finds_direct_children
    Ragdoll::Tag.create!(name: "parent")
    child1 = Ragdoll::Tag.create!(name: "parent:child1")
    child2 = Ragdoll::Tag.create!(name: "parent:child2")
    parent = Ragdoll::Tag.find_by!(name: "parent")
    children = parent.children
    assert_equal 2, children.count
    assert_includes children.pluck(:id), child1.id
    assert_includes children.pluck(:id), child2.id
  end

  # descendants method tests
  def test_root_tag_with_no_descendants
    parent = Ragdoll::Tag.create!(name: "lonely")
    assert_empty parent.descendants
  end

  def test_root_tag_finds_all_descendants
    Ragdoll::Tag.create!(name: "parent")
    Ragdoll::Tag.create!(name: "parent:child")
    Ragdoll::Tag.create!(name: "parent:child:grandchild")
    parent = Ragdoll::Tag.find_by!(name: "parent")
    descendants = parent.descendants
    assert_equal 2, descendants.count
  end

  # find_or_create_with_hierarchy! tests
  def test_find_or_create_with_hierarchy_creates_simple_tag
    tag = Ragdoll::Tag.find_or_create_with_hierarchy!("simple")
    assert tag.persisted?
    assert_equal "simple", tag.name
  end

  def test_find_or_create_with_hierarchy_creates_parent_tags
    tag = Ragdoll::Tag.find_or_create_with_hierarchy!("parent:child:grandchild")
    assert tag.persisted?
    assert_equal "parent:child:grandchild", tag.name
    assert Ragdoll::Tag.exists?(name: "parent")
    assert Ragdoll::Tag.exists?(name: "parent:child")
  end

  def test_find_or_create_with_hierarchy_returns_existing_tag
    existing = Ragdoll::Tag.create!(name: "existing")
    tag = Ragdoll::Tag.find_or_create_with_hierarchy!("existing")
    assert_equal existing.id, tag.id
  end

  def test_find_or_create_with_hierarchy_normalizes_name
    tag = Ragdoll::Tag.find_or_create_with_hierarchy!("  PARENT:CHILD  ")
    assert_equal "parent:child", tag.name
  end

  # increment_usage! tests
  def test_increment_usage_increases_count
    tag = Ragdoll::Tag.create!(name: "popular")
    initial_count = tag.usage_count
    tag.increment_usage!
    tag.reload
    assert_equal initial_count + 1, tag.usage_count
  end

  def test_increment_usage_can_be_called_multiple_times
    tag = Ragdoll::Tag.create!(name: "popular")
    3.times { tag.increment_usage! }
    tag.reload
    assert_equal 3, tag.usage_count
  end

  # Scope tests
  def test_root_tags_scope
    Ragdoll::Tag.create!(name: "root1")
    Ragdoll::Tag.create!(name: "root2")
    Ragdoll::Tag.create!(name: "root1:child")
    roots = Ragdoll::Tag.root_tags
    assert_equal 2, roots.count
  end

  def test_by_depth_scope
    Ragdoll::Tag.create!(name: "root")
    Ragdoll::Tag.create!(name: "root:child")
    Ragdoll::Tag.create!(name: "root:child:grandchild")
    assert_equal 1, Ragdoll::Tag.by_depth(0).count
    assert_equal 1, Ragdoll::Tag.by_depth(1).count
    assert_equal 1, Ragdoll::Tag.by_depth(2).count
  end

  def test_starting_with_scope
    Ragdoll::Tag.create!(name: "database")
    Ragdoll::Tag.create!(name: "database:postgresql")
    Ragdoll::Tag.create!(name: "ai:llm")
    matches = Ragdoll::Tag.starting_with("database")
    assert_equal 2, matches.count
  end

  def test_by_usage_scope
    tag1 = Ragdoll::Tag.create!(name: "popular")
    tag2 = Ragdoll::Tag.create!(name: "less-popular")
    3.times { tag1.increment_usage! }
    tag2.increment_usage!
    sorted = Ragdoll::Tag.by_usage
    assert_equal tag1.id, sorted.first.id
  end
end
