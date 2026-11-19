# frozen_string_literal: true

# Hybrid and text-fallback searches have no query embedding, so recording them
# violated the NOT NULL constraint on ragdoll_searches.query_embedding.
class AllowNullQueryEmbeddingOnSearches < ActiveRecord::Migration[7.0]
  def up
    change_column_null :ragdoll_searches, :query_embedding, true
  end

  def down
    change_column_null :ragdoll_searches, :query_embedding, false
  end
end
