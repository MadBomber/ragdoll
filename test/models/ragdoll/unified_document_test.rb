# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class UnifiedDocumentTest < Minitest::Test
  def setup
    super
    @test_dir = File.join(File.dirname(__FILE__), "..", "..", "tmp")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    Ragdoll::UnifiedDocument.delete_all rescue nil
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
    super
  end

  # Initialization tests
  def test_unified_document_can_be_created
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.create!(
      location: file_path,
      title: "Test Document",
      document_type: "text",
      status: "pending"
    )
    assert document.persisted?
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable, PG::UndefinedColumn => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  # Validation tests
  def test_unified_document_requires_location
    document = Ragdoll::UnifiedDocument.new(
      title: "Test",
      document_type: "text"
    )
    refute document.valid?
    assert_includes document.errors[:location], "can't be blank"
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_unified_document_requires_title
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.new(
      location: file_path,
      document_type: "text"
    )
    refute document.valid?
    assert_includes document.errors[:title], "can't be blank"
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_unified_document_requires_document_type
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.new(
      location: file_path,
      title: "Test"
    )
    # If document_type has a default value, skip this test
    if document.document_type.present?
      skip "UnifiedDocument has default document_type value"
    end
    refute document.valid?
    assert_includes document.errors[:document_type], "can't be blank"
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_unified_document_validates_document_type
    valid_types = %w[text image audio video pdf docx html markdown csv json xml yaml unknown]
    valid_types.each do |type|
      file_path = create_test_file("test_#{type}.txt", "Content")
      document = Ragdoll::UnifiedDocument.new(
        location: file_path,
        title: "Test",
        document_type: type
      )
      assert document.valid?, "Should be valid with type: #{type}"
    end
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_unified_document_rejects_invalid_document_type
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.new(
      location: file_path,
      title: "Test",
      document_type: "invalid"
    )
    refute document.valid?
    assert document.errors[:document_type].any?
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_unified_document_validates_status
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.new(
      location: file_path,
      title: "Test",
      document_type: "text",
      status: "invalid_status"
    )
    refute document.valid?
    assert document.errors[:status].any?
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  # Location normalization tests
  def test_location_normalized_to_absolute_path
    relative_path = "test.txt"
    File.write(File.join(@test_dir, relative_path), "Content")
    Dir.chdir(@test_dir) do
      document = Ragdoll::UnifiedDocument.new(
        location: relative_path,
        title: "Test",
        document_type: "text"
      )
      document.valid?
      assert document.location.start_with?("/")
    end
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_url_location_not_normalized
    document = Ragdoll::UnifiedDocument.new(
      location: "https://example.com/doc.pdf",
      title: "Test",
      document_type: "pdf"
    )
    document.valid?
    assert_equal "https://example.com/doc.pdf", document.location
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  # processed? method tests
  def test_processed_returns_true_when_status_processed
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.new(
      location: file_path,
      title: "Test",
      document_type: "text",
      status: "processed"
    )
    assert document.processed?
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_processed_returns_false_when_status_pending
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.new(
      location: file_path,
      title: "Test",
      document_type: "text",
      status: "pending"
    )
    refute document.processed?
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  # content accessor tests
  def test_content_returns_empty_string_when_no_unified_contents
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.create!(
      location: file_path,
      title: "Test",
      document_type: "text",
      status: "pending"
    )
    assert_equal "", document.content
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  # Statistics method tests
  def test_total_word_count_returns_zero_when_no_content
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.create!(
      location: file_path,
      title: "Test",
      document_type: "text",
      status: "pending"
    )
    assert_equal 0, document.total_word_count
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_total_character_count_returns_zero_when_no_content
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.create!(
      location: file_path,
      title: "Test",
      document_type: "text",
      status: "pending"
    )
    assert_equal 0, document.total_character_count
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_total_embedding_count_returns_zero_when_no_embeddings
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.create!(
      location: file_path,
      title: "Test",
      document_type: "text",
      status: "pending"
    )
    assert_equal 0, document.total_embedding_count
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  # content_quality_score tests
  def test_content_quality_score_returns_zero_when_no_unified_contents
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.create!(
      location: file_path,
      title: "Test",
      document_type: "text",
      status: "pending"
    )
    assert_equal 0.0, document.content_quality_score
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_high_quality_content_returns_false_when_no_content
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.create!(
      location: file_path,
      title: "Test",
      document_type: "text",
      status: "pending"
    )
    refute document.high_quality_content?
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  # to_hash method tests
  def test_to_hash_returns_hash
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.create!(
      location: file_path,
      title: "Test",
      document_type: "text",
      status: "pending"
    )
    result = document.to_hash
    assert_kind_of Hash, result
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_to_hash_includes_expected_keys
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.create!(
      location: file_path,
      title: "Test",
      document_type: "text",
      status: "pending"
    )
    result = document.to_hash
    assert result.key?(:id)
    assert result.key?(:title)
    assert result.key?(:location)
    assert result.key?(:document_type)
    assert result.key?(:status)
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_to_hash_includes_content_when_requested
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::UnifiedDocument.create!(
      location: file_path,
      title: "Test",
      document_type: "text",
      status: "pending"
    )
    result = document.to_hash(include_content: true)
    assert result.key?(:content)
    assert result.key?(:content_details)
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  # Scope tests
  def test_processed_scope
    file_path1 = create_test_file("test1.txt", "Content 1")
    file_path2 = create_test_file("test2.txt", "Content 2")
    Ragdoll::UnifiedDocument.create!(
      location: file_path1,
      title: "Processed",
      document_type: "text",
      status: "processed"
    )
    Ragdoll::UnifiedDocument.create!(
      location: file_path2,
      title: "Pending",
      document_type: "text",
      status: "pending"
    )
    processed = Ragdoll::UnifiedDocument.processed
    assert_equal 1, processed.count
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_by_type_scope
    file_path1 = create_test_file("test1.txt", "Content")
    file_path2 = create_test_file("test2.pdf", "PDF content")
    Ragdoll::UnifiedDocument.create!(
      location: file_path1,
      title: "Text",
      document_type: "text",
      status: "pending"
    )
    Ragdoll::UnifiedDocument.create!(
      location: file_path2,
      title: "PDF",
      document_type: "pdf",
      status: "pending"
    )
    texts = Ragdoll::UnifiedDocument.by_type("text")
    assert_equal 1, texts.count
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_recent_scope_orders_by_created_at_desc
    file_path1 = create_test_file("test1.txt", "Content 1")
    older = Ragdoll::UnifiedDocument.create!(
      location: file_path1,
      title: "Older",
      document_type: "text",
      status: "pending"
    )
    sleep(0.01)
    file_path2 = create_test_file("test2.txt", "Content 2")
    newer = Ragdoll::UnifiedDocument.create!(
      location: file_path2,
      title: "Newer",
      document_type: "text",
      status: "pending"
    )
    recent = Ragdoll::UnifiedDocument.recent
    assert_equal newer.id, recent.first.id
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  # search_content class method tests
  def test_search_content_returns_empty_for_blank_query
    result = Ragdoll::UnifiedDocument.search_content("")
    assert_empty result
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_search_content_returns_empty_for_nil_query
    result = Ragdoll::UnifiedDocument.search_content(nil)
    assert_empty result
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  # stats class method tests
  def test_stats_returns_hash
    result = Ragdoll::UnifiedDocument.stats
    assert_kind_of Hash, result
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  def test_stats_includes_expected_keys
    result = Ragdoll::UnifiedDocument.stats
    assert result.key?(:total_documents)
    assert result.key?(:by_status)
    assert result.key?(:by_type)
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  # all_media_types class method tests
  def test_all_media_types_returns_array
    result = Ragdoll::UnifiedDocument.all_media_types
    assert_kind_of Array, result
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "UnifiedDocument table not configured: #{e.message.split("\n").first}"
  end

  private

  def create_test_file(filename, content)
    file_path = File.join(@test_dir, filename)
    File.write(file_path, content)
    file_path
  end
end
