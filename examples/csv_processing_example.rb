#!/usr/bin/env ruby
# frozen_string_literal: true

# CSV processing example for unified text-based RAG system
# Demonstrates how CSV files are converted to searchable text

require_relative "../lib/ragdoll"
require "tempfile"

# Configure Ragdoll for unified text-based CSV processing
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

  # Unified content processing - CSV converted to searchable text
  config.use_unified_content = true
  config.embedding_model = "text-embedding-3-large"
  config.embedding_provider = :openai
end

puts "=== CSV to Text Processing Example ==="

# Create sample CSV data
csv_content = <<~CSV
  name,age,city,profession
  John Smith,30,New York,Software Engineer
  Jane Doe,25,San Francisco,Data Scientist
  Bob Johnson,35,Chicago,Product Manager
  Alice Wilson,28,Seattle,UX Designer
  Charlie Brown,42,Austin,DevOps Engineer
CSV

# Create temporary CSV file
csv_file = Tempfile.new(["employee_data", ".csv"])
csv_file.write(csv_content)
csv_file.rewind

begin
  puts "\n🔄 Processing CSV through unified text conversion..."
  puts "Original CSV content:"
  puts csv_content

  # Process CSV file through unified RAG system
  result = Ragdoll.add_document(path: csv_file.path)

  if result[:success]
    puts "\n✅ CSV successfully converted to searchable text!"
    puts "Document ID: #{result[:document_id]}"
    puts "Original format: CSV → unified text content"
    puts "Content length: #{result[:content_length]} characters"
    puts "Quality score: #{result[:content_quality_score]&.round(2)}" if result[:content_quality_score]

    # Get the converted text content
    doc = Ragdoll.get_document(id: result[:document_id])
    if doc && doc[:content]
      puts "\n📝 Converted text representation:"
      puts "=" * 50
      puts doc[:content]
      puts "=" * 50

      puts "\n🔍 Testing search capabilities..."

      # Test searching for names
      search_results = Ragdoll.search(query: "John Smith", limit: 1)
      if search_results[:results].any?
        puts "✅ Found CSV data via name search: 'John Smith'"
        puts "   Similarity: #{search_results[:results].first[:similarity]&.round(3)}"
      end

      # Test searching for professions
      search_results = Ragdoll.search(query: "Software Engineer", limit: 1)
      if search_results[:results].any?
        puts "✅ Found CSV data via profession search: 'Software Engineer'"
        puts "   Similarity: #{search_results[:results].first[:similarity]&.round(3)}"
      end

      # Test searching for cities
      search_results = Ragdoll.search(query: "San Francisco", limit: 1)
      if search_results[:results].any?
        puts "✅ Found CSV data via city search: 'San Francisco'"
        puts "   Similarity: #{search_results[:results].first[:similarity]&.round(3)}"
      end

    end

    puts "\n💡 CSV Processing Benefits:"
    puts "✅ Structured data becomes text-searchable"
    puts "✅ Headers and values are preserved in readable format"
    puts "✅ Each row converted to key-value pairs"
    puts "✅ Searchable by any field content (names, cities, professions)"
    puts "✅ Unified embedding model processes all CSV content"

  else
    puts "\n❌ CSV processing failed: #{result[:error]}"
  end

rescue => e
  puts "\n❌ Error: #{e.message}"
ensure
  csv_file.close
  csv_file.unlink
end

puts "\n🎯 Text Conversion Process:"
puts "1. CSV file detected by file extension"
puts "2. Headers parsed from first row"
puts "3. Each data row converted to readable format:"
puts "   'name: John Smith, age: 30, city: New York, profession: Software Engineer'"
puts "4. All rows combined into unified text content"
puts "5. Text embedded using standard embedding model"
puts "6. CSV data now searchable alongside other content types"

puts "\n=== CSV Processing Complete ==="