class EnablePostgresqlExtensions < ActiveRecord::Migration[7.0]
  def up
    # Vector similarity search (required for embeddings)
    execute "CREATE EXTENSION IF NOT EXISTS vector"
    
    # Useful optional extensions for text processing and search
    execute "CREATE EXTENSION IF NOT EXISTS unaccent"  # Remove accents from text
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"   # Trigram matching for fuzzy search
    
    # UUID support (useful for generating unique identifiers)
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""
  end

  def down
    # Extensions are typically not dropped as they might be used by other databases
    # If you really need to drop them, uncomment the following:
    # execute "DROP EXTENSION IF EXISTS vector"
    # execute "DROP EXTENSION IF EXISTS unaccent"
    # execute "DROP EXTENSION IF EXISTS pg_trgm"
    # execute "DROP EXTENSION IF EXISTS \"uuid-ossp\""
  end
end