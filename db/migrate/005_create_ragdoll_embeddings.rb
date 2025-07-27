class CreateRagdollEmbeddings < ActiveRecord::Migration[7.0]
  def change
    create_table :ragdoll_embeddings,
      comment: "Polymorphic vector embeddings storage for semantic similarity search" do |t|

        t.references :embeddable, polymorphic: true, null: false,
        comment: "Polymorphic reference to embeddable content"

      t.text :content, null: false, default: "",
        comment: "Original text content that was embedded"

      t.vector :embedding_vector, limit: 1536, null: false,
        comment: "Vector embedding using pgvector"

      t.integer :chunk_index, null: false,
        comment: "Chunk index for ordering embeddings"

      t.integer :usage_count, default: 0,
        comment: "Number of times used in similarity searches"

      t.datetime :returned_at,
        comment: "Timestamp of most recent usage"

      t.json :metadata, default: {},
        comment: "Embedding-specific metadata (positions, processing info)"

      t.timestamps null: false,
        comment: "Standard creation and update timestamps"

      ###########
      # Indexes #
      ###########

      t.index %i[embeddable_type embeddable_id],
        comment: "Index for finding embeddings by embeddable content"

      t.index :embedding_vector, using: :ivfflat, opclass: :vector_cosine_ops, name: "index_ragdoll_embeddings_on_embedding_vector_cosine",
        comment: "IVFFlat index for fast cosine similarity search"
    end
  end
end
