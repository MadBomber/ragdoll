# frozen_string_literal: true

require "rake"

namespace :db do
  desc "Create the database"
  task :create do
    require_relative "../ragdoll-core"

    config = Ragdoll::Core.configuration
    puts "Creating database with config: #{config.database_config.inspect}"

    case config.database_config[:adapter]
    when "postgresql"
      puts "PostgreSQL database setup - running as superuser to create database and role..."
      
      # Connect as superuser to create database and role
      ActiveRecord::Base.establish_connection(
        adapter: 'postgresql',
        database: 'postgres', # Connect to postgres database initially
        username: ENV['POSTGRES_SUPERUSER'] || 'postgres',
        password: ENV['POSTGRES_SUPERUSER_PASSWORD'],
        host: config.database_config[:host] || 'localhost',
        port: config.database_config[:port] || 5432
      )
      
      # Run individual SQL commands to avoid transaction block issues
      begin
        ActiveRecord::Base.connection.execute("DROP DATABASE IF EXISTS ragdoll_development")
      rescue => e
        puts "Note: #{e.message}" if e.message.include?("does not exist")
      end
      
      begin
        ActiveRecord::Base.connection.execute("DROP ROLE IF EXISTS ragdoll")
      rescue => e
        puts "Note: #{e.message}" if e.message.include?("does not exist")
      end
      
      begin
        ActiveRecord::Base.connection.execute("CREATE ROLE ragdoll WITH LOGIN CREATEDB")
      rescue => e
        puts "Note: Role already exists, continuing..." if e.message.include?("already exists")
      end
      
      begin
        ActiveRecord::Base.connection.execute <<-SQL
          CREATE DATABASE ragdoll_development
            WITH OWNER = ragdoll
            ENCODING = 'UTF8'
            CONNECTION LIMIT = -1
        SQL
      rescue => e
        puts "Note: Database already exists, continuing..." if e.message.include?("already exists")
      end
      
      ActiveRecord::Base.connection.execute("GRANT ALL PRIVILEGES ON DATABASE ragdoll_development TO ragdoll")
      
      # Connect to the new database to set schema privileges
      ActiveRecord::Base.establish_connection(
        adapter: 'postgresql',
        database: 'ragdoll_development',
        username: ENV['POSTGRES_SUPERUSER'] || 'postgres',
        password: ENV['POSTGRES_SUPERUSER_PASSWORD'],
        host: config.database_config[:host] || 'localhost',
        port: config.database_config[:port] || 5432
      )
      
      ActiveRecord::Base.connection.execute <<-SQL
        -- Grant schema privileges (must be done while connected to the database)
        GRANT ALL PRIVILEGES ON SCHEMA public TO ragdoll;
        GRANT CREATE ON SCHEMA public TO ragdoll;
        
        -- Set default privileges for future objects
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ragdoll;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ragdoll;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ragdoll;
        
        -- Enable pgvector extension
        CREATE EXTENSION IF NOT EXISTS vector;
      SQL
      
      puts "Database and role created successfully"
    when "mysql2"
      # For MySQL, we'd typically create the database here
      puts "MySQL database creation - ensure the database exists on your server"
    end

    puts "Database creation completed"
  end

  desc "Drop the database"
  task :drop do
    require_relative "../ragdoll-core"

    config = Ragdoll::Core.configuration
    puts "Dropping database with config: #{config.database_config.inspect}"

    case config.database_config[:adapter]
    when "postgresql", "mysql2"
      puts "For #{config.database_config[:adapter]}, please drop the database manually on your server"
    end

    puts "Database drop completed"
  end

  desc "Setup the database (create and migrate)"
  task setup: %i[create migrate]

  desc "Reset the database (drop, create, and migrate)"
  task reset: %i[drop create migrate]

  desc "Run pending migrations"
  task :migrate do
    require_relative "../ragdoll-core"

    puts "Running migrations..."
    Ragdoll::Core::Database.setup({
                                    auto_migrate: false
                                  })

    Ragdoll::Core::Database.migrate!
    puts "Migrations completed"
  end

  desc "Rollback the database by one migration"
  task :rollback do
    require_relative "../ragdoll-core"

    puts "Rolling back migrations..."
    # For now, we'll implement a simple reset since our manual migration doesn't support rollback
    puts "Note: Rollback not yet implemented, use db:reset to start over"
  end

  desc "Show migration status"
  task :migrate_status do
    require_relative "../ragdoll-core"

    Ragdoll::Core::Database.setup({
                                    auto_migrate: false
                                  })

    puts "\nMigration Status:"
    puts "=================="

    # Get migration files
    migration_paths = [File.join(File.dirname(__FILE__), "..", "..", "db", "migrate")]
    migration_files = Dir[File.join(migration_paths.first, "*.rb")].sort

    # Get applied migrations
    applied_versions = []
    if ActiveRecord::Base.connection.table_exists?("schema_migrations")
      applied_versions = ActiveRecord::Base.connection.select_values(
        "SELECT version FROM schema_migrations ORDER BY version"
      )
    end

    puts format("%-8s %-20s %s", "Status", "Migration ID", "Migration Name")
    puts "-" * 60

    migration_files.each do |migration_file|
      version = File.basename(migration_file, ".rb").split("_").first
      name = File.basename(migration_file, ".rb").split("_")[1..].join("_")
      status = applied_versions.include?(version) ? "up" : "down"

      puts format("%-8s %-20s %s", status, version, name)
    end

    puts "\nTotal migrations: #{migration_files.length}"
    puts "Applied migrations: #{applied_versions.length}"
    puts "Pending migrations: #{migration_files.length - applied_versions.length}"
  end

  desc "Show database schema information"
  task :schema do
    require_relative "../ragdoll-core"

    Ragdoll::Core::Database.setup({
                                    auto_migrate: false
                                  })

    puts "\nDatabase Schema:"
    puts "================"
    puts "Adapter: #{ActiveRecord::Base.connection.adapter_name}"

    if ActiveRecord::Base.connection.tables.any?
      ActiveRecord::Base.connection.tables.sort.each do |table|
        puts "\nTable: #{table}"
        columns = ActiveRecord::Base.connection.columns(table)
        columns.each do |column|
          puts "  #{column.name}: #{column.type} (#{column.sql_type})#{unless column.null
                                                                         ' NOT NULL'
                                                                       end}#{if column.default
                                                                               " DEFAULT #{column.default.inspect}"
                                                                             end}"
        end

        # Show indexes
        indexes = ActiveRecord::Base.connection.indexes(table)
        next unless indexes.any?

        puts "  Indexes:"
        indexes.each do |index|
          unique_text = index.unique ? " (unique)" : ""
          puts "    #{index.name}: [#{index.columns.join(', ')}]#{unique_text}"
        end
      end
    else
      puts "No tables found. Run 'rake db:migrate' to create tables."
    end
  end

  desc "Open database console"
  task :console do
    require_relative "../ragdoll-core"

    config = Ragdoll::Core.configuration

    case config.database_config[:adapter]
    when "postgresql"
      db_config = config.database_config
      psql_cmd = "psql"
      psql_cmd += " -h #{db_config[:host]}" if db_config[:host]
      psql_cmd += " -p #{db_config[:port]}" if db_config[:port]
      psql_cmd += " -U #{db_config[:username]}" if db_config[:username]
      psql_cmd += " #{db_config[:database]}"
      puts "Opening PostgreSQL console..."
      system(psql_cmd)
    when "mysql2"
      db_config = config.database_config
      mysql_cmd = "mysql"
      mysql_cmd += " -h #{db_config[:host]}" if db_config[:host]
      mysql_cmd += " -P #{db_config[:port]}" if db_config[:port]
      mysql_cmd += " -u #{db_config[:username]}" if db_config[:username]
      mysql_cmd += " -p" if db_config[:password]
      mysql_cmd += " #{db_config[:database]}"
      puts "Opening MySQL console..."
      system(mysql_cmd)
    else
      puts "Console not supported for adapter: #{config.database_config[:adapter]}"
    end
  end

  desc "Show database statistics"
  task :stats do
    require_relative "../ragdoll-core"

    Ragdoll::Core::Database.setup({
                                    auto_migrate: false
                                  })

    puts "\nDatabase Statistics:"
    puts "==================="

    if ActiveRecord::Base.connection.table_exists?("ragdoll_documents")
      doc_count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM ragdoll_documents")
      puts "Documents: #{doc_count}"

      if doc_count.positive?
        doc_types = ActiveRecord::Base.connection.select_rows(
          "SELECT document_type, COUNT(*) FROM ragdoll_documents GROUP BY document_type"
        )
        puts "Document types:"
        doc_types.each { |type, count| puts "  #{type}: #{count}" }

        statuses = ActiveRecord::Base.connection.select_rows(
          "SELECT status, COUNT(*) FROM ragdoll_documents GROUP BY status"
        )
        puts "Document statuses:"
        statuses.each { |status, count| puts "  #{status}: #{count}" }
      end
    else
      puts "Documents table does not exist"
    end

    if ActiveRecord::Base.connection.table_exists?("ragdoll_embeddings")
      embedding_count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM ragdoll_embeddings")
      puts "Embeddings: #{embedding_count}"

      if embedding_count.positive?
        models = ActiveRecord::Base.connection.select_rows(
          "SELECT model_name, COUNT(*) FROM ragdoll_embeddings GROUP BY model_name"
        )
        puts "Embedding models:"
        models.each { |model, count| puts "  #{model}: #{count}" }

        usage_stats = ActiveRecord::Base.connection.select_one(
          "SELECT AVG(usage_count) as avg_usage, MAX(usage_count) as max_usage FROM ragdoll_embeddings"
        )
        puts "Usage statistics:"
        puts "  Average usage: #{usage_stats['avg_usage'].to_f.round(2)}"
        puts "  Max usage: #{usage_stats['max_usage']}"
      end
    else
      puts "Embeddings table does not exist"
    end
  end

  desc "Truncate all tables (remove all data but keep structure)"
  task :truncate do
    require_relative "../ragdoll-core"

    Ragdoll::Core::Database.setup({
                                    auto_migrate: false
                                  })

    puts "Truncating all tables..."

    # Disable foreign key checks temporarily
    case ActiveRecord::Base.connection.adapter_name.downcase
    when "postgresql"
      ActiveRecord::Base.connection.execute("SET session_replication_role = 'replica'")
    when "mysql"
      ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS = 0")
    end

    # Truncate tables in correct order (dependent tables first)
    %w[ragdoll_embeddings ragdoll_documents].each do |table|
      if ActiveRecord::Base.connection.table_exists?(table)
        ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
        puts "Truncated #{table}"
      end
    end

    # Re-enable foreign key checks
    case ActiveRecord::Base.connection.adapter_name.downcase
    when "postgresql"
      ActiveRecord::Base.connection.execute("SET session_replication_role = 'origin'")
    when "mysql"
      ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS = 1")
    end

    puts "All tables truncated"
  end
end

# Make db tasks available as top-level commands
task db: "db:migrate_status"
