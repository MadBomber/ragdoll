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
  def initialize(options = {})
    super
    @failed_tests = []
    @error_tests = []
  end

  def start
    super
    puts
    puts "Started"
    puts
  end

  def record(result)
    super

    # Collect failures and errors for summary
    if result.failure
      case result.result_code
      when "F"
        @failed_tests << result
      when "E"
        @error_tests << result
      end
    end

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

    # Show detailed failure summary
    show_failure_summary if @failed_tests.any? || @error_tests.any?
  end

  private

  def show_failure_summary
    puts
    puts "=" * 80
    puts "FAILURE SUMMARY"
    puts "=" * 80

    all_failed = (@failed_tests + @error_tests).sort_by { |r| [test_file_from_result(r), r.klass, r.name] }
    
    if all_failed.any?
      puts
      puts "Failed Tests by File:"
      puts "-" * 40

      # Group by test file
      tests_by_file = all_failed.group_by { |result| test_file_from_result(result) }
      
      tests_by_file.each do |file_path, file_tests|
        relative_path = file_path.gsub(Dir.pwd + "/", "")
        puts
        puts "\e[1m#{relative_path}\e[0m (#{file_tests.count} failure#{'s' if file_tests.count != 1})"
        
        file_tests.each do |result|
          status_color = result.result_code == "F" ? "\e[31m" : "\e[31m"
          status_text = result.result_code == "F" ? "FAIL" : "ERROR"
          puts "  #{status_color}#{status_text}\e[0m #{result.klass}##{result.name}"
          
          # Show brief error message
          if result.failure
            message = result.failure.message.split("\n").first || ""
            message = message[0, 100] + "..." if message.length > 100
            puts "       #{message}"
          end
        end
        
        puts
        puts "  \e[36m# Run this file:\e[0m"
        puts "  bundle exec rake test #{relative_path}"
        puts
        puts "  \e[36m# Run specific test:\e[0m"
        file_tests.each do |result|
          puts "  bundle exec ruby #{relative_path} -n #{result.name}"
        end
      end

      puts
      puts "=" * 80
      puts "Quick Commands:"
      puts "  \e[36m# Run all tests:\e[0m"
      puts "  bundle exec rake test"
      puts
      puts "  \e[36m# Run only failed files:\e[0m"
      tests_by_file.keys.each do |file_path|
        relative_path = file_path.gsub(Dir.pwd + "/", "")
        puts "  bundle exec rake test #{relative_path}"
      end
      puts "=" * 80
    end
  end

  def test_file_from_result(result)
    # Extract test file path from backtrace
    if result.failure && result.failure.respond_to?(:backtrace) && result.failure.backtrace
      test_line = result.failure.backtrace.find { |line| line.include?("/test/") && line.include?("_test.rb") }
      if test_line
        return test_line.split(":").first
      end
    end
    
    # Fallback: try to guess from class name
    class_name = result.klass.to_s
    if class_name.end_with?("Test")
      # Convert CamelCase to snake_case
      file_name = class_name.gsub(/([A-Z])/, '_\1').downcase.gsub(/^_/, '') + ".rb"
      test_dir = File.join(Dir.pwd, "test")
      
      # Search for the file
      Dir.glob("#{test_dir}/**/*_test.rb").find do |path|
        File.basename(path) == file_name
      end || "unknown_test_file.rb"
    else
      "unknown_test_file.rb"
    end
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
                                      username: ENV.fetch("RAGDOLL_POSTGRES_USER", "postgres"),
                                      password: ENV.fetch("RAGDOLL_POSTGRES_PASSWORD", ""),
                                      host: ENV.fetch("RAGDOLL_POSTGRES_HOST", "localhost"),
                                      port: ENV.fetch("RAGDOLL_POSTGRES_PORT", 5432),
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
