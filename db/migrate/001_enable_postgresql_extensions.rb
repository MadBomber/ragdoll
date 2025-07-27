class EnablePostgresqlExtensions < ActiveRecord::Migration[7.0]
  def up
    # This migration is now handled by the db:create rake task
    # Just ensure required extensions are available
    
    # Vector similarity search (required for embeddings)
    execute "CREATE EXTENSION IF NOT EXISTS vector"
    
    # Useful optional extensions for text processing and search
    execute "CREATE EXTENSION IF NOT EXISTS unaccent"  # Remove accents from text
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"   # Trigram matching for fuzzy search
    
    # UUID support (useful for generating unique identifiers)
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""
  end

  def down
    execute <<-SQL
      DROP DATABASE IF EXISTS ragdoll_development;
      DROP ROLE IF EXISTS ragdoll;
    SQL
  end
end
