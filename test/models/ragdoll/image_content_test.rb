# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class ImageContentTest < Minitest::Test
  def setup
    super
    @test_dir = File.join(File.dirname(__FILE__), "..", "..", "tmp")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    Ragdoll::ImageContent.delete_all rescue nil
    Ragdoll::Document.delete_all rescue nil
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
    super
  end

  # Inheritance tests
  def test_image_content_inherits_from_content
    assert Ragdoll::ImageContent < Ragdoll::Content
  end

  # Initialization tests
  def test_image_content_can_be_created_with_description
    document = create_test_document
    content = Ragdoll::ImageContent.create!(
      document: document,
      embedding_model: "clip-vit-large-patch14",
      content: "A beautiful sunset over the ocean"
    )
    assert content.persisted?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_image_content_can_be_created_with_alt_text
    document = create_test_document
    content = Ragdoll::ImageContent.new(
      document: document,
      embedding_model: "test-model"
    )
    content.alt_text = "Sunset photo"
    assert content.valid?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # Validation tests
  def test_image_content_requires_image_or_description
    document = create_test_document
    content = Ragdoll::ImageContent.new(
      document: document,
      embedding_model: "test-model"
    )
    refute content.valid?
    assert content.errors[:base].any?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # Description accessor tests
  def test_description_returns_content
    document = create_test_document
    content = Ragdoll::ImageContent.new(
      document: document,
      embedding_model: "test-model",
      content: "A sunset photo"
    )
    assert_equal "A sunset photo", content.description
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_description_setter_sets_content
    document = create_test_document
    content = Ragdoll::ImageContent.new(
      document: document,
      embedding_model: "test-model"
    )
    content.description = "A mountain view"
    assert_equal "A mountain view", content.content
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # image_data accessor tests
  def test_image_data_returns_data
    document = create_test_document
    content = Ragdoll::ImageContent.new(
      document: document,
      embedding_model: "test-model",
      data: "/path/to/image.jpg"
    )
    assert_equal "/path/to/image.jpg", content.image_data
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_image_data_setter_sets_data
    document = create_test_document
    content = Ragdoll::ImageContent.new(
      document: document,
      embedding_model: "test-model"
    )
    content.image_data = "/path/to/photo.png"
    assert_equal "/path/to/photo.png", content.data
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # alt_text metadata accessor tests
  def test_alt_text_can_be_set_and_retrieved
    document = create_test_document
    content = Ragdoll::ImageContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Description"
    )
    content.alt_text = "Beautiful sunset"
    content.save!
    content.reload
    assert_equal "Beautiful sunset", content.alt_text
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # image_attached? tests
  def test_image_attached_returns_false_when_no_data
    document = create_test_document
    content = Ragdoll::ImageContent.new(
      document: document,
      embedding_model: "test-model",
      content: "Description"
    )
    refute content.image_attached?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_image_attached_returns_true_when_data_present
    document = create_test_document
    content = Ragdoll::ImageContent.new(
      document: document,
      embedding_model: "test-model",
      data: "/path/to/image.jpg"
    )
    assert content.image_attached?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # image_size metadata accessor tests
  def test_image_size_returns_zero_by_default
    document = create_test_document
    content = Ragdoll::ImageContent.new(
      document: document,
      embedding_model: "test-model",
      content: "Description"
    )
    assert_equal 0, content.image_size
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_image_size_can_be_set
    document = create_test_document
    content = Ragdoll::ImageContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Description"
    )
    content.image_size = 1024
    content.save!
    content.reload
    assert_equal 1024, content.image_size
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # image_dimensions tests
  def test_image_dimensions_returns_nil_when_not_set
    document = create_test_document
    content = Ragdoll::ImageContent.new(
      document: document,
      embedding_model: "test-model",
      content: "Description"
    )
    assert_nil content.image_dimensions
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_set_image_dimensions_stores_width_and_height
    document = create_test_document
    content = Ragdoll::ImageContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Description"
    )
    content.set_image_dimensions(1920, 1080)
    content.save!
    content.reload
    assert_equal({ width: 1920, height: 1080 }, content.image_dimensions)
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # color_space and bit_depth tests
  def test_color_space_can_be_set_and_retrieved
    document = create_test_document
    content = Ragdoll::ImageContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Description"
    )
    content.color_space = "RGB"
    content.save!
    content.reload
    assert_equal "RGB", content.color_space
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_bit_depth_can_be_set_and_retrieved
    document = create_test_document
    content = Ragdoll::ImageContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Description"
    )
    content.bit_depth = 24
    content.save!
    content.reload
    assert_equal 24, content.bit_depth
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # content_for_embedding tests
  def test_content_for_embedding_combines_alt_text_and_description
    document = create_test_document
    content = Ragdoll::ImageContent.new(
      document: document,
      embedding_model: "test-model",
      content: "A sunset photo"
    )
    content.alt_text = "Sunset"
    combined = content.content_for_embedding
    assert_includes combined, "Sunset"
    assert_includes combined, "A sunset photo"
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_content_for_embedding_works_with_only_description
    document = create_test_document
    content = Ragdoll::ImageContent.new(
      document: document,
      embedding_model: "test-model",
      content: "A sunset photo"
    )
    assert_equal "A sunset photo", content.content_for_embedding
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # should_generate_embeddings? tests
  def test_should_generate_embeddings_returns_true_when_content_present
    document = create_test_document
    content = Ragdoll::ImageContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Description"
    )
    assert content.should_generate_embeddings?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_should_generate_embeddings_returns_false_when_no_content
    document = create_test_document
    content = Ragdoll::ImageContent.new(
      document: document,
      embedding_model: "test-model"
    )
    refute content.should_generate_embeddings?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # Scope tests
  def test_recent_scope_exists
    assert Ragdoll::ImageContent.respond_to?(:recent)
  end

  def test_with_images_scope_exists
    assert Ragdoll::ImageContent.respond_to?(:with_images)
  end

  def test_with_descriptions_scope_exists
    assert Ragdoll::ImageContent.respond_to?(:with_descriptions)
  end

  # stats class method tests
  def test_stats_returns_hash
    result = Ragdoll::ImageContent.stats
    assert_kind_of Hash, result
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConfigurationError, PG::UndefinedTable => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_stats_includes_total_image_contents
    result = Ragdoll::ImageContent.stats
    assert result.key?(:total_image_contents)
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConfigurationError, PG::UndefinedTable => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  private

  def create_test_document(filename = "test_image.png")
    file_path = File.join(@test_dir, filename)
    File.write(file_path, "fake image data")
    Ragdoll::Document.create!(
      location: file_path,
      title: filename,
      document_type: "image",
      status: "processed"
    )
  end
end
