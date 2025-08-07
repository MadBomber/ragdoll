class CreateRagdollSearches < ActiveRecord::Migration[7.0]
  def change
    create_table :ragdoll_searches,
      comment: "Search queries and results tracking with vector similarity support" do |t|

      t.text :query, null: false,
        comment: "Original search query text"

      t.vector :query_embedding, limit: 1536, null: false,
        comment: "Vector embedding of the search query for similarity matching"

      t.string :search_type, null: false, default: "semantic",
        comment: "Type of search performed (semantic, hybrid, fulltext)"

      t.integer :results_count, null: false, default: 0,
        comment: "Number of results returned for this search"

      t.float :max_similarity_score, 
        comment: "Highest similarity score from results"

      t.float :min_similarity_score,
        comment: "Lowest similarity score from results"

      t.float :avg_similarity_score,
        comment: "Average similarity score of results"

      t.json :search_filters, default: {},
        comment: "Filters applied during search (document_type, date_range, etc.)"

      t.json :search_options, default: {},
        comment: "Search configuration options (threshold, limit, etc.)"

      t.integer :execution_time_ms,
        comment: "Search execution time in milliseconds"

      t.string :session_id,
        comment: "User session identifier for grouping related searches"

      t.string :user_id,
        comment: "User identifier if authentication is available"

      t.timestamps null: false,
        comment: "Standard creation and update timestamps"

      ###########
      # Indexes #
      ###########

      t.index :query_embedding, using: :ivfflat, opclass: :vector_cosine_ops, 
        name: "index_ragdoll_searches_on_query_embedding_cosine",
        comment: "IVFFlat index for finding similar search queries"

      t.index :search_type,
        comment: "Index for filtering by search type"

      t.index :session_id,
        comment: "Index for grouping searches by session"

      t.index :user_id,
        comment: "Index for filtering searches by user"

      t.index :created_at,
        comment: "Index for chronological search history"

      t.index :results_count,
        comment: "Index for analyzing search effectiveness"

      t.index "to_tsvector('english', query)", using: :gin, 
        name: "index_ragdoll_searches_on_fulltext_query",
        comment: "Full-text search index for finding searches by query text"
    end
  end
end