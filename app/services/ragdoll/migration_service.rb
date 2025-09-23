# frozen_string_literal: true

module Ragdoll
  # Migration service to transition from multi-modal to unified text-based RAG system
  class MigrationService
    class MigrationError < StandardError; end

    def self.migrate_all_documents(**options)
      new.migrate_all_documents(**options)
    end

    def self.migrate_document(document_id, **options)
      new.migrate_document(document_id, **options)
    end

    def initialize
      @converter = Ragdoll::DocumentConverter.new
      @unified_management = Ragdoll::UnifiedDocumentManagement.new
    end

    # Migrate all existing documents to unified text-based system
    def migrate_all_documents(**options)
      return { error: "UnifiedDocument model not available" } unless defined?(Ragdoll::UnifiedDocument)

      migration_stats = {
        started_at: Time.current,
        total_documents: 0,
        migrated: 0,
        skipped: 0,
        errors: []
      }

      puts "🚀 Starting migration from multi-modal to unified text-based system..."

      # Get all existing documents
      Ragdoll::Document.find_each(batch_size: options[:batch_size] || 50) do |document|
        migration_stats[:total_documents] += 1

        begin
          result = migrate_single_document(document, **options)
          if result[:status] == :migrated
            migration_stats[:migrated] += 1
          else
            migration_stats[:skipped] += 1
          end
        rescue StandardError => e
          migration_stats[:errors] << {
            document_id: document.id,
            title: document.title,
            error: e.message
          }
          puts "❌ Error migrating document #{document.id}: #{e.message}"
        end

        # Progress reporting
        if migration_stats[:total_documents] % 10 == 0
          puts "📊 Progress: #{migration_stats[:migrated]} migrated, #{migration_stats[:skipped]} skipped, #{migration_stats[:errors].length} errors"
        end
      end

      migration_stats[:completed_at] = Time.current
      migration_stats[:duration] = migration_stats[:completed_at] - migration_stats[:started_at]

      puts "✅ Migration completed!"
      puts "📊 Final stats: #{migration_stats[:migrated]} migrated, #{migration_stats[:skipped]} skipped, #{migration_stats[:errors].length} errors"
      puts "⏱️  Duration: #{migration_stats[:duration].round(2)} seconds"

      migration_stats
    end

    # Migrate a specific document
    def migrate_document(document_id, **options)
      document = Ragdoll::Document.find(document_id)
      migrate_single_document(document, **options)
    end

    # Create comparison report between old and new systems
    def create_comparison_report
      return { error: "UnifiedDocument model not available" } unless defined?(Ragdoll::UnifiedDocument)

      old_stats = Ragdoll::Document.stats
      new_stats = Ragdoll::UnifiedDocument.stats
      content_stats = Ragdoll::UnifiedContent.stats

      {
        migration_summary: {
          old_system: {
            total_documents: old_stats[:total_documents],
            text_contents: old_stats[:total_text_contents],
            image_contents: old_stats[:total_image_contents],
            audio_contents: old_stats[:total_audio_contents],
            total_embeddings: old_stats[:total_embeddings]
          },
          new_system: {
            total_documents: new_stats[:total_documents],
            unified_contents: content_stats[:total_contents],
            total_embeddings: new_stats[:total_embeddings],
            by_media_type: content_stats[:by_media_type]
          }
        },
        benefits: {
          simplified_architecture: "Single content model instead of STI",
          unified_search: "All content searchable through text",
          cross_modal_retrieval: "Images and audio searchable via descriptions/transcripts",
          reduced_complexity: "One embedding pipeline instead of multiple"
        },
        recommendations: generate_migration_recommendations
      }
    end

    # Validate migrated data integrity
    def validate_migration
      return { error: "UnifiedDocument model not available" } unless defined?(Ragdoll::UnifiedDocument)

      validation_results = {
        total_checks: 0,
        passed: 0,
        failed: 0,
        issues: []
      }

      puts "🔍 Validating migration integrity..."

      # Check 1: All documents have corresponding unified documents
      validation_results[:total_checks] += 1
      old_count = Ragdoll::Document.count
      new_count = Ragdoll::UnifiedDocument.count

      if old_count == new_count
        validation_results[:passed] += 1
        puts "✅ Document count matches: #{old_count} = #{new_count}"
      else
        validation_results[:failed] += 1
        validation_results[:issues] << "Document count mismatch: #{old_count} old vs #{new_count} new"
        puts "❌ Document count mismatch: #{old_count} old vs #{new_count} new"
      end

      # Check 2: All unified documents have content
      validation_results[:total_checks] += 1
      documents_without_content = Ragdoll::UnifiedDocument.without_content.count

      if documents_without_content == 0
        validation_results[:passed] += 1
        puts "✅ All unified documents have content"
      else
        validation_results[:failed] += 1
        validation_results[:issues] << "#{documents_without_content} documents without content"
        puts "❌ #{documents_without_content} documents without content"
      end

      # Check 3: Content quality assessment
      validation_results[:total_checks] += 1
      quality_stats = content_quality_report

      if quality_stats[:high_quality_percentage] >= 50
        validation_results[:passed] += 1
        puts "✅ Content quality acceptable: #{quality_stats[:high_quality_percentage]}% high quality"
      else
        validation_results[:failed] += 1
        validation_results[:issues] << "Low content quality: only #{quality_stats[:high_quality_percentage]}% high quality"
        puts "⚠️  Content quality concern: only #{quality_stats[:high_quality_percentage]}% high quality"
      end

      validation_results[:quality_report] = quality_stats
      validation_results
    end

    private

    def migrate_single_document(document, **options)
      # Skip if already migrated (check by location)
      if defined?(Ragdoll::UnifiedDocument) &&
         Ragdoll::UnifiedDocument.exists?(location: document.location)
        return { status: :skipped, reason: "already_migrated" }
      end

      # Extract unified text content from multi-modal document
      unified_text = extract_unified_text_from_document(document)

      if unified_text.blank?
        return { status: :skipped, reason: "no_content" }
      end

      # Create unified document
      unified_doc = Ragdoll::UnifiedDocument.create!(
        location: document.location,
        title: document.title,
        document_type: document.document_type,
        status: "pending",
        file_modified_at: document.file_modified_at,
        metadata: merge_document_metadata(document)
      )

      # Create unified content
      unified_doc.unified_contents.create!(
        content: unified_text,
        original_media_type: determine_primary_media_type(document),
        embedding_model: "text-embedding-3-large",
        metadata: {
          "migrated_at" => Time.current,
          "migration_source" => "multi_modal_document",
          "original_document_id" => document.id,
          "conversion_method" => "migration_consolidation"
        }
      )

      # Process the unified document if requested
      if options[:process_embeddings]
        unified_doc.process_document!
      else
        unified_doc.update!(status: "processed")
      end

      puts "✅ Migrated: #{document.title}"
      { status: :migrated, unified_document: unified_doc }
    rescue StandardError => e
      puts "❌ Failed to migrate #{document.title}: #{e.message}"
      raise MigrationError, "Migration failed for document #{document.id}: #{e.message}"
    end

    def extract_unified_text_from_document(document)
      text_parts = []

      # Collect text from all content types
      if document.respond_to?(:text_contents)
        document.text_contents.each do |tc|
          text_parts << tc.content if tc.content.present?
        end
      end

      if document.respond_to?(:image_contents)
        document.image_contents.each do |ic|
          text_parts << ic.description if ic.description.present?
        end
      end

      if document.respond_to?(:audio_contents)
        document.audio_contents.each do |ac|
          text_parts << ac.transcript if ac.transcript.present?
        end
      end

      # Fallback to document content field
      if text_parts.empty? && document.content.present?
        text_parts << document.content
      end

      # Join all text parts
      unified_text = text_parts.compact.reject(&:empty?).join("\n\n")

      # If still no content, try to regenerate from file
      if unified_text.blank? && File.exist?(document.location)
        begin
          unified_text = @converter.convert_to_text(document.location, document.document_type)
        rescue StandardError => e
          puts "Warning: Could not regenerate content for #{document.location}: #{e.message}"
        end
      end

      unified_text
    end

    def determine_primary_media_type(document)
      # Determine the primary media type based on document structure
      if document.respond_to?(:content_types)
        content_types = document.content_types
        return content_types.first if content_types.any?
      end

      # Fallback to document type
      case document.document_type
      when "text", "markdown", "html", "pdf", "docx"
        "text"
      when "image"
        "image"
      when "audio"
        "audio"
      else
        "text"
      end
    end

    def merge_document_metadata(document)
      base_metadata = document.metadata || {}

      # Add migration tracking
      base_metadata.merge(
        "migrated_from_multi_modal" => true,
        "migration_timestamp" => Time.current,
        "original_system" => "multi_modal_sti"
      )
    end

    def content_quality_report
      return {} unless defined?(Ragdoll::UnifiedContent)

      total_contents = Ragdoll::UnifiedContent.count
      return { error: "No content to analyze" } if total_contents == 0

      high_quality = Ragdoll::UnifiedContent.where("LENGTH(content) > 100").count
      medium_quality = Ragdoll::UnifiedContent.where("LENGTH(content) BETWEEN 50 AND 100").count
      low_quality = Ragdoll::UnifiedContent.where("LENGTH(content) < 50").count

      {
        total_contents: total_contents,
        high_quality: high_quality,
        medium_quality: medium_quality,
        low_quality: low_quality,
        high_quality_percentage: (high_quality.to_f / total_contents * 100).round(1),
        medium_quality_percentage: (medium_quality.to_f / total_contents * 100).round(1),
        low_quality_percentage: (low_quality.to_f / total_contents * 100).round(1)
      }
    end

    def generate_migration_recommendations
      recommendations = []

      # Check if UnifiedDocument is available
      if defined?(Ragdoll::UnifiedDocument)
        quality_report = content_quality_report

        if quality_report[:low_quality_percentage] && quality_report[:low_quality_percentage] > 20
          recommendations << "Consider reprocessing low-quality content with enhanced conversion settings"
        end

        if quality_report[:total_contents] && quality_report[:total_contents] > 0
          recommendations << "Review content quality scores and adjust conversion parameters as needed"
        end
      else
        recommendations << "Enable UnifiedDocument and UnifiedContent models to start migration"
      end

      recommendations << "Test search functionality with unified text-based approach"
      recommendations << "Monitor embedding generation performance with single model"
      recommendations << "Consider archiving old multi-modal content tables after validation"

      recommendations
    end
  end
end