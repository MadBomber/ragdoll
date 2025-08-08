#!/usr/bin/env ruby
# frozen_string_literal: true

# Example demonstrating summary and keywords functionality
# This example shows how documents automatically generate summaries and keywords

require "bundler/setup"
require_relative "../lib/ragdoll"

# Configure Ragdoll using high-level API
Ragdoll.configure do |config|
  # Database configuration (PostgreSQL required)
  # Use a custom database name for this example
  config.database = {
    adapter: "postgresql",
    database: ENV.fetch("RAGDOLL_DATABASE_NAME", "ragdoll_development"),
    username: "ragdoll",
    password: ENV["RAGDOLL_DATABASE_PASSWORD"],
    host: "localhost",
    port: 5432,
    auto_migrate: true
  }

  # Models and LLM providers are configured via environment variables:
  # OPENAI_API_KEY, OLLAMA_ENDPOINT, etc.
  # Models default to gpt-4o for text generation tasks

  # Summarization is enabled by default
end

puts "=== Summary and Keywords Example ==="

# Example content about machine learning
ml_content = <<~TEXT
  Machine learning is a method of data analysis that automates analytical model building.#{' '}
  It is a branch of artificial intelligence based on the idea that systems can learn from data,#{' '}
  identify patterns and make decisions with minimal human intervention. Machine learning algorithms#{' '}
  build a model based on training data in order to make predictions or decisions without being#{' '}
  explicitly programmed to do so. Applications range from email filtering and computer vision#{' '}
  to recommendation systems and autonomous vehicles. The field has gained tremendous momentum#{' '}
  with the advent of big data, improved algorithms, and increased computational power.
TEXT

# Create a document using high-level API
puts "\n1. Creating document with text content..."

# Create a temporary text file
require "tempfile"
text_file = Tempfile.new(["machine_learning_intro", ".txt"])
text_file.write(ml_content)
text_file.rewind

begin
  # Add document using high-level API
  result = Ragdoll.add_document(path: text_file.path)
  
  if result[:success]
    doc_id = result[:document_id]
    puts "✅ Document added successfully"
    puts "Document ID: #{doc_id}"
    puts "Content length: #{result[:content_length]} characters"
    puts "Title: #{result[:title]}"
  else
    puts "❌ Failed to add document: #{result[:error]}"
  end
ensure
  text_file.close
  text_file.unlink
end

# Wait a moment for processing
puts "\n2. Checking document processing status..."
if doc_id
  status = Ragdoll.document_status(id: doc_id)
  puts "Document status: #{status[:status]}"
  puts "Embeddings ready: #{status[:embeddings_ready]}"
  
  # Get document details to see metadata
  doc_details = Ragdoll.get_document(id: doc_id)
  if doc_details && doc_details[:metadata]
    puts "\n3. Generated Summary:"
    puts doc_details[:metadata]['summary'] || "Summary not yet generated"
    
    puts "\n4. Extracted Keywords:"
    puts doc_details[:metadata]['keywords'] || "Keywords not yet generated"
  else
    puts "\nNote: Metadata (summary and keywords) are generated during document processing."
    puts "In a real application, you would wait for processing to complete."
  end
end

# Example 2: Create another document
puts "\n5. Creating second document..."
ai_content = <<~TEXT
  Artificial intelligence (AI) refers to the simulation of human intelligence in machines#{' '}
  that are programmed to think like humans and mimic their actions. The term may also be#{' '}
  applied to any machine that exhibits traits associated with a human mind such as learning#{' '}
  and problem-solving. AI research has been highly successful in developing effective#{' '}
  techniques for solving a wide range of problems, from game playing to medical diagnosis.#{' '}
  Neural networks, deep learning, natural language processing, and computer vision are#{' '}
  key areas of AI research and development.
TEXT

# Create second temporary text file
ai_file = Tempfile.new(["ai_overview", ".txt"])
ai_file.write(ai_content)
ai_file.rewind

begin
  # Add second document using high-level API
  result2 = Ragdoll.add_document(path: ai_file.path)
  
  if result2[:success]
    doc2_id = result2[:document_id]
    puts "✅ Second document added successfully"
    puts "Document ID: #{doc2_id}"
    puts "Title: #{result2[:title]}"
    
    # Get document details
    doc2_details = Ragdoll.get_document(id: doc2_id)
    if doc2_details && doc2_details[:metadata]
      puts "Summary: #{doc2_details[:metadata]['summary'] || 'Summary not yet generated'}"
      puts "Keywords: #{doc2_details[:metadata]['keywords'] || 'Keywords not yet generated'}"
    end
  else
    puts "❌ Failed to add second document: #{result2[:error]}"
  end
ensure
  ai_file.close
  ai_file.unlink
end

# Demonstrate search functionality
puts "\n6. Search functionality..."

# Search across documents
puts "Searching for 'machine learning':"
begin
  search_results = Ragdoll.search(query: "machine learning", limit: 5)
  
  if search_results[:results].any?
    puts "Found #{search_results[:total_results]} results:"
    search_results[:results].each_with_index do |result, index|
      puts "  #{index + 1}. #{result[:document_title]} (Score: #{result[:similarity]&.round(3)})"
    end
  else
    puts "No results found (documents may still be processing)"
  end
rescue => e
  puts "Search failed: #{e.message}"
end

puts "\nSearching for 'artificial intelligence':"
begin
  search_results = Ragdoll.search(query: "artificial intelligence", limit: 5)
  
  if search_results[:results].any?
    puts "Found #{search_results[:total_results]} results:"
    search_results[:results].each_with_index do |result, index|
      puts "  #{index + 1}. #{result[:document_title]} (Score: #{result[:similarity]&.round(3)})"
    end
  else
    puts "No results found (documents may still be processing)"
  end
rescue => e
  puts "Search failed: #{e.message}"
end

# List all documents
puts "\n7. Listing all documents:"
begin
  documents = Ragdoll.list_documents
  puts "Total documents: #{documents.count}"
  
  documents.each do |doc|
    puts "- #{doc[:title]} (ID: #{doc[:id]}, Status: #{doc[:status]})"
  end
rescue => e
  puts "Failed to list documents: #{e.message}"
end

puts "\n=== Summary and Keywords Integration Complete ==="
puts "\nKey features demonstrated:"
puts "1. Automatic document processing with summary and keyword extraction"
puts "2. High-level API for document management and search"
puts "3. Metadata storage in structured JSON format"
puts "4. Semantic search across document content and metadata"
puts "5. Document status tracking and processing feedback"

puts "\nHigh-level API methods used:"
puts "- Ragdoll.configure        # System configuration"
puts "- Ragdoll.add_document     # Add documents with automatic processing"
puts "- Ragdoll.document_status  # Check processing status"
puts "- Ragdoll.get_document     # Retrieve document details and metadata"
puts "- Ragdoll.search           # Semantic search across documents"
puts "- Ragdoll.list_documents   # List all documents"

puts "\nNote: Summary and keyword generation requires:"
puts "- LLM configuration (OPENAI_API_KEY environment variable)"
puts "- Document processing time (happens asynchronously)"
