#!/usr/bin/env ruby
# frozen_string_literal: true

# Example demonstrating multi-modal content with ragdoll-core
# This example shows how to work with TextContent, ImageContent, and AudioContent models

require "bundler/setup"
require_relative "../lib/ragdoll"
require "tempfile"

# Configure ragdoll-core
Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: "postgresql",
    database: "ragdoll_multimodal_example",
    username: "ragdoll",
    password: ENV["DATABASE_PASSWORD"],
    host: "localhost",
    port: 5432,
    auto_migrate: true
  }

  # Configure embedding models for different content types
  config.models[:embedding][:text] = "text-embedding-3-small"
  config.models[:embedding][:image] = "clip-vit-large-patch14"
  config.models[:embedding][:audio] = "whisper-embedding-v1"

  # Configure Ruby LLM providers
  config.ruby_llm_config[:openai][:api_key] = ENV["OPENAI_API_KEY"]
  config.ruby_llm_config[:ollama][:endpoint] = ENV.fetch("OLLAMA_ENDPOINT", "http://localhost:11434/v1")
end

# Initialize the database
Ragdoll::Core::Database.setup

puts "=== Multi-Modal Content Example ==="

# Example 1: Create a document with text content
puts "\n1. Creating document with text content..."

document = Ragdoll::Core::Models::Document.create!(
  location: "example_text.txt",
  title: "Multi-Modal Example Document",
  document_type: "mixed",
  status: "pending",
  file_modified_at: Time.current
)

# Add text content
text_content = document.text_contents.create!(
  content: "This is a comprehensive example of multi-modal document processing. The document contains text, images, and audio content that can be processed together.",
  embedding_model: "text-embedding-3-small",
  metadata: { source: "manual_entry" }
)

puts "Document ID: #{document.id}"
puts "Text content ID: #{text_content.id}"
puts "Text word count: #{text_content.word_count}"

# Example 2: Add image content with description
puts "\n2. Adding image content..."

image_content = document.image_contents.create!(
  content: "A diagram showing the multi-modal architecture with text, image, and audio processing pipelines converging into a unified embedding space.",
  embedding_model: "clip-vit-large-patch14",
  metadata: {
    alt_text: "Multi-modal architecture diagram",
    width: 800,
    height: 600,
    content_type: "image/png"
  }
)

# Simulate setting image file data (in real usage, this would be actual image data)
image_content.image_data = "/path/to/architecture_diagram.png"
image_content.save!

puts "Image content ID: #{image_content.id}"
puts "Image has description: #{image_content.description.present?}"
puts "Image dimensions: #{image_content.image_dimensions}"

# Example 3: Add audio content with transcript
puts "\n3. Adding audio content..."

audio_content = document.audio_contents.create!(
  content: "Welcome to the multi-modal content processing example. This audio explains how different content types work together in the ragdoll system.",
  embedding_model: "whisper-embedding-v1",
  duration: 45.5,
  sample_rate: 44100,
  metadata: {
    codec: "mp3",
    bitrate: 128000,
    channels: 2,
    content_type: "audio/mpeg"
  }
)

puts "Audio content ID: #{audio_content.id}"
puts "Audio duration: #{audio_content.duration_formatted}"
puts "Audio has transcript: #{audio_content.transcript.present?}"

# Example 4: Explore the multi-modal document structure
puts "\n4. Multi-modal document structure..."

document.reload
puts "Document type: #{document.document_type}"
puts "Content types: #{document.content_types.join(', ')}"
puts "Is multi-modal: #{document.multi_modal?}"
puts "Primary content type: #{document.primary_content_type}"

puts "\nContent summary:"
puts "- Text contents: #{document.text_contents.count}"
puts "- Image contents: #{document.image_contents.count}"
puts "- Audio contents: #{document.audio_contents.count}"
puts "- Total contents: #{document.contents.count}"

# Example 5: Generate embeddings for all content types
puts "\n5. Generating embeddings for all content..."

begin
  puts "Generating text embeddings..."
  text_content.generate_embeddings!

  puts "Generating image embeddings..."
  image_content.generate_embeddings!

  puts "Generating audio embeddings..."
  audio_content.generate_embeddings!

  puts "All embeddings generated successfully!"
rescue StandardError => e
  puts "Note: Embedding generation may fail without proper LLM configuration: #{e.message}"
end

# Example 6: Working with content-specific methods
puts "\n6. Content-specific operations..."

# Text content operations
puts "\nText content operations:"
puts "- Character count: #{text_content.character_count}"
puts "- Word count: #{text_content.word_count}"
puts "- Chunk size: #{text_content.chunk_size}"
puts "- Overlap: #{text_content.overlap}"

if text_content.content.present?
  chunks = text_content.chunks
  puts "- Number of chunks: #{chunks.length}"
  puts "- First chunk preview: #{chunks.first[:content][0..50]}..." if chunks.any?
end

# Image content operations
puts "\nImage content operations:"
puts "- Description length: #{image_content.description&.length || 0} characters"
puts "- Alt text: #{image_content.alt_text}"
puts "- Image attached: #{image_content.image_attached?}"
puts "- Content for embedding: #{image_content.content_for_embedding[0..50]}..."

# Audio content operations
puts "\nAudio content operations:"
puts "- Transcript length: #{audio_content.transcript&.length || 0} characters"
puts "- Duration: #{audio_content.duration} seconds (#{audio_content.duration_formatted})"
puts "- Sample rate: #{audio_content.sample_rate} Hz"
puts "- Channels: #{audio_content.channels}"
puts "- Codec: #{audio_content.codec}"

# Example 7: Multi-modal search and retrieval
puts "\n7. Multi-modal search capabilities..."

# Get all embeddings across content types
all_embeddings = document.all_embeddings
puts "Total embeddings across all content types: #{all_embeddings.count}"

# Get embeddings by content type
text_embeddings = document.all_embeddings(content_type: :text)
image_embeddings = document.all_embeddings(content_type: :image)
audio_embeddings = document.all_embeddings(content_type: :audio)

puts "Embeddings by type:"
puts "- Text: #{text_embeddings.count}"
puts "- Image: #{image_embeddings.count}"
puts "- Audio: #{audio_embeddings.count}"

# Combined content for full-text search
combined_content = document.content
puts "\nCombined content preview: #{combined_content[0..100]}..."

# Example 8: Document statistics and metadata
puts "\n8. Document statistics..."

document.update!(status: "processed")

stats = {
  document_id: document.id,
  total_contents: document.contents.count,
  content_types: document.content_types,
  total_word_count: document.total_word_count,
  total_character_count: document.total_character_count,
  total_embedding_count: document.total_embedding_count,
  embeddings_by_type: document.embeddings_by_type
}

puts "Document statistics:"
stats.each do |key, value|
  puts "- #{key}: #{value.is_a?(Array) ? value.join(', ') : value}"
end

# Example 9: Content model statistics
puts "\n9. Content model statistics..."

text_stats = Ragdoll::Core::Models::TextContent.stats
image_stats = Ragdoll::Core::Models::ImageContent.stats
audio_stats = Ragdoll::Core::Models::AudioContent.stats

puts "\nSystem-wide content statistics:"
puts "Text content stats: #{text_stats}"
puts "Image content stats: #{image_stats}"
puts "Audio content stats: #{audio_stats}"

# Example 10: Document hash representation
puts "\n10. Document hash representation..."

document_hash = document.to_hash(include_content: true)
puts "\nDocument hash keys: #{document_hash.keys.join(', ')}"
puts "Content summary in hash: #{document_hash[:content_summary]}"

# Show content details
if document_hash[:content_details]
  details = document_hash[:content_details]
  puts "\nContent details:"
  puts "- Text contents: #{details[:text_content]&.length || 0}"
  puts "- Image descriptions: #{details[:image_descriptions]&.length || 0}"
  puts "- Audio transcripts: #{details[:audio_transcripts]&.length || 0}"
end

puts "\n=== Multi-Modal Content Integration Complete ==="
puts "\nKey takeaways:"
puts "1. Documents can contain multiple content types (text, image, audio)"
puts "2. Each content type has specialized methods and metadata"
puts "3. Content is stored using STI (Single Table Inheritance) in ragdoll_contents table"
puts "4. Embeddings are generated per content type with appropriate models"
puts "5. Multi-modal documents support unified search across all content types"
puts "6. Content-specific operations enable specialized processing workflows"
