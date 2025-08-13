class AddSearchVectorToRagdollDocuments < ActiveRecord::Migration[7.0]
  # For concurrent index creation (PostgreSQL)
  disable_ddl_transaction!

  def up
    # Add tsvector column
    add_column :ragdoll_documents, :search_vector, :tsvector

    # Populate existing rows
    execute <<-SQL.squish
      UPDATE ragdoll_documents
      SET search_vector = to_tsvector('english',
        COALESCE(title, '') || ' ' ||
        COALESCE(metadata->>'summary', '') || ' ' ||
        COALESCE(metadata->>'keywords', '') || ' ' ||
        COALESCE(metadata->>'description', '')
      );
    SQL

    # Create GIN index on the new column
    add_index :ragdoll_documents, :search_vector, using: :gin, algorithm: :concurrently

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
    remove_index :ragdoll_documents, column: :search_vector, using: :gin
    remove_column :ragdoll_documents, :search_vector
  end
end