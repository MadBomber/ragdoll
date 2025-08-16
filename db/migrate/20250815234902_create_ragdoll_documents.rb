class CreateRagdollDocuments < ActiveRecord::Migration[7.0]
  # For concurrent index creation (PostgreSQL)
  disable_ddl_transaction!

  def up
    create_table :ragdoll_documents,
      comment: "Core documents table with LLM-generated structured metadata" do |t|

      t.string :location, null: false,
        comment: "Source location of document (file path, URL, or identifier)"

      t.string :title, null: false,
        comment: "Human-readable document title for display and search"

      t.text :summary, null: false, default: "",
        comment: "LLM-generated summary of document content"

      t.string :document_type, null: false, default: "text",
        comment: "Document format type"

      t.string :status, null: false, default: "pending",
        comment: "Document processing status"

      t.json :metadata, default: {},
        comment: "LLM-generated structured metadata about the file"

      t.timestamp :file_modified_at, null: false, default: -> { "CURRENT_TIMESTAMP" },
        comment: "Timestamp when the source file was last modified"

      t.timestamps null: false,
        comment: "Standard creation and update timestamps"

      # Add tsvector column for full-text search
      t.tsvector :search_vector

      # Add keywords as array column
      t.text :keywords, array: true, default: []
    end

    ###########
    # Indexes #
    ###########

    add_index :ragdoll_documents, :location, unique: true,
      comment: "Unique index for document source lookup"

    add_index :ragdoll_documents, :title,
      comment: "Index for title-based search"

    add_index :ragdoll_documents, :document_type,
      comment: "Index for filtering by document type"

    add_index :ragdoll_documents, :status,
      comment: "Index for filtering by processing status"

    add_index :ragdoll_documents, :created_at,
      comment: "Index for chronological sorting"

    add_index :ragdoll_documents, [:document_type, :status],
      comment: "Composite index for type+status filtering"

    # Full-text search index
    execute <<-SQL
      CREATE INDEX CONCURRENTLY index_ragdoll_documents_on_fulltext_search
      ON ragdoll_documents
      USING gin(to_tsvector('english', 
        COALESCE(title, '') || ' ' ||
        COALESCE(metadata->>'summary', '') || ' ' ||
        COALESCE(metadata->>'keywords', '') || ' ' ||
        COALESCE(metadata->>'description', '')
      ))
    SQL

    add_index :ragdoll_documents, "(metadata->>'document_type')", 
      name: "index_ragdoll_documents_on_metadata_type",
      comment: "Index for filtering by document type"

    add_index :ragdoll_documents, "(metadata->>'classification')", 
      name: "index_ragdoll_documents_on_metadata_classification",
      comment: "Index for filtering by document classification"

    # GIN index on search_vector
    add_index :ragdoll_documents, :search_vector, using: :gin, algorithm: :concurrently

    # GIN index on keywords array
    add_index :ragdoll_documents, :keywords, using: :gin, 
      name: 'index_ragdoll_documents_on_keywords_gin'

    # Trigger to keep search_vector up to date on INSERT/UPDATE
    execute <<-SQL
      CREATE FUNCTION ragdoll_documents_vector_update() RETURNS trigger AS $$
      BEGIN
        NEW.search_vector := to_tsvector('english',
          COALESCE(NEW.title, '') || ' ' ||
          COALESCE(NEW.metadata->>'summary', '') || ' ' ||
          COALESCE(NEW.metadata->>'keywords', '') || ' ' ||
          COALESCE(NEW.metadata->>'description', '')
        );
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER ragdoll_search_vector_update
      BEFORE INSERT OR UPDATE ON ragdoll_documents
      FOR EACH ROW EXECUTE FUNCTION ragdoll_documents_vector_update();
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS ragdoll_search_vector_update ON ragdoll_documents;
      DROP FUNCTION IF EXISTS ragdoll_documents_vector_update();
    SQL
    
    drop_table :ragdoll_documents
  end
end