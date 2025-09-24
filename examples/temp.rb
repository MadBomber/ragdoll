#!/usr/bin/env ruby
# frozen_string_literal: true

# Temporary test script for unified image processing
# Demonstrates how images are converted to searchable text in the unified RAG system

require_relative "../lib/ragdoll"

# Configure unified text-based image processing
Ragdoll.configure do |config|
  config.database = {
    adapter: "postgresql",
    database: ENV.fetch("RAGDOLL_DATABASE_NAME", "ragdoll_development"),
    username: "ragdoll",
    password: ENV["RAGDOLL_DATABASE_PASSWORD"],
    host: "localhost",
    port: 5432,
    auto_migrate: true
  }

  # Unified content processing
  config.use_unified_content = true
  config.embedding_model = "text-embedding-3-large"
  config.embedding_provider = :openai

  # Image to text conversion settings
  config.text_conversion = {
    image_detail_level: :comprehensive,
    image_description_provider: :openai,
    enable_fallback_descriptions: true
  }
end

puts "=== Unified Image Processing Test ==="

# Test with sample image path
image_path = ARGV.first || "gen_jack.jpeg"

unless File.exist?(image_path)
  puts "❌ Image file not found: #{image_path}"
  puts "\nUsage: #{$0} IMAGE_PATH"
  puts "\nThis script demonstrates unified image processing:"
  puts "• Image files → comprehensive text descriptions"
  puts "• Text descriptions → searchable embeddings"
  puts "• Unified search across all content types"
  exit 1
end

puts "🖼️  Processing image: #{image_path}"

begin
  # Process image through unified pipeline
  result = Ragdoll.add_document(path: image_path)

  if result[:success]
    puts "\n✅ Image processed successfully through unified pipeline!"
    puts "Document ID: #{result[:document_id]}"
    puts "Original media type: image → unified text"
    puts "Text description length: #{result[:content_length]} characters"
    puts "Quality score: #{result[:content_quality_score]&.round(2)}" if result[:content_quality_score]

    # Get the generated text description
    doc = Ragdoll.get_document(id: result[:document_id])
    if doc && doc[:content]
      puts "\n" + "="*50
      puts "📝 GENERATED TEXT DESCRIPTION:"
      puts "="*50
      puts doc[:content]
      puts "="*50

      # Test search functionality
      puts "\n🔍 Testing unified search..."
      search_results = Ragdoll.search(query: "image", limit: 1)
      if search_results[:results].any?
        puts "✅ Image found via text search!"
        puts "Similarity score: #{search_results[:results].first[:similarity]&.round(3)}"
      end
    end

    puts "\n💡 Unified Processing Benefits:"
    puts "✅ Image content now searchable as text"
    puts "✅ Cross-modal search capabilities"
    puts "✅ Single embedding model for all content"
    puts "✅ Simplified architecture"

  else
    puts "\n❌ Image processing failed: #{result[:error]}"
    puts "\nNote: Requires OPENAI_API_KEY for vision processing"
  end

rescue => e
  puts "\n❌ Error: #{e.message}"
  puts "\nUnified image processing requires:"
  puts "• PostgreSQL with pgvector extension"
  puts "• OPENAI_API_KEY environment variable"
  puts "• Valid image file path"
end
