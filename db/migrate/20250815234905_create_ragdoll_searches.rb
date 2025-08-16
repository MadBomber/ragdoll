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
    end

    ###########
    # Indexes #
    ###########

    add_index :ragdoll_searches, :query_embedding, 
      using: :ivfflat, 
      opclass: :vector_cosine_ops, 
      name: "index_ragdoll_searches_on_query_embedding_cosine",
      comment: "IVFFlat index for finding similar search queries"

    add_index :ragdoll_searches, :search_type,
      comment: "Index for filtering by search type"

    add_index :ragdoll_searches, :session_id,
      comment: "Index for grouping searches by session"

    add_index :ragdoll_searches, :user_id,
      comment: "Index for filtering searches by user"

    add_index :ragdoll_searches, :created_at,
      comment: "Index for chronological search history"

    add_index :ragdoll_searches, :results_count,
      comment: "Index for analyzing search effectiveness"

    execute <<-SQL
      CREATE INDEX index_ragdoll_searches_on_fulltext_query
      ON ragdoll_searches
      USING gin(to_tsvector('english', query))
    SQL
  end
end