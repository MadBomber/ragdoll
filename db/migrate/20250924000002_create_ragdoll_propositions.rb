# frozen_string_literal: true

class CreateRagdollPropositions < ActiveRecord::Migration[7.0]
  def change
    create_table :ragdoll_propositions do |t|
      t.references :document, null: false, foreign_key: { to_table: :ragdoll_documents }
      t.references :source_embedding, foreign_key: { to_table: :ragdoll_embeddings }
      t.text :content, null: false
      t.vector :embedding_vector, limit: 1536
      t.jsonb :metadata, default: {}
      t.timestamps null: false
    end

    # Note: t.references already creates indexes on document_id and source_embedding_id

    # Vector index for similarity search
    execute <<~SQL
      CREATE INDEX index_ragdoll_propositions_on_embedding_vector
      ON ragdoll_propositions
      USING ivfflat (embedding_vector vector_cosine_ops)
      WITH (lists = 100);
    SQL
  end
end
