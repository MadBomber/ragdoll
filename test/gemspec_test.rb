# frozen_string_literal: true

require_relative "test_helper"

class GemspecTest < Minitest::Test
  def test_gem_ships_the_license_file_it_declares
    spec = Gem::Specification.load(File.expand_path("../ragdoll.gemspec", __dir__))

    assert_equal ["MIT"], spec.licenses
    assert_includes spec.files, "MIT-LICENSE"
  end
end
