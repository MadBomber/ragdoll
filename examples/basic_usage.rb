#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic usage example for ragdoll-core
# This example shows how to get started with the high-level API

require "bundler/setup"
require_relative "../lib/ragdoll"

puts "=== Ragdoll Core - Basic Usage Example ==="

# Example 1: Configuration
puts "\n1. Configuring Ragdoll..."

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
  
  # Note: LLM providers are configured via environment variables:
  # OPENAI_API_KEY, OLLAMA_ENDPOINT, etc.
  # The configuration will automatically use these environment variables
  
  # Models are configured via environment variables (with sensible defaults):
  # RAGDOLL_DEFAULT_TEXT_MODEL, RAGDOLL_TEXT_EMBEDDING_MODEL, etc.
  # Defaults: text models use gpt-4o, embeddings use text-embedding-3-small
  
  # Configuration settings use defaults from environment variables
  # Summarization enabled by default, search threshold defaults to 0.7
end

puts "✅ Configuration complete"
puts "Database: #{Ragdoll.config.database[:database]}"
puts "Default model: #{Ragdoll.config.models[:text_generation][:default]}"

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

# Add another document (title and metadata extracted automatically)
markdown_file = Tempfile.new(["guide", ".md"])
markdown_file.write(<<~MARKDOWN)
  # RAG System Guide
  
  ## What is RAG?
  
  Retrieval-Augmented Generation combines information retrieval with text generation. 
  The system first retrieves relevant documents from a knowledge base, then uses that 
  context to generate more accurate and informative responses.
  
  ## Key Components
  
  - **Document Processing**: Extract and chunk text from various file formats
  - **Embeddings**: Convert text into vector representations for semantic search
  - **Search Engine**: Find relevant content based on semantic similarity
  - **Generation**: Use retrieved context to generate responses
MARKDOWN
markdown_file.rewind

begin
  result2 = Ragdoll.add_document(path: markdown_file.path)
  
  if result2[:success]
    puts "✅ Second document added successfully"
    puts "Document ID: #{result2[:document_id]}"
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
  "What is RAG?",
  "document processing",
  "semantic search",
  "Ruby library"
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
    prompt: "How does document processing work?",
    context_limit: 2
  )
  
  puts "Enhanced prompt with context:"
  puts enhanced_result[:enhanced_prompt][0..200] + "..."
  puts "\nContext sources: #{enhanced_result[:context_sources].count}"
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
  
  puts "System Statistics:"
  puts "- Total documents: #{stats[:total_documents]}"
  puts "- Documents by status: #{stats[:by_status]}"
  puts "- Documents by type: #{stats[:by_type]}"
  puts "- Storage type: #{stats[:storage_type]}"
  
  if stats[:total_embeddings]
    puts "- Total embeddings: #{stats[:total_embeddings]}"
  end
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

puts "\n=== Basic Usage Complete ==="
puts "\nPrerequisites:"
puts "1. PostgreSQL database with 'ragdoll' user and 'ragdoll_development' database"  
puts "2. RAGDOLL_DATABASE_PASSWORD environment variable set"
puts "3. OPENAI_API_KEY environment variable set for LLM features"
puts "\nNext steps:"
puts "1. Configure your database connection and LLM providers"
puts "2. Add more documents using Ragdoll.add_document or Ragdoll.add_directory"
puts "3. Wait for documents to be processed (embeddings generated)"
puts "4. Use Ragdoll.search to find relevant content"
puts "5. Use Ragdoll.enhance_prompt for RAG-enhanced text generation"

puts "\nHigh-level API methods available:"
puts "- Ragdoll.configure        # Configure the system"
puts "- Ragdoll.add_document     # Add a single document"
puts "- Ragdoll.add_directory    # Add all documents in a directory"
puts "- Ragdoll.search           # Search for relevant content"
puts "- Ragdoll.enhance_prompt   # Get context for text generation"
puts "- Ragdoll.list_documents   # List all documents"
puts "- Ragdoll.get_document     # Get document details"
puts "- Ragdoll.delete_document  # Remove a document"
puts "- Ragdoll.stats           # System statistics"
puts "- Ragdoll.healthy?        # System health check"