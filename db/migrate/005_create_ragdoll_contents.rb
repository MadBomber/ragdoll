class CreateRagdollContents < ActiveRecord::Migration[7.0]
  def change
    create_table :ragdoll_contents,
      comment: "Content storage for polymorphic embedding architecture using STI" do |t|

      t.string :type, null: false,
        comment: "Type of content (e.g., AudioContent, ImageContent, TextContent)"

      t.references :document, null: false, foreign_key: { to_table: :ragdoll_documents },
        comment: "Reference to parent document"

      t.string :embedding_model, null: false,
        comment: "Embedding model to use for this content"

      t.text :content,
        comment: "Text content or description of the file"

      t.text :data,
        comment: "Raw data from file"

      t.json :metadata, default: {},
        comment: "Additional metadata about the file's raw data"

      t.float :duration,
        comment: "Duration of audio in seconds (for audio content)"

      t.integer :sample_rate,
        comment: "Audio sample rate in Hz (for audio content)"

      t.timestamps null: false,
        comment: "Standard creation and update timestamps"

      ###########
      # Indexes #
      ###########

      t.index :embedding_model,
        comment: "Index for filtering by embedding model"

      t.index :type,
        comment: "Index for filtering by content type"

      t.index "to_tsvector('english', COALESCE(content, ''))", using: :gin, name: "index_ragdoll_contents_on_fulltext_search",
        comment: "Full-text search index for text content"
    end
  end
end
