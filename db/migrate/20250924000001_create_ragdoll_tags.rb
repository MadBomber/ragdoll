# frozen_string_literal: true

class CreateRagdollTags < ActiveRecord::Migration[7.0]
  def change
    # Tags table - hierarchical tags for classification
    create_table :ragdoll_tags do |t|
      t.string :name, null: false
      t.string :parent_name
      t.integer :depth, default: 0, null: false
      t.integer :usage_count, default: 0, null: false
      t.timestamps null: false
    end

    add_index :ragdoll_tags, :name, unique: true
    add_index :ragdoll_tags, :parent_name
    add_index :ragdoll_tags, :depth
    add_index :ragdoll_tags, "name text_pattern_ops", name: "index_ragdoll_tags_prefix"

    # Document-level tags
    create_table :ragdoll_document_tags do |t|
      t.references :document, null: false, foreign_key: { to_table: :ragdoll_documents }
      t.references :tag, null: false, foreign_key: { to_table: :ragdoll_tags }
      t.float :confidence, default: 1.0, null: false
      t.string :source, default: 'auto', null: false
      t.timestamps null: false
    end

    add_index :ragdoll_document_tags, %i[document_id tag_id], unique: true
    # Note: t.references :tag already creates index on tag_id

    # Embedding/chunk-level tags
    create_table :ragdoll_embedding_tags do |t|
      t.references :embedding, null: false, foreign_key: { to_table: :ragdoll_embeddings }
      t.references :tag, null: false, foreign_key: { to_table: :ragdoll_tags }
      t.float :confidence, default: 1.0, null: false
      t.string :source, default: 'auto', null: false
      t.timestamps null: false
    end

    add_index :ragdoll_embedding_tags, %i[embedding_id tag_id], unique: true
    # Note: t.references :tag already creates index on tag_id
  end
end
