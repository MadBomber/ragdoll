class CreateRagdollDocuments < ActiveRecord::Migration[7.0]
  def change
    create_table :ragdoll_documents,
      comment: "Core documents table with LLM-generated structured metadata" do |t|

      t.string :location, null: false,
        comment: "Source location of document (file path, URL, or identifier)"

      t.string :title, null: false,
        comment: "Human-readable document title for display and search"

      t.text :summary, null: false, default: "",
        comment: "LLM-generated summary of document content"

      t.text :keywords , null: false, default: "",
        comment: "LLM-generated comma-separated keywords of document"

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

      ###########
      # Indexes #
      ###########

      t.index :location, unique: true,
        comment: "Unique index for document source lookup"

      t.index :title,
        comment: "Index for title-based search"

      t.index :document_type,
        comment: "Index for filtering by document type"

      t.index :status,
        comment: "Index for filtering by processing status"

      t.index :created_at,
        comment: "Index for chronological sorting"

      t.index %i[document_type status],
        comment: "Composite index for type+status filtering"

      t.index "to_tsvector('english', COALESCE(title, '') ||
        ' ' ||
        COALESCE(metadata->>'summary', '') ||
        ' ' || COALESCE(metadata->>'keywords', '') ||
        ' ' || COALESCE(metadata->>'description', ''))",
        using: :gin, name: "index_ragdoll_documents_on_fulltext_search",
        comment: "Full-text search across title and metadata fields"

      t.index "(metadata->>'document_type')", name: "index_ragdoll_documents_on_metadata_type",
        comment: "Index for filtering by document type"

      t.index "(metadata->>'classification')", name: "index_ragdoll_documents_on_metadata_classification",
        comment: "Index for filtering by document classification"
    end
  end
end
