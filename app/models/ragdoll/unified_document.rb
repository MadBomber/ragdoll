# frozen_string_literal: true

require "active_record"

module Ragdoll
  # Unified document model for text-based RAG system
  # All documents have their content converted to text for unified search and embedding
  class UnifiedDocument < ActiveRecord::Base
    self.table_name = "ragdoll_documents"

    # Unified content relationship - all content converted to text
    has_many :unified_contents,
             class_name: "Ragdoll::UnifiedContent",
             foreign_key: "document_id",
             dependent: :destroy

    # All embeddings through unified content
    has_many :embeddings, through: :unified_contents

    validates :location, presence: true
    validates :title, presence: true
    validates :document_type, presence: true,
                              inclusion: { in: %w[text image audio video pdf docx html markdown csv json xml yaml unknown] }
    validates :status, inclusion: { in: %w[pending processing processed error] }
    validates :file_modified_at, presence: true

    # Ensure location is always an absolute path for file paths
    before_validation :normalize_location
    before_validation :set_default_file_modified_at

    scope :processed, -> { where(status: "processed") }
    scope :by_type, ->(type) { where(document_type: type) }
    scope :recent, -> { order(created_at: :desc) }
    scope :with_content, -> { joins(:unified_contents).distinct }
    scope :without_content, -> { left_joins(:unified_contents).where(unified_contents: { id: nil }) }

    # Callbacks to process content
    after_commit :create_unified_content_from_pending, on: %i[create update],
                                                       if: :has_pending_content?

    def processed?
      status == "processed"
    end

    # Unified content access
    def content
      unified_contents.pluck(:content).compact.join("\n\n")
    end

    def content=(value)
      @pending_content = value

      return unless persisted?

      create_unified_content_from_pending
    end

    # Content statistics
    def total_word_count
      unified_contents.sum(&:word_count)
    end

    def total_character_count
      unified_contents.sum(&:character_count)
    end

    def total_embedding_count
      embeddings.count
    end

    # Document processing for unified text-based RAG
    def process_document!
      return if processed?

      begin
        update!(status: "processing")

        # Convert document to text using unified converter
        text_content = Ragdoll::DocumentConverter.convert_to_text(location, document_type)

        # Create or update unified content
        create_or_update_unified_content(text_content)

        # Generate embeddings
        generate_embeddings_for_content!

        # Generate metadata
        generate_metadata!

        update!(status: "processed")
      rescue StandardError => e
        puts "Document processing failed: #{e.message}"
        update!(status: "error", metadata: metadata.merge("error" => e.message))
        raise
      end
    end

    # Generate embeddings for all content
    def generate_embeddings_for_content!
      unified_contents.each(&:generate_embeddings!)
    end

    # Generate structured metadata using LLM
    def generate_metadata!
      return unless unified_contents.any?

      begin
        # Use the content for metadata generation
        full_content = content
        return if full_content.blank?

        # Generate basic metadata
        generated_metadata = {
          content_length: full_content.length,
          word_count: full_content.split(/\s+/).length,
          generated_at: Time.current,
          original_media_type: document_type
        }

        # Add document type specific metadata
        case document_type
        when "image"
          generated_metadata[:description_source] = "ai_generated"
        when "audio"
          generated_metadata[:transcript_source] = "auto_generated"
        when "video"
          generated_metadata[:content_source] = "mixed_media_conversion"
        end

        # Merge with existing metadata
        self.metadata = metadata.merge(generated_metadata)
        save!
      rescue StandardError => e
        puts "Metadata generation failed: #{e.message}"
      end
    end

    # Search content using PostgreSQL full-text search
    def self.search_content(query, **options)
      return none if query.blank?

      words = query.downcase.scan(/[[:alnum:]]+/).uniq
      return none if words.empty?

      limit = options[:limit] || 20
      threshold = options[:threshold] || 0.0

      # Build tsvector from title and content
      text_expr = "COALESCE(title, '') || ' ' || COALESCE(content, '')"
      tsvector = "to_tsvector('english', #{text_expr})"

      # Prepare sanitized tsquery terms
      tsqueries = words.map do |word|
        sanitize_sql_array(["plainto_tsquery('english', ?)", word])
      end

      # Combine per-word tsqueries
      combined_tsquery = tsqueries.join(' || ')

      # Score calculation
      score_terms = tsqueries.map { |tsq| "(#{tsvector} @@ #{tsq})::int" }
      score_sum = score_terms.join(' + ')
      similarity_sql = "(#{score_sum})::float / #{words.size}"

      # Build query with content from unified_contents
      query = joins(:unified_contents)
              .select("#{table_name}.*, string_agg(unified_contents.content, ' ') as content, #{similarity_sql} AS fulltext_similarity")
              .group("#{table_name}.id")

      # Build where conditions
      conditions = ["#{tsvector} @@ (#{combined_tsquery})"]

      # Add status filter
      status = options[:status] || 'processed'
      conditions << "#{table_name}.status = '#{status}'"

      # Add document type filter if specified
      if options[:document_type].present?
        conditions << sanitize_sql_array(["#{table_name}.document_type = ?", options[:document_type]])
      end

      # Add threshold filtering if specified
      if threshold > 0.0
        conditions << "#{similarity_sql} >= #{threshold}"
      end

      # Combine all conditions
      where_clause = conditions.join(' AND ')

      query.where(where_clause)
           .order(Arel.sql("fulltext_similarity DESC, updated_at DESC"))
           .limit(limit)
           .to_a
    end

    # Content quality assessment
    def content_quality_score
      return 0.0 unless unified_contents.any?

      scores = unified_contents.map(&:content_quality_score)
      scores.sum / scores.length
    end

    def high_quality_content?
      content_quality_score >= 0.7
    end

    # Get all unique original media types
    def self.all_media_types
      joins(:unified_contents).distinct.pluck("unified_contents.original_media_type").compact.sort
    end

    # Get document statistics
    def self.stats
      {
        total_documents: count,
        by_status: group(:status).count,
        by_type: group(:document_type).count,
        with_content: with_content.count,
        without_content: without_content.count,
        total_unified_contents: joins(:unified_contents).count,
        total_embeddings: joins(:embeddings).count,
        content_quality: {
          high: joins(:unified_contents).where("LENGTH(unified_contents.content) > 1000").distinct.count,
          medium: joins(:unified_contents).where("LENGTH(unified_contents.content) BETWEEN 100 AND 1000").distinct.count,
          low: joins(:unified_contents).where("LENGTH(unified_contents.content) < 100").distinct.count
        },
        storage_type: "unified_text_based"
      }
    end

    # Convert document to hash representation
    def to_hash(include_content: false)
      {
        id: id.to_s,
        title: title,
        location: location,
        document_type: document_type,
        status: status,
        content_length: content&.length || 0,
        word_count: total_word_count,
        embedding_count: total_embedding_count,
        content_quality_score: content_quality_score,
        file_modified_at: file_modified_at&.iso8601,
        created_at: created_at&.iso8601,
        updated_at: updated_at&.iso8601,
        metadata: metadata || {}
      }.tap do |hash|
        if include_content
          hash[:content] = content
          hash[:content_details] = unified_contents.map do |uc|
            {
              original_media_type: uc.original_media_type,
              content: uc.content,
              word_count: uc.word_count,
              embedding_count: uc.embedding_count,
              conversion_method: uc.conversion_method
            }
          end
        end
      end
    end

    private

    def has_pending_content?
      @pending_content.present?
    end

    def create_unified_content_from_pending
      return unless @pending_content.present?

      value = @pending_content
      @pending_content = nil

      create_or_update_unified_content(value)
    end

    def create_or_update_unified_content(text_content)
      return if text_content.blank?

      # Create or update the unified content
      if unified_contents.any?
        unified_contents.first.update!(
          content: text_content,
          metadata: unified_contents.first.metadata.merge(
            "updated_at" => Time.current,
            "manually_set" => true
          )
        )
      else
        unified_contents.create!(
          content: text_content,
          original_media_type: document_type,
          embedding_model: default_embedding_model,
          metadata: {
            "created_at" => Time.current,
            "conversion_method" => "unified_converter",
            "original_filename" => File.basename(location)
          }
        )
      end
    end

    def default_embedding_model
      "text-embedding-3-large"
    end

    # Normalize location to absolute path for file paths
    def normalize_location
      return if location.blank?

      # Don't normalize URLs or other non-file protocols
      return if location.start_with?("http://", "https://", "ftp://", "sftp://")

      # Convert relative file paths to absolute paths
      self.location = File.expand_path(location)
    end

    # Set default file_modified_at if not provided
    def set_default_file_modified_at
      return if file_modified_at.present?

      # If location is a file path that exists, use file mtime
      if location.present? && !location.start_with?("http://", "https://", "ftp://", "sftp://")
        expanded_location = File.expand_path(location)
        self.file_modified_at = if File.exist?(expanded_location)
                                  File.mtime(expanded_location)
                                else
                                  Time.current
                                end
      else
        # For URLs or non-file locations, use current time
        self.file_modified_at = Time.current
      end
    end
  end
end