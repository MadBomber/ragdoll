#!/usr/bin/env ruby
# search.rb - Advanced search examples for unified text-based RAG system
#
require "bundler/setup"
require_relative "../lib/ragdoll"
require "tempfile"

# Configure unified text-based RAG system
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
end

puts "=== Unified RAG Search Examples ==="

# Create test documents with various media types (all converted to text)
puts "\nCreating diverse test content..."

# Text document
text_file = Tempfile.new(["ai_ml_tech", ".txt"])
text_file.write("Machine learning and artificial intelligence represent the cutting edge of computer science. Deep learning neural networks process vast amounts of data to identify patterns. Natural language processing enables computers to understand and generate human language. These technologies are revolutionizing industries from healthcare to autonomous vehicles.")
text_file.rewind

text_result = Ragdoll.add_document(path: text_file.path)

puts "✅ Text document added: #{text_result[:document_id]}" if text_result[:success]

# Add more diverse content to demonstrate unified search
markdown_file = Tempfile.new(["data_science_guide", ".md"])
markdown_file.write("# Data Science Fundamentals\n\nData science combines statistics, programming, and domain expertise. Key components include data collection, cleaning, analysis, and visualization. Python and R are popular languages for data analysis. Machine learning algorithms help extract insights from large datasets.")
markdown_file.rewind

markdown_result = Ragdoll.add_document(path: markdown_file.path)

puts "✅ Markdown document added: #{markdown_result[:document_id]}" if markdown_result[:success]

# Wait for processing and embedding generation
puts "\nWaiting for unified text processing and embedding generation..."
sleep(3)

# Now test unified search capabilities
puts "\n=== Unified Text-Based Search Examples ==="

# 1. Basic semantic search across all content types
puts "\n1. Basic unified search:"
result1 = Ragdoll.search(
  query: "what is machine learning?",
  limit: 5
)

if result1[:results].any?
  puts "Found #{result1[:results].count} results:"
  result1[:results].each_with_index do |result, index|
    puts "  #{index + 1}. #{result[:document_title]}"
    puts "     Original type: #{result[:original_media_type] || 'text'} → unified text"
    puts "     Similarity: #{result[:similarity]&.round(3)}"
    puts "     Preview: #{result[:content][0..80]}..."
  end
else
  puts "No results found (may need more processing time)"
end

# 2. Cross-modal search (find any content type via text)
puts "\n2. Cross-modal unified search:"
result2 = Ragdoll.search(
  query: "data analysis and statistics",
  limit: 3,
  include_metadata: true
)

if result2[:results].any?
  puts "Found #{result2[:results].count} cross-modal results:"
  result2[:results].each_with_index do |result, index|
    puts "  #{index + 1}. #{result[:document_title]}"
    puts "     Content type: #{result[:document_type]}"
    puts "     Conversion quality: #{result[:content_quality_score]&.round(2)}"
    puts "     Similarity: #{result[:similarity]&.round(3)}"
  end
end

# 3. Quality-filtered search
puts "\n3. Quality-filtered search:"
result3 = Ragdoll.search(
  query: "neural networks and deep learning",
  limit: 5,
  quality_threshold: 0.5
)

puts "High-quality results: #{result3[:results]&.count || 0}"
result3[:results]&.each_with_index do |result, index|
  puts "  #{index + 1}. #{result[:document_title]} (Quality: #{result[:content_quality_score]&.round(2)})"
end

# 4. Enhanced search with context for RAG
puts "\n4. Enhanced search for RAG context:"
enhanced_result = Ragdoll.enhance_prompt(
  prompt: "Explain the relationship between machine learning and data science",
  context_limit: 3
)

if enhanced_result[:enhanced_prompt]
  puts "Enhanced prompt generated with context:"
  puts enhanced_result[:enhanced_prompt][0..200] + "..."
  puts "\nContext sources: #{enhanced_result[:context_sources]&.count || 0}"
  enhanced_result[:context_sources]&.each do |source|
    puts "  - #{source[:title]} (#{source[:original_media_type] || 'text'})"
  end
end

# 5. System analytics and search statistics
puts "\n=== Unified Search System Analytics ==="

begin
  stats = Ragdoll.stats

  puts "📊 Search System Statistics:"
  puts "  - Total documents: #{stats[:total_documents]}"
  puts "  - Unified content entries: #{stats[:total_unified_contents]}" if stats[:total_unified_contents]
  puts "  - Total embeddings: #{stats[:total_embeddings]}" if stats[:total_embeddings]

  if stats[:by_original_media_type]
    puts "\n🎭 Content by Original Media Type (all searchable as text):"
    stats[:by_original_media_type].each do |type, count|
      puts "  - #{type.capitalize}: #{count} documents"
    end
  end

  if stats[:content_quality_distribution]
    puts "\n📈 Text Conversion Quality:"
    quality = stats[:content_quality_distribution]
    puts "  - High quality: #{quality[:high]} documents"
    puts "  - Medium quality: #{quality[:medium]} documents"
    puts "  - Low quality: #{quality[:low]} documents"
  end

rescue StandardError => e
  puts "Analytics unavailable: #{e.message}"
end

# Check search tracking (if available)
begin
  puts "\n=== Search Tracking ==="
  if defined?(Ragdoll::Search)
    searches = Ragdoll::Search.recent(limit: 5)
    puts "Recent searches tracked: #{searches.count}"

    searches.each_with_index do |search, index|
      puts "  #{index + 1}. '#{search.query}' → #{search.results_count} results"
    end
  else
    puts "Search tracking not enabled in current configuration"
  end
rescue StandardError => e
  puts "Search tracking not available: #{e.message}"
end

puts "\n=== Unified Search Examples Complete ==="
puts "\n🎯 Key Features Demonstrated:"
puts "✅ Unified search across all media types through text conversion"
puts "✅ Cross-modal discovery (find any content via text queries)"
puts "✅ Quality-based filtering for better results"
puts "✅ Enhanced prompts with context for RAG applications"
puts "✅ System analytics and performance monitoring"

puts "\n💡 Advanced Search Capabilities:"
puts "• Single embedding space for all content types"
puts "• Consistent relevance scoring across media formats"
puts "• Content quality assessment and filtering"
puts "• Context-aware search for enhanced generation"
puts "• Comprehensive analytics and monitoring"

puts "\n🚀 Try these additional searches:"
puts "- Search for specific topics across all your content"
puts "- Use quality thresholds to filter low-quality conversions"
puts "- Generate enhanced prompts with relevant context"
puts "- Monitor search patterns and system performance"

# Cleanup temporary files
text_file.close
text_file.unlink
markdown_file.close
markdown_file.unlink
