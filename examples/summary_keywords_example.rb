#!/usr/bin/env ruby
# frozen_string_literal: true

# Example demonstrating summary and keywords functionality
# This example shows how documents automatically generate summaries and keywords

require "bundler/setup"
require_relative "../lib/ragdoll"

# Configure ragdoll-core
Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: "postgresql",
    database: "ragdoll_summary_example",
    username: "ragdoll",
    password: ENV["RAGDOLL_DATABASE_PASSWORD"],
    host: "localhost",
    port: 5432,
    auto_migrate: true
  }

  # Configure models for summary and keyword generation
  config.models[:summary] = "openai/gpt-4o-mini"
  config.models[:keywords] = "openai/gpt-4o-mini"

  # Configure Ruby LLM providers
  config.ruby_llm_config[:openai][:api_key] = ENV["OPENAI_API_KEY"]

  # Enable summarization
  config.summarization_config[:enable] = true
  config.summarization_config[:max_length] = 300
end

# Initialize the database
Ragdoll::Core::Database.setup

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

# Create a document and generate summary and keywords
puts "\n1. Creating document with text content..."
document = Ragdoll::Core::Models::Document.create!(
  location: "machine_learning_intro.txt",
  title: "Introduction to Machine Learning",
  document_type: "text",
  status: "pending",
  file_modified_at: Time.current
)

# Set the content which will create a text_content record
document.content = ml_content
document.save!

puts "Document ID: #{document.id}"
puts "Content length: #{document.total_character_count} characters"

# Generate metadata including summary and keywords
puts "\n2. Generating summary and keywords..."
begin
  document.generate_metadata!
  document.reload

  puts "Summary generated: #{document.metadata['summary'].present?}"
  puts "Keywords generated: #{document.metadata['keywords'].present?}"
rescue StandardError => e
  puts "Note: Metadata generation requires LLM configuration: #{e.message}"

  # Manually set example metadata for demonstration
  document.update!(
    metadata: {
      summary: "Machine learning is a data analysis method that automates model building through AI, enabling systems to learn from data and make decisions with minimal human intervention.",
      keywords: "machine learning, artificial intelligence, data analysis, algorithms, training data, predictions, automation, computer vision, recommendation systems",
      classification: "educational",
      tags: ["AI", "technology", "data science"]
    }
  )
end

puts "\n3. Generated Summary:"
puts document.metadata['summary']

puts "\n4. Extracted Keywords:"
puts document.metadata['keywords']

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

document2 = Ragdoll::Core::Models::Document.create!(
  location: "ai_overview.txt",
  title: "Artificial Intelligence Overview",
  document_type: "text",
  status: "pending",
  file_modified_at: Time.current
)

document2.content = ai_content
document2.save!

# Manually set metadata for second document
document2.update!(
  metadata: {
    summary: "Artificial intelligence simulates human intelligence in machines for learning and problem-solving, with successful applications in game playing, medical diagnosis, and various AI research areas.",
    keywords: "artificial intelligence, AI, neural networks, deep learning, natural language processing, computer vision, machine learning, medical diagnosis",
    classification: "technical",
    tags: ["AI", "technology", "research"]
  }
)

puts "Second Document - AI Overview:"
puts "Summary: #{document2.metadata['summary']}"
puts "Keywords: #{document2.metadata['keywords']}"

# Demonstrate keyword management (note: keywords now stored in metadata)
puts "\n6. Keyword Management:"
current_keywords = document.metadata['keywords']&.split(',')&.map(&:strip) || []
puts "Current keywords: #{current_keywords}"

# Add new keywords to metadata
new_keywords = current_keywords + ["supervised learning", "unsupervised learning"]
document.update!(
  metadata: document.metadata.merge('keywords' => new_keywords.uniq.join(', '))
)
puts "After adding keywords: #{document.metadata['keywords']}"

# Demonstrate faceted search
puts "\n7. Faceted Search Capabilities:"
all_keywords = Ragdoll::Core::Models::Document.all_keywords
puts "All available keywords: #{all_keywords.first(10).join(', ')}..."

keyword_frequencies = Ragdoll::Core::Models::Document.keyword_frequencies
puts "Top keyword frequencies:"
keyword_frequencies.first(5).each do |keyword, count|
  puts "  #{keyword}: #{count}"
end

# Search by keywords (searching in metadata)
puts "\n8. Search by Keywords:"
search_results = Ragdoll::Core::Models::Document.faceted_search(
  query: nil,
  keywords: %w[learning intelligence]
)
puts "Documents with 'learning' and 'intelligence' keywords: #{search_results.count}"

# Full-text search on metadata fields (summary and keywords)
puts "\n9. Full-text Search (on metadata fields):"
search_results = Ragdoll::Core::Models::Document.search_content("machine learning")
puts "Search results for 'machine learning': #{search_results.count}"

# Combined search
puts "\n10. Combined Faceted Search:"
combined_results = Ragdoll::Core::Models::Document.faceted_search(
  query: "artificial",
  keywords: ["intelligence"],
  limit: 10
)
puts "Combined search results: #{combined_results.count}"
combined_results.each do |doc|
  metadata_keywords = doc.metadata['keywords']&.split(',')&.map(&:strip) || []
  puts "  - #{doc.title} (#{metadata_keywords.length} keywords)"
end

# Document hash representation
puts "\n11. Document Hash with Metadata:"
hash = document.to_hash
puts "Hash keys: #{hash.keys}"
puts "Metadata present: #{hash[:metadata].present?}"
puts "Summary in metadata: #{hash[:metadata]['summary'].present?}"
puts "Keywords in metadata: #{hash[:metadata]['keywords'].present?}"

# Show metadata structure
puts "\nMetadata structure:"
document.metadata.each do |key, value|
  if value.is_a?(String) && value.length > 50
    puts "  #{key}: #{value[0..50]}..."
  else
    puts "  #{key}: #{value}"
  end
end

puts "\n=== Summary and Keywords Integration Complete ==="
puts "\nKey changes in current architecture:"
puts "1. Summary and keywords are now stored in the metadata JSON column"
puts "2. Content is managed through STI content models (TextContent, etc.)"
puts "3. Metadata generation requires LLM configuration and generate_metadata! call"
puts "4. Search functionality uses PostgreSQL full-text search on metadata fields"
puts "5. Faceted search enables filtering by metadata keywords, classification, and tags"
