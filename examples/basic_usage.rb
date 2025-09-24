#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic usage example for ragdoll-core
# This example shows how to get started with the unified text-based RAG system

require "bundler/setup"
require_relative "../lib/ragdoll"

puts "=== Ragdoll Core - Unified Text-Based RAG Example ==="

# Example 1: Configuration
puts "\n1. Configuring Ragdoll for Unified Text-Based RAG..."

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

  # Unified text-based RAG configuration
  # All documents (text, images, audio, video) are converted to text
  config.use_unified_content = true

  # Single embedding model for all content types
  config.embedding_model = "text-embedding-3-large"
  config.embedding_provider = :openai

  # Text conversion settings for different media types
  config.text_conversion = {
    # Image description detail level
    image_detail_level: :comprehensive,  # :minimal, :standard, :comprehensive

    # Audio transcription provider
    audio_transcription_provider: :openai,  # :openai, :azure, :whisper_local

    # Enable fallback descriptions for unsupported files
    enable_fallback_descriptions: true,

    # Content quality thresholds
    min_content_length: 10,
    max_content_length: 50000
  }

  # LLM providers configured via environment variables:
  # OPENAI_API_KEY, OLLAMA_ENDPOINT, etc.
end

puts "✅ Unified text-based RAG configuration complete"
puts "Database: #{Ragdoll.config.database[:database]}"
puts "Embedding model: #{Ragdoll.config.embedding_model}"
puts "Using unified content: #{Ragdoll.config.use_unified_content}"

# Example 2: Check system health
puts "\n2. Checking system health..."

if Ragdoll.healthy?
  puts "✅ Ragdoll system is healthy"
else
  puts "⚠️  Ragdoll system health check failed"
end

# Example 3: Add documents using high-level API
puts "\n3. Adding documents..."

# Create a simple text file for demonstration
require "tempfile"

text_file = Tempfile.new(["example", ".txt"])
text_file.write("Ragdoll is a Ruby library for Retrieval-Augmented Generation (RAG). It provides document processing, embedding generation, and semantic search capabilities using PostgreSQL and various LLM providers.")
text_file.rewind

begin
  # Add document using high-level API
  result = Ragdoll.add_document(path: text_file.path)
  
  if result[:success]
    doc_id = result[:document_id]
    puts "✅ Document added successfully"
    puts "Document ID: #{doc_id}"
    puts "Status: #{result[:status]}"
  else
    puts "❌ Failed to add document: #{result[:error]}"
  end
ensure
  text_file.close
  text_file.unlink
end

# Add an image document to demonstrate unified text conversion
image_file = Tempfile.new(["sample_image", ".png"])
# Create a simple 1x1 PNG for demonstration (in real usage, you'd use actual images)
image_file.write([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x37, 0x6E, 0xF9, 0x24, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82].pack("C*"))
image_file.rewind

begin
  puts "\nAdding image document (will be converted to text description)..."
  image_result = Ragdoll.add_document(path: image_file.path)

  if image_result[:success]
    puts "✅ Image document added and converted to text"
    puts "Document ID: #{image_result[:document_id]}"
    puts "Content preview: #{image_result[:content_preview]}" if image_result[:content_preview]
  else
    puts "ℹ️  Image processing may require vision model configuration"
  end
rescue StandardError => e
  puts "ℹ️  Image processing skipped: #{e.message}"
ensure
  image_file.close
  image_file.unlink
end

# Add another markdown document
markdown_file = Tempfile.new(["unified_guide", ".md"])
markdown_file.write(<<~MARKDOWN)
  # Unified Text-Based RAG System

  ## Overview

  The unified approach converts all media types (text, images, audio, video) into
  plain text before generating embeddings. This simplifies the architecture while
  enabling cross-modal search capabilities.

  ## Benefits

  - **Simplified Architecture**: Single content model instead of STI complexity
  - **Unified Search**: All content searchable through text embeddings
  - **Cross-Modal Retrieval**: Find images via descriptions, audio via transcripts
  - **Single Embedding Pipeline**: One model handles all content types

  ## Supported Formats

  - Text: TXT, MD, HTML, PDF, DOCX
  - Images: JPG, PNG, GIF, WebP (converted to descriptions)
  - Audio: MP3, WAV, M4A (converted to transcripts)
  - Video: MP4, AVI (audio track transcribed, visual frames described)
MARKDOWN
markdown_file.rewind

begin
  result2 = Ragdoll.add_document(path: markdown_file.path)

  if result2[:success]
    puts "✅ Markdown document added successfully"
    puts "Document ID: #{result2[:document_id]}"
    puts "Content type: Unified text (from markdown)"
  end
ensure
  markdown_file.close
  markdown_file.unlink
end

# Example 4: List documents
puts "\n4. Listing documents..."

documents = Ragdoll.list_documents
puts "Total documents: #{documents.count}"

documents.each do |doc|
  puts "- #{doc[:title]} (ID: #{doc[:id]}, Type: #{doc[:document_type]})"
end

# Example 5: Document status and processing
puts "\n5. Document processing status..."

if doc_id
  status = Ragdoll.document_status(id: doc_id)
  puts "Document #{doc_id} status: #{status[:status]}"
  
  if status[:status] != "processed"
    puts "Processing document..."
    # In a real application, you might want to wait or poll for completion
    puts "Note: Document processing happens asynchronously"
  end
end

# Example 6: Search documents
puts "\n6. searching documents..."

search_queries = [
  "unified text-based RAG",
  "cross-modal retrieval",
  "image descriptions",
  "simplified architecture",
  "embedding pipeline"
]

search_queries.each do |query|
  puts "\nQuery: '#{query}'"
  
  begin
    results = Ragdoll.search(query: query, limit: 3)
    
    if results[:results].any?
      puts "Found #{results[:results].count} results:"
      results[:results].each_with_index do |result, index|
        puts "  #{index + 1}. #{result[:document_title]} (Score: #{result[:similarity]&.round(3)})"
        puts "     #{result[:content][0..100]}..."
      end
    else
      puts "No results found"
    end
  rescue StandardError => e
    puts "Search failed (may require embeddings): #{e.message}"
  end
end

# Example 7: Enhanced search with context
puts "\n7. Enhanced search with context..."

begin
  enhanced_result = Ragdoll.enhance_prompt(
    prompt: "How does the unified text-based RAG system work with different media types?",
    context_limit: 3
  )

  puts "Enhanced prompt with context:"
  puts enhanced_result[:enhanced_prompt][0..300] + "..."
  puts "\nContext sources: #{enhanced_result[:context_sources].count}"
  puts "Media types in context: #{enhanced_result[:media_types_found].join(', ')}" if enhanced_result[:media_types_found]
rescue StandardError => e
  puts "Enhanced search failed: #{e.message}"
end

# Example 8: Get document details
puts "\n8. Document details..."

if doc_id
  doc_details = Ragdoll.get_document(id: doc_id)
  
  if doc_details
    puts "Document: #{doc_details[:title]}"
    puts "Location: #{doc_details[:location]}"
    puts "Content length: #{doc_details[:content_length]} characters"
    puts "Original media type: #{doc_details[:original_media_type]}" if doc_details[:original_media_type]
    puts "Conversion method: #{doc_details[:conversion_method]}" if doc_details[:conversion_method]
    puts "Content quality score: #{doc_details[:content_quality_score]&.round(2)}" if doc_details[:content_quality_score]
    puts "Created: #{doc_details[:created_at]}"
    puts "Status: #{doc_details[:status]}"

    if doc_details[:metadata].any?
      puts "Metadata keys: #{doc_details[:metadata].keys.join(', ')}"
    end
  end
end

# Example 9: System statistics
puts "\n9. System statistics..."

begin
  stats = Ragdoll.stats
  
  puts "Unified RAG System Statistics:"
  puts "- Total documents: #{stats[:total_documents]}"
  puts "- Documents by status: #{stats[:by_status]}"
  puts "- Documents by type: #{stats[:by_type]}"
  puts "- Total unified contents: #{stats[:total_unified_contents]}" if stats[:total_unified_contents]
  puts "- Content by original media type: #{stats[:by_original_media_type]}" if stats[:by_original_media_type]
  puts "- Content quality distribution: #{stats[:content_quality_distribution]}" if stats[:content_quality_distribution]
  puts "- Total embeddings: #{stats[:total_embeddings]}" if stats[:total_embeddings]
  puts "- Storage type: #{stats[:storage_type]}"
rescue StandardError => e
  puts "Stats unavailable: #{e.message}"
end

# Example 10: Version information
puts "\n10. Version information..."

versions = Ragdoll.version
if versions.any?
  puts "Installed versions:"
  versions.each { |v| puts "- #{v}" }
else
  puts "Version information not available"
end

puts "\n=== Unified Text-Based RAG Usage Complete ==="
puts "\nKey Benefits Demonstrated:"
puts "✅ All media types converted to searchable text"
puts "✅ Single embedding model for all content"
puts "✅ Cross-modal search (find images via descriptions)"
puts "✅ Simplified architecture (no STI complexity)"
puts "✅ Content quality assessment"
puts "✅ Unified search across all document types"

puts "\nPrerequisites:"
puts "1. PostgreSQL database with pgvector extension"
puts "2. 'ragdoll' user and 'ragdoll_development' database"
puts "3. RAGDOLL_DATABASE_PASSWORD environment variable"
puts "4. OPENAI_API_KEY environment variable for embeddings and text conversion"
puts "5. Optional: OLLAMA_ENDPOINT for local LLM providers"

puts "\nNext steps:"
puts "1. Add documents of various types (text, images, audio, video)"
puts "2. All content is automatically converted to text"
puts "3. Single embedding pipeline processes all content"
puts "4. Search works across all media types through text conversion"
puts "5. Use content quality scores to assess conversion effectiveness"

puts "\nUnified RAG API methods:"
puts "- Ragdoll.configure        # Configure unified text-based system"
puts "- Ragdoll.add_document     # Add any media type (auto-converted to text)"
puts "- Ragdoll.add_directory    # Batch add mixed media documents"
puts "- Ragdoll.search           # Unified search across all content types"
puts "- Ragdoll.enhance_prompt   # Context-aware text generation"
puts "- Ragdoll.list_documents   # List all documents with media type info"
puts "- Ragdoll.get_document     # Get document details including conversion info"
puts "- Ragdoll.content_quality  # Assess text conversion quality"
puts "- Ragdoll.migration_status # Check migration from multi-modal system"
puts "- Ragdoll.stats           # Unified content statistics"
puts "- Ragdoll.healthy?        # System health check"