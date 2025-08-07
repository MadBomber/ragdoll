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
    "CHANGELOG.md",
    "Thorfile"
  ]
  spec.require_paths = ["lib", "app/models"]

  # Runtime dependencies
  spec.add_dependency "activerecord"
  spec.add_dependency "activejob"
  spec.add_dependency "docx"
  spec.add_dependency "neighbor"
  spec.add_dependency "opensearch-ruby"
  spec.add_dependency "pdf-reader"
  spec.add_dependency "pg"
  spec.add_dependency "pgvector"
  spec.add_dependency "rmagick"
  spec.add_dependency "ruby-progressbar"
  spec.add_dependency "ruby_llm"
  spec.add_dependency "rubyzip"
  spec.add_dependency "searchkick"
  spec.add_dependency "shrine"

  # Development dependencies
  spec.add_development_dependency "annotate"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "database_cleaner-active_record"
  spec.add_development_dependency "debug_me"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-minitest"
  spec.add_development_dependency "rubocop-rake"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "undercover"
end