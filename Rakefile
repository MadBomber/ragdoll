# frozen_string_literal: true

require "simplecov"
SimpleCov.start

# Suppress bundler/rubygems warnings
$VERBOSE = nil

require "bundler/gem_tasks"
require "rake/testtask"

desc "Setup test database"
task :setup_test_db do
  require_relative "lib/ragdoll-core"

  # Database configuration for tests
  test_db_config = {
    adapter: "postgresql",
    database: "ragdoll_test",
    username: ENV.fetch("RAGDOLL_POSTGRES_USER", "postgres"),
    password: ENV.fetch("RAGDOLL_POSTGRES_PASSWORD", ""),
    host: ENV.fetch("RAGDOLL_POSTGRES_HOST", "localhost"),
    port: ENV.fetch("RAGDOLL_POSTGRES_PORT", 5432)
  }

  # Ensure database exists
  begin
    # Try to connect to the database
    ActiveRecord::Base.establish_connection(test_db_config)
    ActiveRecord::Base.connection.execute("SELECT 1")
  rescue ActiveRecord::NoDatabaseError
    # Database doesn't exist, create it
    puts "Creating ragdoll_test database..."
    admin_config = test_db_config.merge(database: "postgres")
    ActiveRecord::Base.establish_connection(admin_config)
    ActiveRecord::Base.connection.execute("CREATE DATABASE ragdoll_test")
    ActiveRecord::Base.establish_connection(test_db_config)
  rescue PG::ConnectionBad => e
    puts "Error connecting to PostgreSQL: #{e.message}"
    puts "Please ensure PostgreSQL is running and accessible"
    exit 1
  end

  # Ensure pgvector extension is installed
  begin
    ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS vector")
  rescue StandardError => e
    puts "Warning: Could not install pgvector extension: #{e.message}"
  end

  # Run migrations
  Ragdoll::Core::Database.setup(test_db_config.merge(auto_migrate: true, logger: nil))
  puts "Test database setup complete"
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

# Make test task depend on database setup
task test: :setup_test_db

# Load annotate tasks
Dir.glob("lib/tasks/*.rake").each { |r| load r }

task default: :test
