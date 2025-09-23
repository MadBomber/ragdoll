#!/usr/bin/env ruby
# frozen_string_literal: true

# Example demonstrating unified content analysis and keyword extraction
# Shows how unified text conversion enables consistent analysis across all media types

require "bundler/setup"
require_relative "../lib/ragdoll"

# Configure Ragdoll for unified text-based content analysis
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

  # Unified content processing - all media types converted to text
  config.use_unified_content = true
  config.embedding_model = "text-embedding-3-large"
  config.embedding_provider = :openai

  # Content analysis settings for unified text content
  config.content_analysis = {
    enable_summarization: true,
    enable_keyword_extraction: true,
    summary_length: :medium,  # :short, :medium, :long
    keyword_count: 10,
    quality_scoring: true
  }

  # Text conversion settings for multi-modal content
  config.text_conversion = {
    image_detail_level: :comprehensive,
    audio_transcription_provider: :openai,
    enable_fallback_descriptions: true,
    min_content_length: 20,
    max_content_length: 50000
  }
end

puts "=== Unified Text-Based Content Analysis Example ==="

# Example content about machine learning for unified text analysis
ml_content = <<~TEXT
  Machine learning is a method of data analysis that automates analytical model building.#{' '}
  It is a branch of artificial intelligence based on the idea that systems can learn from data,#{' '}
  identify patterns and make decisions with minimal human intervention. Machine learning algorithms#{' '}
  build a model based on training data in order to make predictions or decisions without being#{' '}
  explicitly programmed to do so. Applications range from email filtering and computer vision#{' '}
  to recommendation systems and autonomous vehicles. The field has gained tremendous momentum#{' '}
  with the advent of big data, improved algorithms, and increased computational power. This#{' '}
  content demonstrates how the unified RAG system processes text for summary and keyword extraction.
TEXT

# Create documents using unified text-based API
puts "\n1. Creating text document for unified analysis..."

# Create a temporary text file
require "tempfile"
text_file = Tempfile.new(["machine_learning_intro", ".txt"])
text_file.write(ml_content)
text_file.rewind

begin
  # Add document using unified text-based API
  result = Ragdoll.add_document(path: text_file.path)

  if result[:success]
    doc_id = result[:document_id]
    puts "✅ Text document processed through unified pipeline"
    puts "Document ID: #{doc_id}"
    puts "Original media type: text → unified text content"
    puts "Content length: #{result[:content_length]} characters"
    puts "Title: #{result[:title]}"
    puts "Content quality score: #{result[:content_quality_score]&.round(2)}" if result[:content_quality_score]
  else
    puts "❌ Failed to add document: #{result[:error]}"
  end
ensure
  text_file.close
  text_file.unlink
end

# Check unified document processing status
puts "\n2. Checking unified document processing status..."
if doc_id
  status = Ragdoll.document_status(id: doc_id)
  puts "Document status: #{status[:status]}"
  puts "Unified embeddings ready: #{status[:embeddings_ready]}"
  puts "Text conversion method: #{status[:conversion_method] || 'direct_text'}"
  puts "Content quality score: #{status[:content_quality_score]&.round(2)}" if status[:content_quality_score]

  # Get document details to see unified content metadata
  doc_details = Ragdoll.get_document(id: doc_id)
  if doc_details && doc_details[:metadata]
    puts "\n3. Unified Content Analysis Results:"
    puts "Generated Summary:"
    puts doc_details[:metadata]['summary'] || "Summary not yet generated"

    puts "\n4. Extracted Keywords:"
    puts doc_details[:metadata]['keywords'] || "Keywords not yet generated"

    puts "\n5. Unified Content Metrics:"
    puts "Original media type: #{doc_details[:original_media_type] || 'text'}"
    puts "Text conversion quality: #{doc_details[:content_quality_score]&.round(2)}" if doc_details[:content_quality_score]
  else
    puts "\nNote: Unified content analysis (summary and keywords) happens during processing."
    puts "All content types go through the same text-based analysis pipeline."
  end
end

# Example 2: Create another document for unified analysis
puts "\n6. Creating second document for unified content analysis..."
ai_content = <<~TEXT
  Artificial intelligence (AI) refers to the simulation of human intelligence in machines#{' '}
  that are programmed to think like humans and mimic their actions. The term may also be#{' '}
  applied to any machine that exhibits traits associated with a human mind such as learning#{' '}
  and problem-solving. AI research has been highly successful in developing effective#{' '}
  techniques for solving a wide range of problems, from game playing to medical diagnosis.#{' '}
  Neural networks, deep learning, natural language processing, and computer vision are#{' '}
  key areas of AI research and development. This unified RAG system can analyze all content#{' '}
  types using the same text-based pipeline for consistent summary and keyword extraction.
TEXT

# Create second temporary text file
ai_file = Tempfile.new(["ai_overview", ".txt"])
ai_file.write(ai_content)
ai_file.rewind

begin
  # Add second document using unified text-based API
  result2 = Ragdoll.add_document(path: ai_file.path)

  if result2[:success]
    doc2_id = result2[:document_id]
    puts "✅ Second document processed through unified pipeline"
    puts "Document ID: #{doc2_id}"
    puts "Original media type: text → unified text content"
    puts "Title: #{result2[:title]}"
    puts "Content quality score: #{result2[:content_quality_score]&.round(2)}" if result2[:content_quality_score]

    # Get unified content analysis results
    doc2_details = Ragdoll.get_document(id: doc2_id)
    if doc2_details && doc2_details[:metadata]
      puts "Summary: #{doc2_details[:metadata]['summary'] || 'Summary generation in progress'}"
      puts "Keywords: #{doc2_details[:metadata]['keywords'] || 'Keyword extraction in progress'}"
      puts "Text conversion method: #{doc2_details[:conversion_method] || 'direct_text'}"
    end
  else
    puts "❌ Failed to add second document: #{result2[:error]}"
  end
ensure
  ai_file.close
  ai_file.unlink
end

# Demonstrate unified search functionality across all content types
puts "\n7. Unified search functionality..."

# Search across all unified text content
puts "Searching for 'machine learning' across unified content:"
begin
  search_results = Ragdoll.search(query: "machine learning", limit: 5)

  if search_results[:results].any?
    puts "Found #{search_results[:total_results]} unified content results:"
    search_results[:results].each_with_index do |result, index|
      puts "  #{index + 1}. #{result[:document_title]} (Score: #{result[:similarity]&.round(3)})"
      puts "     Original media: #{result[:original_media_type] || 'text'} → unified text"
      puts "     Content quality: #{result[:content_quality_score]&.round(2)}" if result[:content_quality_score]
    end
  else
    puts "No results found (unified embeddings may still be processing)"
  end
rescue => e
  puts "Search failed: #{e.message}"
end

puts "\nSearching for 'artificial intelligence' in unified content:"
begin
  search_results = Ragdoll.search(query: "artificial intelligence", limit: 5)

  if search_results[:results].any?
    puts "Found #{search_results[:total_results]} unified results:"
    search_results[:results].each_with_index do |result, index|
      puts "  #{index + 1}. #{result[:document_title]} (Score: #{result[:similarity]&.round(3)})"
      puts "     Conversion method: #{result[:conversion_method] || 'direct_text'}"
      puts "     Content preview: #{result[:content][0..80]}..." if result[:content]
    end
  else
    puts "No results found (unified processing may still be in progress)"
  end
rescue => e
  puts "Search failed: #{e.message}"
end

# List all unified documents
puts "\n8. Listing all unified documents:"
begin
  documents = Ragdoll.list_documents
  puts "Total unified documents: #{documents.count}"

  documents.each do |doc|
    puts "- #{doc[:title]} (ID: #{doc[:id]}, Status: #{doc[:status]})"
    puts "  Original media: #{doc[:original_media_type] || 'text'} → unified text"
    puts "  Conversion method: #{doc[:conversion_method] || 'direct_text'}"
    puts "  Content quality: #{doc[:content_quality_score]&.round(2)}" if doc[:content_quality_score]
  end
rescue => e
  puts "Failed to list documents: #{e.message}"
end

puts "\n=== Unified Text-Based Content Analysis Complete ==="
puts "\nKey unified features demonstrated:"
puts "1. ✅ Unified content analysis - all media types processed as text"
puts "2. ✅ Consistent summary and keyword extraction across content types"
puts "3. ✅ Single embedding pipeline for all unified text content"
puts "4. ✅ Cross-modal search with unified relevance scoring"
puts "5. ✅ Content quality assessment for text conversion effectiveness"
puts "6. ✅ Simplified architecture without STI complexity"

puts "\nUnified Text-Based RAG API methods:"
puts "- Ragdoll.configure        # Configure unified text-based system"
puts "- Ragdoll.add_document     # Add any media type (auto-converted to text)"
puts "- Ragdoll.document_status  # Check unified processing status"
puts "- Ragdoll.get_document     # Retrieve unified content details"
puts "- Ragdoll.search           # Unified search across all content types"
puts "- Ragdoll.list_documents   # List all unified documents"

puts "\nUnified system benefits:"
puts "✅ All content types searchable through text conversion"
puts "✅ Single content model eliminates database complexity"
puts "✅ Consistent analysis pipeline for summary/keyword extraction"
puts "✅ Cross-modal discovery (find images via descriptions, audio via transcripts)"
puts "✅ Quality scoring helps assess conversion effectiveness"

puts "\nText conversion capabilities:"
puts "📄 Text files → Direct extraction (PDF, DOCX, MD, HTML, TXT)"
puts "🖼️  Images → AI-generated comprehensive descriptions"
puts "🎵 Audio → Speech-to-text transcription (multi-language)"
puts "🎬 Video → Combined audio transcription + visual frame descriptions"

puts "\nNote: Unified content analysis requires:"
puts "- LLM configuration (OPENAI_API_KEY environment variable)"
puts "- PostgreSQL with pgvector extension"
puts "- Text conversion happens asynchronously for all media types"
