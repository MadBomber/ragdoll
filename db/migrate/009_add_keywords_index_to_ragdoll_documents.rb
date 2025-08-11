# frozen_string_literal: true

class AddKeywordsIndexToRagdollDocuments < ActiveRecord::Migration[7.0]
  def up
    # First, convert existing text keywords to array format
    # Parse comma-separated strings into PostgreSQL arrays
    
    # Add a temporary array column
    add_column :ragdoll_documents, :keywords_array, :text, array: true, default: []
    
    # Migrate existing data from text to array format
    execute <<-SQL
      UPDATE ragdoll_documents 
      SET keywords_array = CASE 
        WHEN keywords IS NULL OR keywords = '' THEN '{}'::text[]
        ELSE string_to_array(
          regexp_replace(keywords, '\\s*,\\s*', ',', 'g'), -- normalize spaces
          ','
        )
      END;
    SQL
    
    # Remove the old text column and rename the array column
    remove_column :ragdoll_documents, :keywords
    rename_column :ragdoll_documents, :keywords_array, :keywords
    
    # Add GIN index on keywords array column for efficient array operations  
    # This supports PostgreSQL array operators: &&, @>, <@, =
    add_index :ragdoll_documents, :keywords, using: :gin, 
              name: 'index_ragdoll_documents_on_keywords_gin'
  end

  def down
    # Remove the GIN index
    remove_index :ragdoll_documents, name: 'index_ragdoll_documents_on_keywords_gin'
    
    # Convert array back to text format
    add_column :ragdoll_documents, :keywords_text, :text, default: ""
    
    # Migrate data from array back to comma-separated text
    execute <<-SQL
      UPDATE ragdoll_documents 
      SET keywords_text = CASE 
        WHEN keywords IS NULL OR array_length(keywords, 1) IS NULL THEN ''
        ELSE array_to_string(keywords, ', ')
      END;
    SQL
    
    # Replace array column with text column
    remove_column :ragdoll_documents, :keywords
    rename_column :ragdoll_documents, :keywords_text, :keywords
  end
end