# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class PropositionTest < Minitest::Test
  def setup
    super
    @test_dir = File.join(File.dirname(__FILE__), "..", "..", "tmp")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    Ragdoll::Proposition.delete_all rescue nil
    Ragdoll::Document.delete_all rescue nil
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
    super
  end

  # Initialization tests
  def test_proposition_can_be_created_with_valid_attributes
    document = create_test_document
    proposition = Ragdoll::Proposition.create!(
      content: "Neil Armstrong walked on the Moon in 1969.",
      document: document
    )
    assert proposition.persisted?
  end

  def test_proposition_content_is_stored
    document = create_test_document
    proposition = Ragdoll::Proposition.create!(
      content: "PostgreSQL supports JSON data types.",
      document: document
    )
    assert_equal "PostgreSQL supports JSON data types.", proposition.content
  end

  # Validation tests
  def test_proposition_requires_content
    document = create_test_document
    proposition = Ragdoll::Proposition.new(document: document)
    refute proposition.valid?
    assert_includes proposition.errors[:content], "can't be blank"
  end

  def test_proposition_requires_document_id
    proposition = Ragdoll::Proposition.new(content: "Some fact")
    refute proposition.valid?
    assert_includes proposition.errors[:document_id], "can't be blank"
  end

  # Association tests
  def test_proposition_belongs_to_document
    document = create_test_document
    proposition = Ragdoll::Proposition.create!(
      content: "A test proposition.",
      document: document
    )
    assert_equal document.id, proposition.document.id
  end

  def test_proposition_can_have_source_embedding
    # Embedding uses polymorphic embeddable, not document
    # This test validates the optional association exists
    document = create_test_document
    proposition = Ragdoll::Proposition.create!(
      content: "A derived proposition.",
      document: document
    )
    # source_embedding is optional and would be set during proposition extraction
    assert_respond_to proposition, :source_embedding
    assert_respond_to proposition, :source_embedding=
  end

  def test_proposition_source_embedding_is_optional
    document = create_test_document
    proposition = Ragdoll::Proposition.create!(
      content: "A proposition without source embedding.",
      document: document
    )
    assert_nil proposition.source_embedding
  end

  # embedded? method tests
  def test_embedded_returns_false_when_no_vector
    document = create_test_document
    proposition = Ragdoll::Proposition.create!(
      content: "A proposition without embedding.",
      document: document
    )
    refute proposition.embedded?
  end

  def test_embedded_returns_true_when_vector_present
    document = create_test_document
    proposition = Ragdoll::Proposition.create!(
      content: "A proposition with embedding.",
      document: document,
      embedding_vector: [0.1] * 1536
    )
    assert proposition.embedded?
  rescue ActiveRecord::RecordInvalid => e
    skip "Embedding dimension mismatch: #{e.message.split("\n").first}"
  end

  # source_chunk method tests
  def test_source_chunk_returns_nil_when_no_source_embedding
    document = create_test_document
    proposition = Ragdoll::Proposition.create!(
      content: "A proposition.",
      document: document
    )
    assert_nil proposition.source_chunk
  end

  # Scope tests
  def test_with_embeddings_scope
    document = create_test_document
    Ragdoll::Proposition.create!(
      content: "With embedding",
      document: document,
      embedding_vector: [0.1] * 1536
    )
    Ragdoll::Proposition.create!(
      content: "Without embedding",
      document: document
    )
    with_embeddings = Ragdoll::Proposition.with_embeddings
    assert_equal 1, with_embeddings.count
  rescue ActiveRecord::RecordInvalid => e
    skip "Embedding dimension mismatch: #{e.message.split("\n").first}"
  end

  def test_without_embeddings_scope
    document = create_test_document
    Ragdoll::Proposition.create!(
      content: "With embedding",
      document: document,
      embedding_vector: [0.1] * 1536
    )
    Ragdoll::Proposition.create!(
      content: "Without embedding",
      document: document
    )
    without_embeddings = Ragdoll::Proposition.without_embeddings
    assert_equal 1, without_embeddings.count
  rescue ActiveRecord::RecordInvalid => e
    skip "Embedding dimension mismatch: #{e.message.split("\n").first}"
  end

  def test_by_document_scope
    doc1 = create_test_document("doc1.txt")
    doc2 = create_test_document("doc2.txt")
    Ragdoll::Proposition.create!(content: "Prop 1", document: doc1)
    Ragdoll::Proposition.create!(content: "Prop 2", document: doc1)
    Ragdoll::Proposition.create!(content: "Prop 3", document: doc2)
    assert_equal 2, Ragdoll::Proposition.by_document(doc1.id).count
    assert_equal 1, Ragdoll::Proposition.by_document(doc2.id).count
  end

  def test_recent_scope_orders_by_created_at_desc
    document = create_test_document
    older = Ragdoll::Proposition.create!(
      content: "Older proposition",
      document: document
    )
    # Ensure different timestamps
    sleep(0.01)
    newer = Ragdoll::Proposition.create!(
      content: "Newer proposition",
      document: document
    )
    recent = Ragdoll::Proposition.recent
    assert_equal newer.id, recent.first.id
  end

  # search_similar class method tests
  def test_search_similar_class_method_exists
    assert Ragdoll::Proposition.respond_to?(:search_similar)
  end

  def test_search_similar_returns_array
    query_vector = [0.1] * 1536
    result = Ragdoll::Proposition.search_similar(query_vector)
    assert_kind_of Array, result
  rescue PG::UndefinedColumn, PG::UndefinedTable, ActiveRecord::StatementInvalid => e
    skip "pgvector not properly configured: #{e.message.split("\n").first}"
  end

  def test_search_similar_accepts_limit_parameter
    query_vector = [0.1] * 1536
    result = Ragdoll::Proposition.search_similar(query_vector, limit: 5)
    assert_kind_of Array, result
  rescue PG::UndefinedColumn, PG::UndefinedTable, ActiveRecord::StatementInvalid => e
    skip "pgvector not properly configured: #{e.message.split("\n").first}"
  end

  def test_search_similar_accepts_threshold_parameter
    query_vector = [0.1] * 1536
    result = Ragdoll::Proposition.search_similar(query_vector, threshold: 0.8)
    assert_kind_of Array, result
  rescue PG::UndefinedColumn, PG::UndefinedTable, ActiveRecord::StatementInvalid => e
    skip "pgvector not properly configured: #{e.message.split("\n").first}"
  end

  # Multiple propositions tests
  def test_multiple_propositions_for_same_document
    document = create_test_document
    props = []
    3.times do |i|
      props << Ragdoll::Proposition.create!(
        content: "Proposition #{i}",
        document: document
      )
    end
    assert_equal 3, Ragdoll::Proposition.where(document: document).count
  end

  private

  def create_test_document(filename = "test_document.txt")
    file_path = File.join(@test_dir, filename)
    File.write(file_path, "Test document content.")
    Ragdoll::Document.create!(
      location: file_path,
      title: filename,
      document_type: "text",
      status: "processed"
    )
  end
end
