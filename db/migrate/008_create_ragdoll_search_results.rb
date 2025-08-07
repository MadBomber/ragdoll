class CreateRagdollSearchResults < ActiveRecord::Migration[7.0]
  def change
    # Junction table for tracking which embeddings were returned for each search
    create_table :ragdoll_search_results,
      comment: "Junction table linking searches to their returned embeddings" do |t|

      t.references :search, null: false, foreign_key: { to_table: :ragdoll_searches },
        comment: "Reference to the search query"

      t.references :embedding, null: false, foreign_key: { to_table: :ragdoll_embeddings },
        comment: "Reference to the returned embedding"

      t.float :similarity_score, null: false,
        comment: "Similarity score for this result"

      t.integer :result_rank, null: false,
        comment: "Ranking position of this result (1-based)"

      t.boolean :clicked, default: false,
        comment: "Whether user interacted with this result"

      t.datetime :clicked_at,
        comment: "Timestamp when result was clicked/selected"

      t.timestamps null: false,
        comment: "Standard creation and update timestamps"

      ###########
      # Indexes #
      ###########

      t.index [:search_id, :result_rank],
        name: "idx_search_results_search_rank",
        comment: "Index for retrieving results in ranked order"

      t.index [:embedding_id, :similarity_score],
        name: "idx_search_results_embedding_score", 
        comment: "Index for analyzing embedding performance"

      t.index :similarity_score,
        name: "idx_search_results_similarity",
        comment: "Index for similarity score analysis"

      t.index [:clicked, :clicked_at],
        name: "idx_search_results_clicks",
        comment: "Index for click-through analysis"
    end
  end
end