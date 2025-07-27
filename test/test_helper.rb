# frozen_string_literal: true

# Suppress bundler/rubygems warnings
$VERBOSE = nil

require "simplecov"

SimpleCov.start do
  add_filter "/test/"
  track_files "lib/**/*.rb"
  minimum_coverage 0 # Temporarily disable coverage requirement

  add_group "Core", "lib/ragdoll/core"
  add_group "Models", "lib/ragdoll/core/models"
end

# Load undercover after SimpleCov to avoid circular requires
# Only load in specific test environments to avoid conflicts
if ENV["COVERAGE_UNDERCOVER"] == "true"
  begin
    require "undercover"
  rescue LoadError, StandardError => e
    # Undercover is optional - skip if not available or has conflicts
    puts "Skipping undercover due to: #{e.message}" if ENV["DEBUG"]
  end
end

require "minitest/autorun"
require "minitest/reporters"

# Custom reporter that shows test names with pass/fail and timing
class CompactTestReporter < Minitest::Reporters::BaseReporter
  def start
    super
    puts
    puts "Started"
    puts
  end

  def record(result)
    super

    status = case result.result_code
             when "."
               "\e[32mPASS\e[0m"
             when "F"
               "\e[31mFAIL\e[0m"
             when "E"
               "\e[31mERROR\e[0m"
             when "S"
               "\e[33mSKIP\e[0m"
             end

    time_str = if result.time >= 1.0
                 "\e[31m(#{result.time.round(2)}s)\e[0m" # Red for slow tests
               else
                 "(#{result.time.round(3)}s)"
               end

    puts "#{result.klass}##{result.name} ... #{status} #{time_str}"

    # Show failure/error details
    return unless result.failure

    puts "  \e[31m#{result.failure.class}: #{result.failure.message}\e[0m"
    if result.failure.respond_to?(:backtrace) && result.failure.backtrace
      # Show first few lines of backtrace, filtered to project files
      relevant_trace = result.failure.backtrace.select do |line|
        line.include?("/test/") || line.include?("/lib/")
      end
      relevant_trace.first(3).each do |line|
        puts "    \e[90m#{line}\e[0m" # Gray color for backtrace
      end
    end
    puts # Add blank line after error details
  end

  def report
    super
    puts
    puts "Finished in #{total_time.round(5)}s"

    status_counts = results.group_by(&:result_code).transform_values(&:count)

    puts "#{count} tests, #{assertions} assertions, " \
         "\e[32m#{status_counts['F'] || 0} failures, #{status_counts['E'] || 0} errors, \e[0m" \
         "\e[33m#{status_counts['S'] || 0} skips\e[0m"
  end
end

# Use the custom compact reporter
Minitest::Reporters.use! [CompactTestReporter.new]
require_relative "../lib/ragdoll-core"

# Silence migration output during tests
ActiveRecord::Migration.verbose = false

module Minitest
  class Test
    def setup
      Ragdoll::Core.reset_configuration!

      # Silence all ActiveRecord output
      ActiveRecord::Base.logger = nil
      ActiveRecord::Migration.verbose = false

      # Setup test database with PostgreSQL
      Ragdoll::Core::Database.setup({
                                      adapter: "postgresql",
                                      database: "ragdoll_test",
                                      username: ENV["POSTGRES_USER"] || "postgres",
                                      password: ENV["POSTGRES_PASSWORD"] || "",
                                      host: ENV["POSTGRES_HOST"] || "localhost",
                                      port: ENV["POSTGRES_PORT"] || 5432,
                                      auto_migrate: true,
                                      logger: nil
                                    })
    end

    def teardown
      # Clean up database in correct order to avoid foreign key violations
      if ActiveRecord::Base.connected?
        # Delete child tables first, then parent tables (using current schema)
        tables_to_clean = %w[
          ragdoll_embeddings
          ragdoll_contents
          ragdoll_documents
        ]

        tables_to_clean.each do |table_name|
          if ActiveRecord::Base.connection.table_exists?(table_name)
            ActiveRecord::Base.connection.execute("DELETE FROM #{table_name}")
          end
        end
      end

      Ragdoll::Core.reset_configuration!
    end
  end
end
