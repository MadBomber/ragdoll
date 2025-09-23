# frozen_string_literal: true

class CreateRagdollUnifiedContents < ActiveRecord::Migration[7.0]
  def change
    unless table_exists?(:ragdoll_unified_contents)
      create_table :ragdoll_unified_contents,
        comment: "Unified content storage for text-based RAG architecture" do |t|

        t.references :document, null: false, foreign_key: { to_table: :ragdoll_documents },
          comment: "Reference to parent document"

        t.text :content, null: false,
          comment: "Text content (original text, extracted text, image description, audio transcript, etc.)"

        t.string :original_media_type, null: false,
          comment: "Original media type (text, image, audio, video, pdf, docx, html, markdown, unknown)"

        t.string :embedding_model, null: false,
          comment: "Embedding model used for this content"

        t.string :conversion_method,
          comment: "Method used to convert to text (text_extraction, image_to_text, audio_transcription, etc.)"

        t.integer :word_count, default: 0,
          comment: "Number of words in the content"

        t.integer :character_count, default: 0,
          comment: "Number of characters in the content"

        t.float :content_quality_score, default: 0.0,
          comment: "Quality score of the converted content (0.0-1.0)"

        t.json :metadata, default: {},
          comment: "Additional metadata about the conversion and content"

        t.timestamps null: false,
          comment: "Standard creation and update timestamps"
      end
    else
      # Add missing columns to existing table
      add_column :ragdoll_unified_contents, :original_media_type, :string unless column_exists?(:ragdoll_unified_contents, :original_media_type)
      add_column :ragdoll_unified_contents, :conversion_method, :string unless column_exists?(:ragdoll_unified_contents, :conversion_method)
      add_column :ragdoll_unified_contents, :word_count, :integer, default: 0 unless column_exists?(:ragdoll_unified_contents, :word_count)
      add_column :ragdoll_unified_contents, :character_count, :integer, default: 0 unless column_exists?(:ragdoll_unified_contents, :character_count)
      add_column :ragdoll_unified_contents, :content_quality_score, :float, default: 0.0 unless column_exists?(:ragdoll_unified_contents, :content_quality_score)
    end

    ###########
    # Indexes #
    ###########

    unless index_exists?(:ragdoll_unified_contents, :embedding_model)
      add_index :ragdoll_unified_contents, :embedding_model,
        comment: "Index for filtering by embedding model"
    end

    unless index_exists?(:ragdoll_unified_contents, :original_media_type)
      add_index :ragdoll_unified_contents, :original_media_type,
        comment: "Index for filtering by original media type"
    end

    unless index_exists?(:ragdoll_unified_contents, :conversion_method)
      add_index :ragdoll_unified_contents, :conversion_method,
        comment: "Index for filtering by conversion method"
    end

    unless index_exists?(:ragdoll_unified_contents, :content_quality_score)
      add_index :ragdoll_unified_contents, :content_quality_score,
        comment: "Index for filtering by content quality"
    end

    unless index_exists?(:ragdoll_unified_contents, [:document_id, :original_media_type], name: "index_unified_contents_on_doc_and_media_type")
      add_index :ragdoll_unified_contents, [:document_id, :original_media_type],
        name: "index_unified_contents_on_doc_and_media_type",
        comment: "Index for finding content by document and media type"
    end

    # Full-text search index
    unless connection.execute("SELECT 1 FROM pg_indexes WHERE indexname = 'index_ragdoll_unified_contents_on_fulltext_search'").any?
      execute <<-SQL
        CREATE INDEX index_ragdoll_unified_contents_on_fulltext_search
        ON ragdoll_unified_contents
        USING gin(to_tsvector('english', COALESCE(content, '')))
      SQL
    end
  end
end