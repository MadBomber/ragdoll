# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

# Suppress bundler/rubygems warnings
$VERBOSE = nil

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

# Load annotate tasks
Dir.glob("lib/tasks/*.rake").each { |r| load r }

task default: :test
