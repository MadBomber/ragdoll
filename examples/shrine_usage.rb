#!/usr/bin/env ruby
# frozen_string_literal: true

# File upload integration example for unified text-based RAG system
# Demonstrates how all uploaded files are converted to searchable text content

require "bundler/setup"
require_relative "../lib/ragdoll"
require "tempfile"

# Configure Ragdoll for unified text-based file processing
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

  # Unified content processing for all uploaded files
  config.use_unified_content = true
  config.embedding_model = "text-embedding-3-large"
  config.embedding_provider = :openai

  # Text conversion settings for various file types
  config.text_conversion = {
    # Image processing
    image_detail_level: :comprehensive,
    image_description_provider: :openai,

    # Audio processing
    audio_transcription_provider: :openai,
    audio_language: "auto",

    # Content quality settings
    min_content_length: 10,
    max_content_length: 100000,
    enable_fallback_descriptions: true
  }
end

puts "=== Unified File Upload Processing Example ==="

# Example 1: Upload text file through unified system
puts "\n1. Text file upload through unified pipeline..."

# Create a temporary file to simulate file upload
temp_file = Tempfile.new(["example", ".txt"])
temp_file.write("This is example content for a text file uploaded through the unified RAG system.\nIt demonstrates how all file types are converted to searchable text content.\nThe unified approach simplifies processing while enabling powerful cross-file-type search.")
temp_file.rewind

begin
  # Add uploaded file to unified RAG system
  result = Ragdoll.add_document(path: temp_file.path)

  if result[:success]
    text_doc_id = result[:document_id]
    puts "✅ Text file processed through unified pipeline"
    puts "Document ID: #{text_doc_id}"
    puts "Original file type: text → unified text content"
    puts "Content length: #{result[:content_length]} characters"
    puts "Title: #{result[:title]}"
    puts "Content quality score: #{result[:content_quality_score]&.round(2)}" if result[:content_quality_score]
  else
    puts "❌ Failed to process text file: #{result[:error]}"
  end
rescue StandardError => e
  puts "Error processing uploaded text file: #{e.message}"
ensure
  temp_file.close
  temp_file.unlink
end

# Example 2: Upload image file (converted to text description)
puts "\n2. Image file upload through unified text conversion..."

# Create a minimal PNG for demonstration
image_file = Tempfile.new(["upload_demo", ".png"])
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
  puts "Processing uploaded image → text description..."
  image_result = Ragdoll.add_document(path: image_file.path)

  if image_result[:success]
    image_doc_id = image_result[:document_id]
    puts "✅ Image file converted to searchable text"
    puts "Document ID: #{image_doc_id}"
    puts "Original file type: image → unified text content"
    puts "Generated description length: #{image_result[:content_length]} characters"
    puts "Content quality score: #{image_result[:content_quality_score]&.round(2)}" if image_result[:content_quality_score]
  else
    puts "ℹ️  Image processing requires vision model: #{image_result[:error]}"
  end
rescue StandardError => e
  puts "ℹ️  Image processing skipped: #{e.message}"
ensure
  image_file.close
  image_file.unlink
end

# Example 3: Multiple file types processed through unified pipeline
puts "\n3. Multiple file types through unified text conversion..."

file_demos = [
  {
    name: "markdown",
    ext: ".md",
    content: "# Uploaded Markdown\n\nThis **markdown file** was uploaded and processed through the unified text-based RAG system.",
    description: "Markdown → extracted text"
  },
  {
    name: "html",
    ext: ".html",
    content: "<html><body><h1>Uploaded HTML</h1><p>This HTML file content is <strong>extracted as text</strong> for unified search.</p></body></html>",
    description: "HTML → extracted text"
  },
  {
    name: "csv",
    ext: ".csv",
    content: "name,age,city\nJohn,30,NYC\nJane,25,LA\nBob,35,Chicago",
    description: "CSV → structured text"
  }
]

file_demos.each do |demo|
  temp = Tempfile.new(["upload_#{demo[:name]}", demo[:ext]])
  temp.write(demo[:content])
  temp.rewind

  begin
    result = Ragdoll.add_document(path: temp.path)

    if result[:success]
      puts "✅ #{demo[:name].upcase} file: #{demo[:description]}"
      puts "   Document ID: #{result[:document_id]}"
      puts "   Content length: #{result[:content_length]} characters"
      puts "   Quality score: #{result[:content_quality_score]&.round(2)}" if result[:content_quality_score]
    else
      puts "❌ Failed to process #{demo[:name]} file: #{result[:error]}"
    end
  rescue StandardError => e
    puts "Error with #{demo[:name]} file: #{e.message}"
  ensure
    temp.close
    temp.unlink
  end
end

# Example 4: Cross-file-type unified search
puts "\n4. Cross-file-type unified search capabilities..."

if defined?(text_doc_id) || defined?(image_doc_id)
  search_terms = ["uploaded", "unified", "text", "content"]

  search_terms.each do |term|
    begin
      results = Ragdoll.search(query: term, limit: 3)

      if results[:results].any?
        puts "\n🔍 Search for '#{term}':"
        results[:results].each_with_index do |result, index|
          puts "  #{index + 1}. #{result[:document_title]}"
          puts "     Original type: #{result[:original_media_type] || 'text'} → unified text"
          puts "     Similarity: #{result[:similarity]&.round(3)}"
        end
      end
    rescue => e
      puts "Search for '#{term}' skipped: #{e.message}"
    end
  end
end

# Example 5: Unified document management
puts "\n5. Unified document management and metadata..."

begin
  documents = Ragdoll.list_documents
  puts "📊 Uploaded File Statistics:"
  puts "Total unified documents: #{documents.count}"

  if documents.any?
    type_counts = documents.group_by { |doc| doc[:original_media_type] || 'text' }
                           .transform_values(&:count)

    puts "\nContent by original file type:"
    type_counts.each do |type, count|
      puts "  #{type}: #{count} files → unified text content"
    end

    quality_scores = documents.filter_map { |doc| doc[:content_quality_score] }
    if quality_scores.any?
      avg_quality = quality_scores.sum / quality_scores.length
      puts "\nAverage content quality score: #{avg_quality.round(2)}"
    end
  end

rescue StandardError => e
  puts "Document statistics unavailable: #{e.message}"
end

puts "\n=== Unified File Upload Processing Complete ==="
puts "\n🎯 Revolutionary File Upload Benefits:"
puts "✅ All uploaded file types → unified text content"
puts "✅ Single embedding model for all file formats"
puts "✅ Cross-file-type search (find any content via text)"
puts "✅ Simplified architecture (no complex file type handling)"
puts "✅ Content quality assessment for all conversions"
puts "✅ Consistent search relevance across file types"

puts "\n🔄 Unified Processing Pipeline:"
puts "📄 Text files (TXT, MD, HTML, CSV) → direct text extraction"
puts "🖼️  Images (JPG, PNG, GIF) → AI-generated descriptions"
puts "🎵 Audio files (MP3, WAV) → speech-to-text transcription"
puts "📊 Documents (PDF, DOCX) → text extraction"
puts "🎬 Video files (MP4, AVI) → audio transcription + frame descriptions"

puts "\n💡 Integration Benefits:"
puts "• Upload any file type through standard web forms"
puts "• All content becomes immediately searchable as text"
puts "• No complex file type-specific handling required"
puts "• Single API for all uploaded content management"
puts "• Quality scoring helps assess conversion effectiveness"
puts "• Unified storage model simplifies database design"
