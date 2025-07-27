# frozen_string_literal: true

# =============================================================================
# Ragdoll Core - Complete IRB Configuration
# =============================================================================
# This file contains all possible configuration options for Ragdoll Core.
# Uncomment and modify settings as needed for your environment.
#
# Environment variables are used as defaults where applicable.
# =============================================================================

require_relative "lib/ragdoll"

def table_counts
  ActiveRecord::Base.connection.tables.each_with_object({}) do |table, counts|
    # Skip system tables if necessary
    next if %w[schema_migrations ar_internal_metadata].include?(table)

    # Get the count of records in the table
    counts[table] = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM #{table}").first["count"]
  end
end

# Configure Ragdoll with all available options
Ragdoll::Core.configure do |config|
  # add overrides for config defaults here
end

# =============================================================================
# HELPER METHODS FOR IRB SESSION
# =============================================================================

# Quick access to configuration
def ragdoll_config
  Ragdoll::Core.configuration
end

# Quick access to client
def ragdoll_client
  @ragdoll_client ||= Ragdoll::Core.client
end

# Quick stats
def ragdoll_stats
  Ragdoll::Core.stats
end

# Quick document count (safe)
def doc_count
  return 0 unless table_exists?("ragdoll_documents")

  Ragdoll::Core::Models::Document.count
rescue StandardError
  0
end

# Quick embedding count (safe)
def embedding_count
  return 0 unless table_exists?("ragdoll_embeddings")

  Ragdoll::Core::Models::Embedding.count
rescue StandardError
  0
end

# Check if table exists
def table_exists?(table_name)
  ActiveRecord::Base.connection.table_exists?(table_name)
rescue StandardError
  false
end

# Quick health check (safe)
def ragdoll_health
  {
    healthy: Ragdoll::Core.healthy?,
    documents: doc_count,
    embeddings: embedding_count,
    database_connected: Ragdoll::Core::Database.connected?,
    tables_exist: %w[ragdoll_documents ragdoll_embeddings ragdoll_text_contents ragdoll_image_contents
                     ragdoll_audio_contents].map do |t|
      [t, table_exists?(t)]
    end.to_h
  }
rescue StandardError => e
  {
    healthy: false,
    error: e.message,
    database_connected: false,
    documents: 0,
    embeddings: 0
  }
end

# =============================================================================
# DEVELOPMENT HELPERS
# =============================================================================

# Run database migrations
def migrate_database!
  puts "🔄 Running database migrations..."
  Ragdoll::Core::Database.migrate!
  puts "✅ Database migrations complete"
rescue StandardError => e
  puts "❌ Migration failed: #{e.message}"
end

# Reset database (WARNING: Destroys all data!)
def reset_database!
  puts "⚠️  WARNING: This will destroy all data!"
  print "Are you sure? (yes/no): "
  response = gets.chomp
  if response.downcase == "yes"
    Ragdoll::Core::Database.reset!
    puts "✅ Database reset complete"
  else
    puts "❌ Database reset cancelled"
  end
end

# Show current configuration
def show_config
  config = ragdoll_config
  puts "\n=== Ragdoll Configuration ==="
  puts "LLM Provider: #{config.llm_provider}"
  puts "Embedding Model: #{config.embedding_model}"
  puts "Chunk Size: #{config.chunk_size}"
  puts "Chunk Overlap: #{config.chunk_overlap}"
  puts "Search Threshold: #{config.search_similarity_threshold}"
  puts "Max Results: #{config.max_search_results}"
  puts "Log Level: #{config.log_level}"
  puts "Log File: #{config.log_file}"
  puts "Database: #{config.database_config[:adapter]}"
  puts "Auto Migrate: #{config.database_config[:auto_migrate]}"
  puts "========================="
end

# Show database info
def show_database_info
  config = ragdoll_config.database_config
  puts "\n=== Database Configuration ==="
  puts "Adapter: #{config[:adapter]}"
  puts "Database: #{config[:database]}"
  puts "Host: #{config[:host]}" if config[:host]
  puts "Port: #{config[:port]}" if config[:port]
  puts "Username: #{config[:username]}" if config[:username]
  puts "Pool: #{config[:pool]}" if config[:pool]
  puts "Timeout: #{config[:timeout]}"
  puts "Auto Migrate: #{config[:auto_migrate]}"
  puts "Connected: #{Ragdoll::Core::Database.connected?}"
  puts "========================="
end

# Show LLM configuration
def show_llm_config
  config = ragdoll_config
  puts "\n=== LLM Configuration ==="
  puts "Primary Provider: #{config.llm_provider}"
  puts "Embedding Provider: #{config.embedding_provider}"
  puts "Embedding Model: #{config.embedding_model}"
  puts "Default Model: #{config.default_model}"
  puts "Summary Model: #{config.summary_provider_model}"
  puts "Keywords Model: #{config.keywords_provider_model}"
  puts "Embeddings Model: #{config.embeddings_provider_model}"
  puts "========================="
end

# List all available helper methods
def help
  puts "\n=== Available Helper Methods ==="
  puts "ragdoll_config        - Access configuration"
  puts "ragdoll_client        - Access client instance"
  puts "ragdoll_stats         - System statistics"
  puts "ragdoll_health        - Health check (safe)"
  puts "doc_count             - Document count (safe)"
  puts "embedding_count       - Embedding count (safe)"
  puts "table_exists?(name)   - Check if table exists"
  puts "migrate_database!     - Run database migrations"
  puts "reset_database!       - Reset database (destroys all data!)"
  puts "show_config           - Show current configuration"
  puts "show_database_info    - Show database configuration"
  puts "show_llm_config       - Show LLM configuration"
  puts "table_counts          - Show record counts for all tables"
  puts "help                  - Show this help message"
  puts "========================="
end

# =============================================================================
# STARTUP MESSAGE
# =============================================================================

puts "\n🎯 Ragdoll Core loaded!"

# Check if tables exist and show appropriate message
health = ragdoll_health
if health[:tables_exist].values.all?
  puts "📊 Health: #{health}"
  puts "✅ All database tables exist"
else
  puts "⚠️  Database tables missing!"
  puts "   Missing tables: #{health[:tables_exist].reject { |_t, exists| exists }.keys.join(', ')}"
  puts "   Run 'migrate_database!' to create tables"
end

puts "⚙️  Use 'show_config' to see current configuration"
puts "🔍 Use 'ragdoll_health' to check system health"
puts "❓ Use 'help' to see all available methods"
puts "🗄️  Use 'migrate_database!' to run migrations"
puts "⚠️  Use 'reset_database!' to reset database (destroys all data!)"
puts "=" * 60

# =============================================================================
# SAVE CONFIGURATION TO FILE
# =============================================================================

# Save the current configuration to the default config file
begin
  config_saved_path = ragdoll_config.save
  puts "💾 Configuration saved to: #{config_saved_path}"
rescue StandardError => e
  puts "❌ Failed to save configuration: #{e.message}"
end
