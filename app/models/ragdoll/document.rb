# frozen_string_literal: true

require "active_record"

module Ragdoll
  class Document < ActiveRecord::Base
    self.table_name = "ragdoll_documents"

    # PostgreSQL full-text search on summary and keywords
    # Uses PostgreSQL's built-in full-text search capabilities

    # File handling moved to content models - no Shrine attachment at document level

    # Multi-modal content relationships using STI
    has_many :contents,
             class_name: "Ragdoll::Content",
             foreign_key: "document_id",
             dependent: :destroy

    has_many :text_contents,
             -> { where(type: "Ragdoll::TextContent") },
             class_name: "Ragdoll::TextContent",
             foreign_key: "document_id"

    has_many :image_contents,
             -> { where(type: "Ragdoll::ImageContent") },
             class_name: "Ragdoll::ImageContent",
             foreign_key: "document_id"

    has_many :audio_contents,
             -> { where(type: "Ragdoll::AudioContent") },
             class_name: "Ragdoll::AudioContent",
             foreign_key: "document_id"

    # All embeddings across content types
    has_many :text_embeddings, through: :text_contents, source: :embeddings
    has_many :image_embeddings, through: :image_contents, source: :embeddings
    has_many :audio_embeddings, through: :audio_contents, source: :embeddings

    validates :location, presence: true
    validates :title, presence: true
    validates :document_type, presence: true,
                              inclusion: { in: %w[text image audio pdf docx html markdown mixed] }
    validates :summary, presence: false # Allow empty summaries initially
    validates :keywords, presence: false # Allow empty keywords initially
    validates :status, inclusion: { in: %w[pending processing processed error] }
    validates :file_modified_at, presence: true

    # Ensure location is always an absolute path for file paths
    before_validation :normalize_location
    before_validation :set_default_file_modified_at

    # JSON columns are handled natively by PostgreSQL - no serialization needed

    scope :processed, -> { where(status: "processed") }
    scope :by_type, ->(type) { where(document_type: type) }
    scope :recent, -> { order(created_at: :desc) }
    scope :with_content, -> { joins(:contents).distinct }
    scope :without_content, -> { left_joins(:contents).where(contents: { id: nil }) }

    # Callbacks to process content
    after_commit :create_content_from_pending, on: %i[create update],
                                               if: :has_pending_content?

    def processed?
      status == "processed"
    end

    # Multi-modal content type detection
    def multi_modal?
      content_types.length > 1
    end

    def content_types
      %w[text image audio].select do |type|
        send("#{type}_contents").any?
      end
    end

    def primary_content_type
      return document_type if %w[text image audio].include?(document_type)
      return content_types.first if content_types.any?

      "text" # default
    end

    # Dynamic content method that forwards to appropriate content table
    def content
      type = primary_content_type

      if %w[text image audio].include?(type)
        # Return the combined content from the appropriate content type
        # For text: actual text content
        # For image: AI-generated descriptions (stored in content field)
        # For audio: transcripts (stored in content field)
        send("#{type}_contents").pluck(:content).compact.join("\n\n")
      else
        # Fallback: try to get any available content
        contents.pluck(:content).compact.join("\n\n")
      end
    end

    # Set content method for backwards compatibility
    def content=(value)
      # Store the content to be created after save
      @pending_content = value

      # If document is already persisted, create the content immediately
      return unless persisted?

      create_content_from_pending
    end

    # Content statistics
    def total_word_count
      text_contents.sum { |tc| tc.word_count }
    end

    def total_character_count
      text_contents.sum { |tc| tc.character_count }
    end

    def total_embedding_count
      %w[text image audio].sum { |type| send("#{type}_embeddings").count }
    end

    def embeddings_by_type
      %w[text image audio].each_with_object({}) do |type, result|
        result[type.to_sym] = send("#{type}_embeddings").count
      end
    end

    # Document metadata methods - now using dedicated columns
    def has_summary?
      summary.present?
    end

    def has_keywords?
      keywords.present?
    end

    def keywords_array
      return [] unless keywords.present?

      # After migration, keywords is now a PostgreSQL array
      case keywords
      when Array
        keywords.map(&:to_s).map(&:strip).reject(&:empty?)
      when String
        # Fallback for any remaining string data (shouldn't happen after migration)
        keywords.split(",").map(&:strip).reject(&:empty?)
      else
        []
      end
    end

    def add_keyword(keyword)
      return if keyword.blank?
      
      current_keywords = keywords_array
      normalized_keyword = keyword.to_s.strip.downcase
      return if current_keywords.map(&:downcase).include?(normalized_keyword)

      current_keywords << normalized_keyword
      self.keywords = current_keywords
    end

    def remove_keyword(keyword)
      return if keyword.blank?
      
      current_keywords = keywords_array
      normalized_keyword = keyword.to_s.strip.downcase
      current_keywords.reject! { |k| k.downcase == normalized_keyword }
      self.keywords = current_keywords
    end

    # Metadata accessors for common fields
    def description
      metadata["description"]
    end

    def description=(value)
      self.metadata = metadata.merge("description" => value)
    end

    def classification
      metadata["classification"]
    end

    def classification=(value)
      self.metadata = metadata.merge("classification" => value)
    end

    def tags
      metadata["tags"] || []
    end

    def tags=(value)
      self.metadata = metadata.merge("tags" => Array(value))
    end

    # File-related helper methods - now delegated to content models
    def has_files?
      contents.any? { |c| c.data.present? }
    end

    def total_file_size
      # Could be implemented by summing file sizes from content metadata
      contents.sum { |c| c.metadata.dig("file_size") || 0 }
    end

    def primary_file_type
      # Return the document_type as the primary file type
      document_type
    end

    # Content processing for multi-modal documents
    def process_content!
      # Content processing is now handled by individual content models
      # This method orchestrates the overall processing

      # Generate embeddings for all content
      generate_embeddings_for_all_content!

      # Generate structured metadata using LLM
      generate_metadata!

      update!(status: "processed")
    end

    # Generate embeddings for all content types
    def generate_embeddings_for_all_content!
      %w[text image audio].each do |type|
        send("#{type}_contents").each(&:generate_embeddings!)
      end
    end

    # Generate structured metadata using LLM
    def generate_metadata!
      require_relative "../../lib/ragdoll/core/services/metadata_generator"

      generator = Ragdoll::MetadataGenerator.new
      generated_metadata = generator.generate_for_document(self)

      # Validate metadata against schema
      errors = Ragdoll::MetadataSchemas.validate_metadata(document_type, generated_metadata)
      if errors.any?
        Rails.logger.warn "Metadata validation errors: #{errors.join(', ')}" if defined?(Rails)
        puts "Metadata validation errors: #{errors.join(', ')}"
      end

      # Merge with existing metadata (preserving user-set values)
      self.metadata = metadata.merge(generated_metadata)
      save!
    rescue StandardError => e
      Rails.logger.error "Metadata generation failed: #{e.message}" if defined?(Rails)
      puts "Metadata generation failed: #{e.message}"
    end

    # PostgreSQL full-text search on metadata fields with per-word match-ratio [0.0..1.0]
    def self.search_content(query, **options)
      return none if query.blank?

      # Split into unique alphanumeric words
      words = query.downcase.scan(/[[:alnum:]]+/).uniq
      return none if words.empty?

      limit = options[:limit] || 20
      threshold = options[:threshold] || 0.0

      # Use precomputed tsvector column if it exists, otherwise build on the fly
      if column_names.include?("search_vector")
        tsvector = "#{table_name}.search_vector"
      else
        # Build tsvector from title and metadata fields
        text_expr = 
          "COALESCE(title, '') || ' ' || " \
          "COALESCE(metadata->>'summary', '') || ' ' || " \
          "COALESCE(metadata->>'keywords', '') || ' ' || " \
          "COALESCE(metadata->>'description', '')"
        tsvector = "to_tsvector('english', #{text_expr})"
      end

      # Prepare sanitized tsquery terms
      tsqueries = words.map do |word|
        sanitize_sql_array(["plainto_tsquery('english', ?)", word])
      end

      # Combine per-word tsqueries with OR so PostgreSQL can use the GIN index
      combined_tsquery = tsqueries.join(' || ')

      # Score each match (1 if present, 0 if not), sum them
      score_terms = tsqueries.map { |tsq| "(#{tsvector} @@ #{tsq})::int" }
      score_sum   = score_terms.join(' + ')

      # Similarity ratio: fraction of query words present
      similarity_sql = "(#{score_sum})::float / #{words.size}"

      # Filter using an index-friendly predicate and restrict to processed docs
      where_clause = "#{tsvector} @@ (#{combined_tsquery}) AND #{table_name}.status = 'processed'"
      
      # Add threshold filtering if specified
      if threshold > 0.0
        where_clause += " AND #{similarity_sql} >= #{threshold}"
      end

      # Materialize to array to avoid COUNT/SELECT alias conflicts in some AR versions
      select("#{table_name}.*, #{similarity_sql} AS fulltext_similarity")
        .where(where_clause)
        .order(Arel.sql("fulltext_similarity DESC, updated_at DESC"))
        .limit(limit)
        .to_a
    end

    # Search documents by keywords using PostgreSQL array operations
    # Returns documents that match keywords with scoring based on match count
    # Inspired by find_matching_entries.rb algorithm but optimized for PostgreSQL arrays
    def self.search_by_keywords(keywords_array, **options)
      return where("1 = 0") if keywords_array.blank?

      # Normalize keywords to lowercase strings array
      normalized_keywords = Array(keywords_array).map(&:to_s).map(&:downcase).reject(&:empty?)
      return where("1 = 0") if normalized_keywords.empty?

      limit = options[:limit] || 20
      
      # Use PostgreSQL array overlap operator with proper array literal
      quoted_keywords = normalized_keywords.map { |k| "\"#{k}\"" }.join(',')
      array_literal = "'{#{quoted_keywords}}'::text[]"
      where("keywords && #{array_literal}")
        .order("created_at DESC")
        .limit(limit)
    end

    # Find documents that contain ALL specified keywords (exact array matching)
    def self.search_by_keywords_all(keywords_array, **options)
      return where("1 = 0") if keywords_array.blank?

      normalized_keywords = Array(keywords_array).map(&:to_s).map(&:downcase).reject(&:empty?)
      return where("1 = 0") if normalized_keywords.empty?

      limit = options[:limit] || 20
      
      # Use PostgreSQL array contains operator with proper array literal
      quoted_keywords = normalized_keywords.map { |k| "\"#{k}\"" }.join(',')
      array_literal = "'{#{quoted_keywords}}'::text[]"
      where("keywords @> #{array_literal}")
        .order("created_at DESC")
        .limit(limit)
    end

    # Faceted search by metadata fields
    def self.faceted_search(query: nil, keywords: [], classification: nil, tags: [], **options)
      scope = all

      # Filter by keywords if provided
      if keywords.any?
        keywords.each do |keyword|
          scope = scope.where("metadata->>'keywords' ILIKE ?", "%#{keyword}%")
        end
      end

      # Filter by classification
      scope = scope.where("metadata->>'classification' = ?", classification) if classification.present?

      # Filter by tags
      if tags.any?
        tags.each do |tag|
          scope = scope.where("metadata ? 'tags' AND metadata->'tags' @> ?", [tag].to_json)
        end
      end

      # Apply PostgreSQL full-text search if query provided
      if query.present?
        scope = scope.where(
          "to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(metadata->>'summary', '') || ' ' || COALESCE(metadata->>'keywords', '') || ' ' || COALESCE(metadata->>'description', '')) @@ plainto_tsquery('english', ?)",
          query
        )
      end

      scope.limit(options[:limit] || 20)
    end

    # Get all unique keywords from metadata
    def self.all_keywords
      keywords = []
      where("metadata ? 'keywords'").pluck(:metadata).each do |meta|
        case meta["keywords"]
        when Array
          keywords.concat(meta["keywords"])
        when String
          keywords.concat(meta["keywords"].split(",").map(&:strip))
        end
      end
      keywords.uniq.sort
    end

    # Get all unique classifications
    def self.all_classifications
      where("metadata ? 'classification'").distinct.pluck("metadata->>'classification'").compact.sort
    end

    # Get all unique tags
    def self.all_tags
      tags = []
      where("metadata ? 'tags'").pluck(:metadata).each do |meta|
        tags.concat(Array(meta["tags"]))
      end
      tags.uniq.sort
    end

    # Get keyword frequencies for faceted search
    def self.keyword_frequencies
      frequencies = Hash.new(0)
      where("metadata ? 'keywords'").pluck(:metadata).each do |meta|
        case meta["keywords"]
        when Array
          meta["keywords"].each { |k| frequencies[k] += 1 }
        when String
          meta["keywords"].split(",").map(&:strip).each { |k| frequencies[k] += 1 }
        end
      end
      frequencies.sort_by { |_k, v| -v }.to_h
    end

    # Hybrid search combining semantic and PostgreSQL full-text search
    def self.hybrid_search(query, query_embedding: nil, **options)
      limit = options[:limit] || 20
      semantic_weight = options[:semantic_weight] || 0.7
      text_weight = options[:text_weight] || 0.3

      results = []

      # Get semantic search results if embedding provided
      if query_embedding
        semantic_results = embeddings_search(query_embedding, limit: limit)
        results.concat(semantic_results.map do |result|
          result.merge(
            search_type: "semantic",
            weighted_score: result[:combined_score] * semantic_weight
          )
        end)
      end

      # Get PostgreSQL full-text search results
      text_results = search_content(query, limit: limit)
      text_results.each_with_index do |doc, index|
        score = (limit - index).to_f / limit * text_weight
        results << {
          document_id: doc.id.to_s,
          document_title: doc.title,
          document_location: doc.location,
          content: doc.content[0..500], # Preview
          search_type: "full_text",
          weighted_score: score,
          document: doc
        }
      end

      # Combine and deduplicate by document_id
      combined = results.group_by { |r| r[:document_id] }
                        .map do |_doc_id, doc_results|
        best_result = doc_results.max_by { |r| r[:weighted_score] }
        total_score = doc_results.sum { |r| r[:weighted_score] }
        search_types = doc_results.map { |r| r[:search_type] }.uniq

        best_result.merge(
          combined_score: total_score,
          search_types: search_types
        )
      end

      combined.sort_by { |r| -r[:combined_score] }.take(limit)
    end

    # Extract keywords from query string (words > 4 characters)
    def self.extract_keywords(query:)
      return [] if query.nil? || query.strip.empty?

      query.split(/\s+/)
           .map(&:strip)
           .reject(&:empty?)
           .select { |word| word.length > 4 }
    end

    # Get search data for indexing
    def search_data
      data = {
        title: title,
        document_type: document_type,
        location: location,
        status: status,
        total_word_count: total_word_count,
        total_character_count: total_character_count,
        total_embedding_count: total_embedding_count,
        content_types: content_types,
        multi_modal: multi_modal?
      }

      # Add document metadata
      data.merge!(metadata.transform_keys { |k| "metadata_#{k}" }) if metadata.present?

      # Add file metadata
      data.merge!(file_metadata.transform_keys { |k| "file_#{k}" }) if file_metadata.present?

      data
    end

    def all_embeddings(content_type: nil)
      content_ids = []

      content_types = content_type ? [content_type.to_s] : %w[text image audio]

      content_types.each do |type|
        content_relation = send("#{type}_contents")
        content_ids.concat(content_relation.pluck(:id)) if content_relation.any?
      end

      return Ragdoll::Embedding.none if content_ids.empty?

      # Use the base STI class name 'Ragdoll::Content' as that's what's stored
      # in polymorphic associations with STI
      Ragdoll::Embedding.where(
        embeddable_type: "Ragdoll::Content",
        embeddable_id: content_ids
      )
    end

    private

    def has_pending_content?
      @pending_content.present?
    end

    def create_content_from_pending
      return unless @pending_content.present?

      value = @pending_content
      @pending_content = nil

      case primary_content_type
      when "text"
        # Create or update the first text_content
        if text_contents.any?
          text_contents.first.update!(content: value)
        else
          text_contents.create!(
            content: value,
            embedding_model: default_text_model,
            metadata: { manually_set: true }
          )
        end
      when "image"
        # For images, set the description (stored in content field)
        if image_contents.any?
          image_contents.first.update!(content: value) # content field stores description
        else
          image_contents.create!(
            content: value, # content field stores description
            embedding_model: default_image_model,
            metadata: { manually_set: true }
          )
        end
      when "audio"
        # For audio, set the transcript (stored in content field)
        if audio_contents.any?
          audio_contents.first.update!(content: value) # content field stores transcript
        else
          audio_contents.create!(
            content: value, # content field stores transcript
            embedding_model: default_audio_model,
            metadata: { manually_set: true }
          )
        end
      else
        # Default to text content
        text_contents.create!(
          content: value,
          embedding_model: default_text_model,
          metadata: { manually_set: true }
        )
      end
    end

    def self.embeddings_search(query_embedding, **options)
      Ragdoll::Embedding.search_similar(query_embedding, **options)
    end

    # File processing is now handled by DocumentProcessor and content models
    # These methods are no longer needed at the document level

    # Default model names for each content type
    def default_text_model
      "text-embedding-3-large"
    end

    def default_image_model
      "clip-vit-large-patch14"
    end

    def default_audio_model
      "whisper-embedding-v1"
    end

    # File extraction is now handled by DocumentProcessor
    # Content-specific extraction is handled by individual content models

    # Get document statistics
    def self.stats
      {
        total_documents: count,
        by_status: group(:status).count,
        by_type: group(:document_type).count,
        multi_modal_documents: joins(:text_contents, :image_contents).distinct.count +
          joins(:text_contents, :audio_contents).distinct.count +
          joins(:image_contents, :audio_contents).distinct.count,
        total_text_contents: joins(:text_contents).count,
        total_image_contents: joins(:image_contents).count,
        total_audio_contents: joins(:audio_contents).count,
        total_embeddings: {
          text: joins(:text_embeddings).count,
          image: joins(:image_embeddings).count,
          audio: joins(:audio_embeddings).count
        },
        storage_type: "activerecord_polymorphic"
      }
    end

    public

    # Convert document to hash representation for API responses
    def to_hash(include_content: false)
      {
        id: id.to_s,
        title: title,
        location: location,
        document_type: document_type,
        status: status,
        content_length: content&.length || 0,
        file_modified_at: file_modified_at&.iso8601,
        created_at: created_at&.iso8601,
        updated_at: updated_at&.iso8601,
        metadata: metadata || {},
        content_summary: {
          text_contents: text_contents.count,
          image_contents: image_contents.count,
          audio_contents: audio_contents.count,
          embeddings_count: total_embeddings_count,
          embeddings_ready: status == "processed"
        }
      }.tap do |hash|
        if include_content
          hash[:content_details] = {
            text_content: text_contents.map(&:content),
            image_descriptions: image_contents.map(&:description),
            audio_transcripts: audio_contents.map(&:transcript)
          }
        end
      end
    end

    private

    def total_embeddings_count
      # Count embeddings through polymorphic associations
      %w[text image audio].sum do |type|
        send("#{type}_contents").sum { |content| content.embeddings.count }
      end
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
