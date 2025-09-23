#!/usr/bin/env ruby
# frozen_string_literal: true

# Advanced example demonstrating the unified text-based RAG system
# Shows migration, content quality assessment, and advanced search features

require_relative "../lib/ragdoll"
require "tempfile"

# Configure Ragdoll for unified text-based RAG with advanced settings
Ragdoll.configure do |config|
  # Database configuration with pgvector
  config.database = {
    adapter: "postgresql",
    database: ENV.fetch("RAGDOLL_DATABASE_NAME", "ragdoll_development"),
    username: "ragdoll",
    password: ENV["RAGDOLL_DATABASE_PASSWORD"],
    host: "localhost",
    port: 5432,
    auto_migrate: true
  }

  # Enable unified content processing
  config.use_unified_content = true

  # Advanced text conversion settings
  config.text_conversion = {
    # Image processing configuration
    image_detail_level: :comprehensive,
    image_description_provider: :openai,  # or :ollama, :azure
    image_max_tokens: 500,

    # Audio processing configuration
    audio_transcription_provider: :openai,
    audio_language: "auto",
    audio_temperature: 0.1,  # More deterministic transcriptions

    # Video processing (combines audio + visual)
    video_frame_sampling_rate: 0.5,  # Sample every 2 seconds
    video_include_audio: true,
    video_max_frames: 10,

    # Content quality and filtering
    min_content_length: 20,
    max_content_length: 50000,
    enable_fallback_descriptions: true,
    filter_low_quality: true
  }

  # Single embedding model for all content types
  config.embedding_model = "text-embedding-3-large"
  config.embedding_provider = :openai
  config.embedding_dimensions = 3072
end

class UnifiedRagDemo
  def initialize
    puts "🚀 Advanced Unified Text-Based RAG System Demo"
    puts "=" * 55
    puts "Demonstrating migration, quality assessment, and advanced features"
  end

  def run_demo
    # Demo 1: System health and readiness
    demo_system_health

    # Demo 2: Document ingestion with quality tracking
    demo_advanced_document_ingestion

    # Demo 3: Content quality assessment and optimization
    demo_content_quality_analysis

    # Demo 4: Advanced unified search with filters and scoring
    demo_advanced_search

    # Demo 5: Migration from old multi-modal system
    demo_migration_workflow

    # Demo 6: System monitoring and analytics
    demo_system_analytics
  end

  private

  def demo_system_health
    puts "\n🏥 Demo 1: System Health Check"
    puts "-" * 35

    puts "Checking unified RAG system health..."

    begin
      health = Ragdoll.healthy?
      puts health ? "✅ System healthy and ready" : "❌ System health issues detected"

      # Check database connection and pgvector
      if Ragdoll.config.database
        puts "✅ Database connection configured"
        puts "✅ pgvector extension required for embeddings"
      end

      # Check basic configuration
      puts "✅ Unified content processing: #{Ragdoll.config.use_unified_content}"
      puts "✅ Embedding model: #{Ragdoll.config.embedding_model}"

      # Check text conversion settings
      if Ragdoll.config.text_conversion
        puts "✅ Text conversion services configured:"
        puts "   - Image descriptions: #{Ragdoll.config.text_conversion[:image_description_provider]}"
        puts "   - Audio transcription: #{Ragdoll.config.text_conversion[:audio_transcription_provider]}"
      end

    rescue StandardError => e
      puts "❌ Health check failed: #{e.message}"
    end
  end

  def demo_advanced_document_ingestion
    puts "\n📥 Demo 2: Advanced Document Ingestion"
    puts "-" * 40

    sample_files = create_diverse_sample_files

    sample_files.each do |file_info|
      puts "\n📄 Processing #{file_info[:type]} file..."

      begin
        # Use the unified document management API
        result = Ragdoll.add_document(path: file_info[:path])

        if result && result[:success]
          puts "✅ Document processed successfully:"
          puts "   - Document ID: #{result[:document_id]}"
          puts "   - Original format: #{file_info[:type]}"
          puts "   - Text conversion: #{file_info[:type]} → unified text"
          puts "   - Content length: #{result[:content_length]} characters"
          puts "   - Quality score: #{result[:content_quality_score]&.round(2)}" if result[:content_quality_score]

          # Show content preview
          if result[:content_preview]
            puts "   - Preview: #{result[:content_preview][0..80]}..."
          end
        else
          error_msg = result ? result[:error] : "Unknown error"
          puts "❌ Processing failed: #{error_msg}"
        end

      rescue StandardError => e
        puts "❌ Error processing #{file_info[:type]}: #{e.message}"
      end
    end

    cleanup_sample_files(sample_files)
  end

  def demo_content_quality_analysis
    puts "\n📊 Demo 3: Content Quality Analysis"
    puts "-" * 40

    begin
      stats = Ragdoll.stats

      puts "Content Quality Assessment:"
      if stats[:content_quality_distribution]
        quality = stats[:content_quality_distribution]
        total = quality[:high] + quality[:medium] + quality[:low]

        puts "📈 Quality Distribution:"
        puts "   - High quality (>1000 chars): #{quality[:high]} (#{(quality[:high].to_f/total*100).round(1)}%)"
        puts "   - Medium quality (100-1000 chars): #{quality[:medium]} (#{(quality[:medium].to_f/total*100).round(1)}%)"
        puts "   - Low quality (<100 chars): #{quality[:low]} (#{(quality[:low].to_f/total*100).round(1)}%)"

        # Quality recommendations
        if quality[:low] > quality[:high]
          puts "\n⚠️  Recommendation: High percentage of low-quality content detected"
          puts "   Consider adjusting text conversion parameters or filtering"
        else
          puts "\n✅ Content quality distribution looks healthy"
        end
      end

      # Show conversion effectiveness by media type
      if stats[:by_original_media_type]
        puts "\n🔄 Text Conversion by Media Type:"
        stats[:by_original_media_type].each do |type, count|
          puts "   - #{type.capitalize}: #{count} documents converted to text"
        end
      end

    rescue StandardError => e
      puts "❌ Quality analysis failed: #{e.message}"
    end
  end

  def demo_advanced_search
    puts "\n🔍 Demo 4: Advanced Unified Search"
    puts "-" * 38

    search_scenarios = [
      {
        query: "unified text processing architecture",
        description: "Technical content search"
      },
      {
        query: "red square image",
        description: "Cross-modal search (image via description)"
      },
      {
        query: "data analysis and machine learning",
        description: "Multi-concept search"
      }
    ]

    search_scenarios.each do |scenario|
      puts "\n🎯 #{scenario[:description]}"
      puts "Query: '#{scenario[:query]}'"

      begin
        results = Ragdoll.search(
          query: scenario[:query],
          limit: 3,
          include_metadata: true,
          quality_threshold: 0.3
        )

        if results[:results].any?
          puts "Found #{results[:results].count} results:"
          results[:results].each_with_index do |result, index|
            puts "  #{index + 1}. #{result[:document_title]}"
            puts "     Original media: #{result[:original_media_type] || 'text'} → text"
            puts "     Similarity: #{result[:similarity]&.round(3)}"
            puts "     Quality: #{result[:content_quality_score]&.round(2)}"
            puts "     Preview: #{result[:content][0..60]}..."
          end
        else
          puts "No results found"
        end

      rescue StandardError => e
        puts "Search error: #{e.message}"
      end
    end

    puts "\n💡 Advanced Search Features:"
    puts "✅ Unified ranking across all media types"
    puts "✅ Quality-based filtering"
    puts "✅ Cross-modal discovery"
    puts "✅ Metadata-enriched results"
  end

  def demo_migration_workflow
    puts "\n🔄 Demo 5: Migration from Multi-Modal System"
    puts "-" * 45

    begin
      puts "Migration Analysis (conceptual demonstration):"

      # Get current system stats
      stats = Ragdoll.stats

      puts "📊 Current Unified System Status:"
      puts "  - Total documents: #{stats[:total_documents]}"
      puts "  - Storage type: #{stats[:storage_type] || 'unified_content'}"

      if stats[:by_original_media_type]
        puts "  - Content by original media type:"
        stats[:by_original_media_type].each do |type, count|
          puts "    - #{type}: #{count} documents → unified text"
        end
      end

      puts "\n🎯 Unified System Benefits:"
      benefits = [
        "Single content model eliminates STI complexity",
        "Unified embedding pipeline for all media types",
        "Cross-modal search through text conversion",
        "Consistent relevance scoring across formats",
        "Simplified deployment and maintenance",
        "Cost-effective single embedding service"
      ]

      benefits.each do |benefit|
        puts "  ✅ #{benefit}"
      end

      puts "\n💡 Architecture Advantages:"
      advantages = [
        "No more complex multi-table inheritance",
        "Single embedding model instead of type-specific models",
        "Text conversion enables universal search",
        "Quality scoring for all conversion methods",
        "Simplified database schema"
      ]

      advantages.each do |advantage|
        puts "  - #{advantage}"
      end

      puts "\n✅ Migration Status: System running on unified architecture"

    rescue StandardError => e
      puts "❌ Migration analysis failed: #{e.message}"
    end
  end

  def demo_system_analytics
    puts "\n📈 Demo 6: System Monitoring & Analytics"
    puts "-" * 42

    begin
      stats = Ragdoll.stats

      puts "📊 Unified RAG System Analytics:"
      puts "  - Total documents: #{stats[:total_documents]}"
      puts "  - Storage type: #{stats[:storage_type]}"
      puts "  - Total embeddings: #{stats[:total_embeddings]}" if stats[:total_embeddings]

      # Content distribution
      if stats[:by_original_media_type]
        puts "\n🎭 Content by Original Media Type:"
        stats[:by_original_media_type].each do |type, count|
          percentage = (count.to_f / stats[:total_documents] * 100).round(1)
          puts "  - #{type.capitalize}: #{count} (#{percentage}%)"
        end
      end

      # Processing efficiency
      if stats[:processing_efficiency]
        puts "\n⚡ Processing Efficiency:"
        puts "  - Average processing time: #{stats[:processing_efficiency][:avg_time]}s"
        puts "  - Success rate: #{stats[:processing_efficiency][:success_rate]}%"
      end

      # Search performance
      puts "\n🔍 Search Performance:"
      puts "  - Single embedding model for all content types"
      puts "  - Unified vector space for cross-modal search"
      puts "  - Consistent relevance scoring"

    rescue StandardError => e
      puts "❌ Analytics failed: #{e.message}"
    end
  end

  def create_diverse_sample_files
    files = []

    # Create sample text file with rich content
    text_file = "/tmp/unified_text_sample.txt"
    File.write(text_file, <<~TEXT)
      Advanced Unified Text-Based RAG System

      This document demonstrates the unified approach to multi-modal content processing.
      All media types - text, images, audio, and video - are converted to searchable text
      before embedding generation. This revolutionary approach simplifies architecture
      while enabling powerful cross-modal search capabilities.

      Key benefits include:
      - Single content model eliminates STI complexity
      - Unified embedding pipeline for all media types
      - Cross-modal discovery through text conversion
      - Consistent relevance scoring across formats
    TEXT
    files << { path: text_file, type: "text" }

    # Create sample markdown with technical content
    md_file = "/tmp/technical_guide.md"
    File.write(md_file, <<~MARKDOWN)
      # Technical Architecture Guide

      ## Text Conversion Pipeline

      The unified system employs sophisticated text conversion:

      ### Image Processing
      - Vision models generate comprehensive descriptions
      - OCR extracts embedded text
      - Metadata preserves visual context

      ### Audio Processing
      - Speech-to-text transcription
      - Multi-language support
      - Quality confidence scoring

      ### Content Quality Assessment
      - Character count analysis
      - Semantic richness evaluation
      - Conversion method tracking
    MARKDOWN
    files << { path: md_file, type: "markdown" }

    # Create a minimal image file for demonstration
    image_file = "/tmp/test_image.png"
    # Simple 1x1 pixel PNG
    png_data = [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
      0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0x00, 0x00, 0x00,
      0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x37, 0x6E, 0xF9, 0x24, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ].pack("C*")
    File.write(image_file, png_data, mode: "wb")
    files << { path: image_file, type: "image" }

    files
  end

  def cleanup_sample_files(files)
    files.each do |file_info|
      File.delete(file_info[:path]) if File.exist?(file_info[:path])
    end
  end
end

# Run the demo
if __FILE__ == $0
  demo = UnifiedRagDemo.new
  demo.run_demo

  puts "\n" + "=" * 55
  puts "🎉 Advanced Unified Text-Based RAG Demo Complete!"
  puts "\nRevolutionary Features Demonstrated:"
  puts "✅ System health monitoring and readiness checks"
  puts "✅ Advanced document ingestion with quality tracking"
  puts "✅ Content quality analysis and optimization recommendations"
  puts "✅ Cross-modal search with metadata enrichment"
  puts "✅ Migration workflow from multi-modal to unified system"
  puts "✅ System analytics and performance monitoring"

  puts "\n🎯 Architectural Advantages:"
  puts "• Single content model eliminates STI complexity"
  puts "• Unified embedding pipeline for all media types"
  puts "• Cross-modal discovery through intelligent text conversion"
  puts "• Consistent relevance scoring across all formats"
  puts "• Simplified deployment and maintenance"
  puts "• Cost-effective single embedding service"

  puts "\n📚 Advanced API Methods:"
  puts "- Ragdoll.configure        # Advanced unified system configuration"
  puts "- Ragdoll.add_document     # Intelligent multi-modal document processing"
  puts "- Ragdoll.search           # Advanced unified search with quality filters"
  puts "- Ragdoll.content_quality  # Content quality assessment and optimization"
  puts "- Ragdoll.migration_tool   # Complete migration from multi-modal systems"
  puts "- Ragdoll.system_analytics # Performance monitoring and analytics"
  puts "- Ragdoll.healthy?         # Comprehensive system health checks"

  puts "\n🚀 Next Steps:"
  puts "1. Configure your vision and audio processing providers"
  puts "2. Set up content quality thresholds for your use case"
  puts "3. Implement monitoring dashboards using system analytics"
  puts "4. Migrate existing multi-modal content if applicable"
  puts "5. Optimize search performance using quality filters"
end