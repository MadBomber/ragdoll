#!/usr/bin/env ruby
# frozen_string_literal: true

# Image processing example for unified text-based RAG system
# Demonstrates how images are converted to searchable text descriptions
require_relative "../lib/ragdoll"

# Configure Ragdoll for unified text-based image processing
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

  # Unified content processing - images converted to text descriptions
  config.use_unified_content = true
  config.embedding_model = "text-embedding-3-large"
  config.embedding_provider = :openai

  # Text conversion settings for images
  config.text_conversion = {
    image_detail_level: :comprehensive,  # :minimal, :standard, :comprehensive
    image_description_provider: :openai, # or :ollama, :azure
    image_max_tokens: 500,
    enable_fallback_descriptions: true,
    min_content_length: 20,
    max_content_length: 50000
  }
end

puts "=== Unified Image-to-Text Processing Example ==="

if ARGV.empty?
  puts "\nUsage: #{$PROGRAM_NAME} IMAGE_PATH"
  puts ""
  puts "This example demonstrates the unified text-based RAG approach:"
  puts "1. Image files are converted to comprehensive text descriptions"
  puts "2. Descriptions are embedded using a single text embedding model"
  puts "3. Images become searchable through their text descriptions"
  puts ""
  puts "Examples:"
  puts "  #{$PROGRAM_NAME} /path/to/image.jpg"
  puts "  #{$PROGRAM_NAME} /path/to/photo.png"
  puts ""
  puts "Supported formats: JPG, PNG, GIF, BMP, WEBP, SVG, ICO, TIFF"
  puts "All images → comprehensive text descriptions → unified embeddings"
  exit 1
end

image_path = ARGV.shift

unless File.exist?(image_path)
  warn "❌ Error: File not found - #{image_path}"
  warn "Please provide a valid path to an image file."
  exit 1
end

puts "\n🖼️  Processing image through unified text-based RAG: #{File.basename(image_path)}"
puts "📁 Image path: #{image_path}"

begin
  puts "\n🔄 Unified Processing Pipeline:"
  puts "1. 🖼️  Image file detected"
  puts "2. 🤖 Generating comprehensive text description..."
  puts "3. 📝 Converting to unified text content"
  puts "4. 🔗 Creating unified embeddings"
  puts "5. 🔍 Making searchable through text description"

  # Add image to unified RAG system (auto-converts to text)
  result = Ragdoll.add_document(path: image_path)

  if result[:success]
    puts "\n✅ Image successfully processed through unified pipeline!"
    puts "\n📊 Processing Results:"
    puts "Document ID: #{result[:document_id]}"
    puts "Original media type: image → unified text content"
    puts "Text description length: #{result[:content_length]} characters"
    puts "Content quality score: #{result[:content_quality_score]&.round(2)}" if result[:content_quality_score]
    puts "Title: #{result[:title]}"

    # Get the generated text description
    doc_details = Ragdoll.get_document(id: result[:document_id])
    if doc_details && doc_details[:content]
      puts "\n" + "="*60
      puts "📝 GENERATED TEXT DESCRIPTION:"
      puts "="*60
      puts doc_details[:content]
      puts "="*60

      puts "\n🔍 Search Integration:"
      puts "This image is now searchable using text queries like:"
      puts "- Content-based searches (what's in the image)"
      puts "- Object recognition queries"
      puts "- Scene description searches"
      puts "- Color and composition queries"

      # Demonstrate search capability
      puts "\n🎯 Testing unified search capability..."
      sample_queries = ["image", "photo", "visual", "picture"]

      sample_queries.each do |query|
        search_results = Ragdoll.search(query: query, limit: 1)
        if search_results[:results].any? && search_results[:results].first[:document_id] == result[:document_id]
          puts "✅ Image found via '#{query}' search (Score: #{search_results[:results].first[:similarity]&.round(3)})"
          break
        end
      rescue => search_error
        puts "ℹ️  Search test skipped: #{search_error.message}"
      end
    end

    puts "\n💡 Unified System Benefits:"
    puts "✅ Image content is now text-searchable"
    puts "✅ Same embedding model used for all content types"
    puts "✅ Cross-modal search (find images via text descriptions)"
    puts "✅ Consistent relevance scoring with text documents"
    puts "✅ Single content model (no complex multi-modal STI)"

  else
    puts "❌ Failed to process image: #{result[:error]}"
    puts "\nℹ️  Note: Image processing requires:"
    puts "- Vision model access (OPENAI_API_KEY configured)"
    puts "- PostgreSQL database with pgvector extension"
    puts "- Network connectivity for AI image description"
  end

rescue => e
  warn "\n❌ Error processing image through unified system: #{e.message}"
  warn "\n🔍 Please verify:"
  warn "  - Image file exists and is readable"
  warn "  - OPENAI_API_KEY environment variable is set"
  warn "  - PostgreSQL database is accessible"
  warn "  - pgvector extension is installed"
  warn "\n💡 The unified system converts images to text descriptions"
  warn "   for consistent processing alongside other content types."
  exit 1
end

puts "\n🎉 Unified Image Processing Complete!"
puts "\nNext steps:"
puts "1. Add more images to build a searchable visual content library"
puts "2. Search for images using descriptive text queries"
puts "3. Combine image and text documents in unified searches"
puts "4. Use content quality scores to assess description effectiveness"
