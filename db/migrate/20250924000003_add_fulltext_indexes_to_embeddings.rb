# frozen_string_literal: true

class AddFulltextIndexesToEmbeddings < ActiveRecord::Migration[7.0]
  def up
    # Enable pg_trgm extension for trigram matching
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

    # Full-text search index using GIN
    execute <<~SQL
      CREATE INDEX IF NOT EXISTS idx_embeddings_content_fulltext
      ON ragdoll_embeddings
      USING GIN (to_tsvector('english', content));
    SQL

    # Trigram index for fuzzy matching
    execute <<~SQL
      CREATE INDEX IF NOT EXISTS idx_embeddings_content_trigram
      ON ragdoll_embeddings
      USING GIN (content gin_trgm_ops);
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS idx_embeddings_content_trigram;"
    execute "DROP INDEX IF EXISTS idx_embeddings_content_fulltext;"
  end
end
