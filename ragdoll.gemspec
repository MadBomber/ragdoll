# This file defines the gemspec for the Ragdoll gem, including its dependencies and metadata.

# frozen_string_literal: true

require_relative "lib/ragdoll/core/version"

Gem::Specification.new do |spec|
  spec.name        = "ragdoll"
  spec.version     = Ragdoll::Core::VERSION
  spec.authors     = ["Dewayne VanHoozer"]
  spec.email       = ["dvanhoozer@gmail.com"]

  spec.summary     = "Multi-Modal Retrieval Augmented Generation"
  spec.description = "Under development.  Contributors welcome."
  spec.homepage    = "https://github.com/MadBomber/ragdoll"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/blob/main"
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been
  # added into git.
  gemspec = File.basename(__FILE__)
  spec.files = Dir[
    "{app,config,db,lib}/**/*",
    "MIT-LICENSE",
    "Rakefile",
    "README.md",
    "Thorfile"
  ]
  spec.require_paths = ["lib"]
end
