# frozen_string_literal: true

require "test_helper"

class VersionTest < Minitest::Test
  def test_version_is_defined
    assert defined?(Ragdoll::Core::VERSION)
  end

  def test_version_is_a_string
    assert_kind_of String, Ragdoll::Core::VERSION
  end

  def test_version_is_not_empty
    refute Ragdoll::Core::VERSION.empty?
  end

  def test_version_matches_semantic_versioning_format
    # Semantic versioning: MAJOR.MINOR.PATCH with optional prerelease
    semver_regex = /\A\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?\z/
    assert_match semver_regex, Ragdoll::Core::VERSION
  end

  def test_version_can_be_compared
    current = Gem::Version.new(Ragdoll::Core::VERSION)
    zero = Gem::Version.new("0.0.0")
    assert current > zero
  end

  def test_version_constant_is_frozen
    assert Ragdoll::Core::VERSION.frozen?
  end
end
