#!/usr/bin/env ruby
# frozen_string_literal: true

# Example demonstrating unified text-based multi-modal content processing
# All media types (text, images, audio, video) are converted to text for unified search

require "bundler/setup"
require_relative "../lib/ragdoll"
require "tempfile"

# Configure Ragdoll for unified text-based multi-modal processing
Ragdoll.configure do |config|
  # Database configuration (PostgreSQL required with pgvector extension)
  config.database = {
    adapter: "postgresql",
    database: ENV.fetch("RAGDOLL_DATABASE_NAME", "ragdoll_development"),
    username: "ragdoll",
    password: ENV["RAGDOLL_DATABASE_PASSWORD"],
    host: "localhost",
    port: 5432,
    auto_migrate: true
  }

  # Enable unified text-based processing
  config.use_unified_content = true

  # Single embedding model for all content types (after text conversion)
  config.embedding_model = "text-embedding-3-large"
  config.embedding_provider = :openai

  # Text conversion settings for different media types
  config.text_conversion = {
    # Image processing
    image_detail_level: :comprehensive,
    image_description_prompt: "Describe this image in detail, including objects, scenes, text, and context.",

    # Audio processing
    audio_transcription_provider: :openai,
    audio_language: "auto",  # Auto-detect language

    # Video processing (combines audio transcription + frame descriptions)
    video_frame_sampling_rate: 1,  # Sample 1 frame per second
    video_include_audio: true,

    # Content quality settings
    min_content_length: 10,
    max_content_length: 100000,
    enable_fallback_descriptions: true
  }

  # LLM providers configured via environment variables:
  # OPENAI_API_KEY for embeddings and vision/audio processing
  # OLLAMA_ENDPOINT for local alternatives
end

puts "=== Unified Multi-Modal Content Processing Example ==="

# Example 1: Create a text document (baseline for unified system)
puts "\n1. Adding text document..."

# Create a temporary text file
text_file = Tempfile.new(["unified_text", ".txt"])
text_file.write("This demonstrates unified text-based processing. All content types - text, images, audio, and video - are converted to text and processed through a single embedding pipeline for simplified search and retrieval.")
text_file.rewind

begin
  # Add text document using unified API
  text_result = Ragdoll.add_document(path: text_file.path)

  if text_result[:success]
    text_doc_id = text_result[:document_id]
    puts "✅ Text document processed (original media: text)"
    puts "Document ID: #{text_doc_id}"
    puts "Title: #{text_result[:title]}"
    puts "Content length: #{text_result[:content_length]} characters"
    puts "Original media type: text → unified text content"
  else
    puts "❌ Failed to add text document: #{text_result[:error]}"
  end
ensure
  text_file.close
  text_file.unlink
end

# Example 2: Add image document (converted to text description)
puts "\n2. Adding image document (→ text conversion)..."

# Create a minimal PNG image for demonstration
image_file = Tempfile.new(["sample", ".png"])
# Simple 2x2 red square PNG
png_data = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02,
  0x08, 0x02, 0x00, 0x00, 0x00, 0xFD, 0xD4, 0x9A, 0x73, 0x00, 0x00, 0x00,
  0x0E, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0x0F, 0x00, 0x01,
  0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
].pack("C*")
image_file.write(png_data)
image_file.rewind

begin
  puts "Processing image → generating text description..."
  image_result = Ragdoll.add_document(path: image_file.path)

  if image_result[:success]
    image_doc_id = image_result[:document_id]
    puts "✅ Image converted to text description"
    puts "Document ID: #{image_doc_id}"
    puts "Original media type: image → unified text content"
    puts "Generated description length: #{image_result[:content_length]} characters"

    # Show how the image was converted to searchable text
    if image_result[:content_preview]
      puts "Description preview: #{image_result[:content_preview][0..100]}..."
    end
  else
    puts "ℹ️  Image processing requires vision model: #{image_result[:error]}"
    puts "   Configure OPENAI_API_KEY or use local vision models"
  end
rescue StandardError => e
  puts "ℹ️  Image processing skipped: #{e.message}"
  puts "   Images are converted to text descriptions for unified search"
ensure
  image_file.close
  image_file.unlink
end

# Example 3: Audio content processing (→ text transcription)
puts "\n3. Audio content processing (→ text conversion)..."

puts "🎵 Audio Processing in Unified System:"
puts "   • Audio files are transcribed to text using speech-to-text models"
puts "   • Transcriptions become searchable text content"
puts "   • Single embedding pipeline processes all transcribed audio"
puts "   • Metadata preserves original audio format and duration"

puts "\n   Example usage:"
puts "   Ragdoll.add_document(path: '/path/to/audio.mp3')"
puts "   → Audio transcribed to: 'Hello, this is a test recording about...'"
puts "   → Text embedded using unified embedding model"
puts "   → Searchable as text content with audio metadata"

puts "\n   Supported audio formats:"
puts "   • MP3, WAV, M4A, FLAC, OGG"
puts "   • Multi-language transcription support"
puts "   • Automatic language detection"
puts "   • Confidence scoring for transcription quality"

# Example 4: Unified multi-modal processing overview
puts "\n4. Unified multi-modal processing overview..."

puts "🔄 Text Conversion Pipeline:"
puts "📄 Text files → Direct text extraction (PDF, DOCX, MD, HTML, TXT)"
puts "🖼️  Images → AI-generated descriptions (comprehensive visual analysis)"
puts "🎵 Audio → Speech-to-text transcription (multi-language support)"
puts "🎬 Video → Audio transcription + frame descriptions (combined text)"

puts "\n✅ Unified System Benefits:"
puts "• Single content model (no STI complexity)"
puts "• One embedding pipeline for all media types"
puts "• Cross-modal search (find images via text descriptions)"
puts "• Simplified query interface"
puts "• Content quality scoring for all converted text"
puts "• Consistent search relevance across media types"

# Example 5: Unified cross-modal search
puts "\n5. Unified cross-modal search capabilities..."

search_queries = [
  "unified text processing",       # Should find text documents
  "image description",            # Should find converted image content
  "transcription and audio",      # Should find audio-related content
  "text conversion pipeline"      # Should find system description content
]

search_queries.each do |query|
  puts "\n🔍 Query: '#{query}'"
  begin
    search_results = Ragdoll.search(query: query, limit: 3)

    if search_results[:results].any?
      puts "Found #{search_results[:results].count} results:"
      search_results[:results].each_with_index do |result, index|
        puts "  #{index + 1}. #{result[:document_title]}"
        puts "     Original type: #{result[:original_media_type] || 'text'} → text"
        puts "     Similarity: #{result[:similarity]&.round(3)}"
        puts "     Content: #{result[:content][0..80]}..."
      end
    else
      puts "No results found (documents may still be processing embeddings)"
    end
  rescue StandardError => e
    puts "Search error: #{e.message}"
  end
end

puts "\n💡 Cross-Modal Search Examples:"
puts "• 'red color' → finds images with red objects (via descriptions)"
puts "• 'hello world' → finds audio files with those spoken words (via transcripts)"
puts "• 'presentation slides' → finds PDFs, images, and videos of presentations"
puts "• All results ranked by unified text similarity scoring"

# Example 6: Unified content processing status
puts "\n6. Unified content processing status..."

if defined?(text_doc_id) || defined?(image_doc_id)
  doc_to_check = defined?(text_doc_id) ? text_doc_id : image_doc_id

  begin
    status = Ragdoll.document_status(id: doc_to_check)
    puts "Document processing status:"
    puts "• Status: #{status[:status]}"
    puts "• Original media type: #{status[:original_media_type]}"
    puts "• Text conversion method: #{status[:conversion_method]}"
    puts "• Content quality score: #{status[:content_quality_score]&.round(2)}"
    puts "• Unified embeddings ready: #{status[:embeddings_ready]}"
    puts "• Embedding count: #{status[:embeddings_count]}"
    puts "• Searchable as text: #{status[:searchable]}"
  rescue StandardError => e
    puts "Status check failed: #{e.message}"
  end
end

puts "\n🔄 Processing Pipeline Summary:"
puts "1. Media file uploaded"
puts "2. Content type detected"
puts "3. Text conversion applied (description/transcription/extraction)"
puts "4. Text quality assessed"
puts "5. Single embedding model generates vectors"
puts "6. Content indexed for unified search"

# Example 7: Unified system statistics
puts "\n7. Unified system statistics..."

begin
  stats = Ragdoll.stats
  puts "Unified Multi-Modal System Statistics:"
  puts "• Total documents: #{stats[:total_documents]}"
  puts "• Documents by original format: #{stats[:by_type]}"
  puts "• Unified content entries: #{stats[:total_unified_contents]}" if stats[:total_unified_contents]

  if stats[:by_original_media_type]
    puts "• Content by original media type:"
    stats[:by_original_media_type].each do |type, count|
      puts "  - #{type}: #{count} documents"
    end
  end

  if stats[:content_quality_distribution]
    puts "• Text conversion quality:"
    quality = stats[:content_quality_distribution]
    puts "  - High quality (>1000 chars): #{quality[:high]}"
    puts "  - Medium quality (100-1000 chars): #{quality[:medium]}"
    puts "  - Low quality (<100 chars): #{quality[:low]}"
  end

  puts "• Total embeddings: #{stats[:total_embeddings]}" if stats[:total_embeddings]
  puts "• Single embedding model for all content types"
rescue StandardError => e
  puts "Stats unavailable: #{e.message}"
end

# Example 8: Unified multi-modal system advantages
puts "\n8. Unified system advantages..."

puts "🎯 Architecture Comparison:"
puts "\n❌ Old Multi-Modal System:"
puts "• Separate models for text, image, audio content (STI complexity)"
puts "• Multiple embedding pipelines and models"
puts "• Complex search across different vector spaces"
puts "• Inconsistent relevance scoring between media types"

puts "\n✅ New Unified Text-Based System:"
puts "• Single content model - all media converted to text"
puts "• One embedding pipeline using text-embedding-3-large"
puts "• Unified search interface across all content"
puts "• Consistent relevance scoring for all media types"
puts "• Cross-modal search via text conversion"
puts "• Simplified deployment and maintenance"

puts "\n🔄 Text Conversion Quality:"
puts "📄 Text files → Direct extraction (high fidelity)"
puts "🖼️  Images → AI descriptions (captures visual content semantically)"
puts "🎵 Audio → Speech transcription (preserves spoken information)"
puts "🎬 Video → Combined audio + visual descriptions"

puts "\n💡 Search Capabilities:"
puts "• Find images by describing visual content"
puts "• Locate audio by searching transcribed words"
puts "• Discover videos through spoken content or visual scenes"
puts "• All results ranked using unified similarity scoring"

puts "\n=== Unified Multi-Modal System Complete ==="
puts "\nRevolutionary Benefits:"
puts "1. ✅ Simplified architecture - single content model eliminates STI complexity"
puts "2. ✅ Universal search - all media types searchable through text conversion"
puts "3. ✅ Cross-modal discovery - find any content type using text queries"
puts "4. ✅ Consistent quality - unified embedding pipeline for all content"
puts "5. ✅ Easy maintenance - one model to manage instead of multiple"
puts "6. ✅ Cost effective - single embedding service for all media types"

puts "\nUnified API methods for all media types:"
puts "- Ragdoll.configure        # Configure unified text-based processing"
puts "- Ragdoll.add_document     # Add any media type (auto-converted to text)"
puts "- Ragdoll.search           # Unified search across all converted content"
puts "- Ragdoll.content_quality  # Assess text conversion effectiveness"
puts "- Ragdoll.migration_tool   # Migrate from old multi-modal system"
puts "- Ragdoll.stats           # Unified content statistics and quality metrics"
