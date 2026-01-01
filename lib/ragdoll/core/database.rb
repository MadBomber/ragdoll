# frozen_string_literal: true

require "active_record"
require "logger"

module Ragdoll
  module Core
    class Database
      def self.setup(config = {})
        database_config = default_config.merge(config)

        # Set up ActiveRecord connection
        ActiveRecord::Base.establish_connection(database_config)

        # Set up logging if specified
        ActiveRecord::Base.logger = database_config[:logger] if database_config[:logger]

        # Auto-migrate if specified
        return unless database_config[:auto_migrate]

        migrate!
      end

      def self.migrate!
        # Get the path to the gem root directory
        # Current file is lib/ragdoll/core/database.rb, so go up 3 levels to get to gem root
        gem_root = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", ".."))
        migration_paths = [
          File.join(gem_root, "db", "migrate")
        ]

        ActiveRecord::Migration.verbose = true

        # Ensure schema_migrations table exists first
        unless ActiveRecord::Base.connection.table_exists?("schema_migrations")
          ActiveRecord::Base.connection.create_table("schema_migrations", id: false) do |t|
            t.string :version, null: false
          end
          ActiveRecord::Base.connection.add_index("schema_migrations", :version, unique: true)
        end

        # Debug migration path (silenced for clean test output)
        # puts "Migration path: #{migration_paths.first}" if ActiveRecord::Migration.verbose
        migration_files = Dir[File.join(migration_paths.first, "*.rb")].sort
        # puts "Found #{migration_files.length} migration files" if ActiveRecord::Migration.verbose

        # Load and run each migration manually since ActiveRecord migration context seems broken
        migration_files.each do |migration_file|
          # Extract version from filename
          version = File.basename(migration_file, ".rb").split("_").first

          # Skip if already migrated
          next if ActiveRecord::Base.connection.select_values(
            "SELECT version FROM schema_migrations WHERE version = '#{version}'"
          ).any?

          # Load the migration file to define the class
          require migration_file

          # Get the migration class - convert snake_case to CamelCase
          filename_parts = File.basename(migration_file, ".rb").split("_")[1..]
          migration_class_name = filename_parts.map(&:capitalize).join

          begin
            migration_class = Object.const_get(migration_class_name)
          rescue NameError
            puts "Warning: Could not find migration class #{migration_class_name} in #{migration_file}"
            next
          end

          # Run the migration quietly
          old_verbose = ActiveRecord::Migration.verbose
          ActiveRecord::Migration.verbose = false
          migration_class.migrate(:up)
          ActiveRecord::Migration.verbose = old_verbose

          # Record the migration
          ActiveRecord::Base.connection.insert(
            "INSERT INTO schema_migrations (version) VALUES ('#{version}')"
          )

          # Silenced migration progress - uncomment for debugging
          # puts "Migrated #{migration_class_name}" if ActiveRecord::Migration.verbose
        end
      end

      def self.reset!
        ActiveRecord::Migration.verbose = false

        # Drop all tables in correct order (respecting foreign key constraints)
        # Order: dependent tables first, then parent tables
        tables_to_drop = %w[
          ragdoll_propositions
          ragdoll_embedding_tags
          ragdoll_document_tags
          ragdoll_tags
          ragdoll_search_results
          ragdoll_searches
          ragdoll_embeddings
          ragdoll_unified_contents
          ragdoll_contents
          ragdoll_documents
          schema_migrations
        ]

        tables_to_drop.each do |table|
          if ActiveRecord::Base.connection.table_exists?(table)
            # For PostgreSQL, we can use CASCADE to drop dependent objects
            if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
              ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{table} CASCADE")
            else
              ActiveRecord::Base.connection.drop_table(table)
            end
          end
        end

        # Also drop any functions/triggers that might exist
        if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
          ActiveRecord::Base.connection.execute("DROP FUNCTION IF EXISTS ragdoll_documents_vector_update() CASCADE")
        end

        migrate!
      end

      def self.connected?
        ActiveRecord::Base.connected?
      end

      def self.disconnect!
        ActiveRecord::Base.clear_all_connections!
      end

      def self.default_config
        {
          adapter: "postgresql",
          database: "ragdoll_development",
          username: ENV.fetch("RAGDOLL_POSTGRES_USER") { ENV.fetch("USER", "ragdoll") },
          password: ENV.fetch("RAGDOLL_DATABASE_PASSWORD", nil),
          host: "localhost",
          port: 5432,
          auto_migrate: true,
          logger: Logger.new($stdout, level: Logger::WARN)
        }
      end

      def self.migration_paths
        [File.join(File.dirname(__FILE__), "..", "..", "..", "..", "db", "migrate")]
      end
    end
  end
end
