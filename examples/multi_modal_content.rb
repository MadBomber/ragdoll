#!/usr/bin/env ruby
# frozen_string_literal: true

# Example demonstrating multi-modal content with ragdoll-core
# This example shows how to work with TextContent, ImageContent, and AudioContent models

require "bundler/setup"
require_relative "../lib/ragdoll"
require "tempfile"

# Configure Ragdoll using high-level API
Ragdoll.configure do |config|
  # Database configuration (PostgreSQL required)
  # Use the default ragdoll_development database or set RAGDOLL_DATABASE_NAME
  config.database = {
    adapter: "postgresql",
    database: ENV.fetch("RAGDOLL_DATABASE_NAME", "ragdoll_development"),
    username: "ragdoll",
    password: ENV["RAGDOLL_DATABASE_PASSWORD"],
    host: "localhost",
    port: 5432,
    auto_migrate: true
  }

  # Embedding models are configured via environment variables with defaults:
  # RAGDOLL_TEXT_EMBEDDING_MODEL (default: openai/text-embedding-3-small)
  # RAGDOLL_IMAGE_EMBEDDING_MODEL (default: openai/clip-vit-base-patch32)
  # RAGDOLL_AUDIO_EMBEDDING_MODEL (default: openai/whisper-1)

  # LLM providers configured via environment variables:
  # OPENAI_API_KEY, OLLAMA_ENDPOINT
end

puts "=== Multi-Modal Content Example ==="

# Example 1: Create a text document using high-level API
puts "\n1. Creating text document..."

# Create a temporary text file
text_file = Tempfile.new(["multimodal_text", ".txt"])
text_file.write("This is a comprehensive example of multi-modal document processing. The document contains text content that demonstrates Ragdoll's ability to process and embed textual information for semantic search and retrieval.")
text_file.rewind

begin
  # Add document using high-level API
  text_result = Ragdoll.add_document(path: text_file.path)
  
  if text_result[:success]
    text_doc_id = text_result[:document_id]
    puts "✅ Text document added successfully"
    puts "Document ID: #{text_doc_id}"
    puts "Title: #{text_result[:title]}"
    puts "Content length: #{text_result[:content_length]} characters"
  else
    puts "❌ Failed to add text document: #{text_result[:error]}"
  end
ensure
  text_file.close
  text_file.unlink
end

# Example 2: Add image document using high-level API
puts "\n2. Adding image document..."

# Use the existing example image if it exists
image_path = File.join(File.dirname(__FILE__), "gen_jack.jpeg")
if File.exist?(image_path)
  begin
    image_result = Ragdoll.add_document(path: image_path)
    
    if image_result[:success]
      image_doc_id = image_result[:document_id]
      puts "✅ Image document added successfully"
      puts "Document ID: #{image_doc_id}"
      puts "Title: #{image_result[:title]}"
      puts "Document type: #{image_result[:document_type]}"
    else
      puts "❌ Failed to add image document: #{image_result[:error]}"
    end
  rescue => e
    puts "❌ Error adding image: #{e.message}"
  end
else
  puts "ℹ️  No example image found at #{image_path}"
  puts "   In a real application, you would add image files using:"
  puts "   Ragdoll.add_document(path: '/path/to/image.jpg')"
end

# Example 3: Add audio content (if available)
puts "\n3. Audio content processing..."

# Audio files would be processed similarly to text and images
puts "ℹ️  Audio files can be added using:"
puts "   Ragdoll.add_document(path: '/path/to/audio.mp3')"
puts "   Ragdoll.add_document(path: '/path/to/audio.wav')"
puts "\n   Audio processing includes:"
puts "   • Transcription using speech-to-text models"
puts "   • Audio embedding generation"
puts "   • Metadata extraction (duration, format, etc.)"

# Example 4: Working with multi-modal documents
puts "\n4. Multi-modal document capabilities..."

puts "✅ Ragdoll supports multiple content types:"
puts "• Text files (.txt, .md, .html, .pdf, .docx)"
puts "• Image files (.jpg, .png, .gif, .webp)"  
puts "• Audio files (.mp3, .wav, .m4a)"
puts "• Mixed documents containing multiple content types"

# Example 5: Search across all content types
puts "\n5. Multi-modal search capabilities..."

if defined?(text_doc_id)
  puts "Searching for text content..."
  begin
    search_results = Ragdoll.search(query: "multi-modal processing", limit: 3)
    puts "Found #{search_results[:total_results]} results"
    
    if search_results[:results].any?
      search_results[:results].each_with_index do |result, index|
        puts "  #{index + 1}. #{result[:document_title]} (Score: #{result[:similarity]&.round(3)})"
      end
    else
      puts "No results found (documents may still be processing)"
    end
  rescue => e
    puts "Search failed: #{e.message}"
  end
end

# Example 6: Document status and processing
puts "\n6. Document processing status..."

if defined?(text_doc_id)
  begin
    status = Ragdoll.document_status(id: text_doc_id)
    puts "Text document status: #{status[:status]}"
    puts "Embeddings ready: #{status[:embeddings_ready]}"
    puts "Embeddings count: #{status[:embeddings_count]}"
  rescue => e
    puts "Status check failed: #{e.message}"
  end
end

# Example 7: System statistics for multi-modal content
puts "\n7. System statistics..."

begin
  stats = Ragdoll.stats
  puts "System Statistics:"
  puts "- Total documents: #{stats[:total_documents]}"
  puts "- Documents by type: #{stats[:by_type]}"
  puts "- Total embeddings: #{stats[:total_embeddings]}"
  
  if stats[:content_types]
    puts "- Content types processed: #{stats[:content_types].keys.join(', ')}"
  end
rescue => e
  puts "Stats unavailable: #{e.message}"
end

# Example 8: Multi-modal document capabilities summary
puts "\n8. Multi-modal capabilities summary..."

puts "✅ Ragdoll's multi-modal features:"
puts "\n📄 Text Processing:"
puts "• Document parsing (PDF, DOCX, TXT, MD, HTML)"
puts "• Text chunking and embedding generation"
puts "• Full-text search and semantic similarity"

puts "\n🖼️  Image Processing:"
puts "• Image format support (JPEG, PNG, GIF, WebP)"
puts "• Automatic image description generation"
puts "• Visual content embedding for similarity search"

puts "\n🎵 Audio Processing:"
puts "• Audio format support (MP3, WAV, M4A)"
puts "• Speech-to-text transcription"
puts "• Audio content embedding and search"

puts "\n🔍 Unified Search:"
puts "• Cross-modal semantic search"
puts "• Content type filtering and hybrid search"
puts "• Combined embeddings for comprehensive results"


puts "\n=== Multi-Modal Content Integration Complete ==="
puts "\nKey takeaways:"
puts "1. Documents can contain multiple content types (text, image, audio)"
puts "2. Each content type has specialized processing and embedding models"
puts "3. Ragdoll automatically detects file types and applies appropriate processing"
puts "4. All content types support unified semantic search"
puts "5. Multi-modal documents enable comprehensive information retrieval"
puts "6. The high-level API abstracts away complexity while providing full functionality"

puts "\nHigh-level API methods used in this example:"
puts "- Ragdoll.configure        # Configure the system"
puts "- Ragdoll.add_document     # Add documents of any supported type"
puts "- Ragdoll.search           # Search across all content types"
puts "- Ragdoll.document_status  # Check processing status"
puts "- Ragdoll.stats           # Get system statistics"
