#!/usr/bin/env ruby
# search.rb
#
# Load the Ragdoll system
require "bundler/setup"
require_relative "../lib/ragdoll"

# Initialize a client
client = Ragdoll.client

# Create some test data first
puts "Creating test document..."
doc_result = client.add_text(
  content: "Machine learning is a subset of artificial intelligence that focuses on algorithms and statistical models. Deep
learning uses neural networks with multiple layers to process data. Natural language processing helps computers understand
human language.",
  title: "AI and ML Overview",
  metadata: { category: "technology", author: "test_user" }
)

puts "Document created with ID: #{doc_result}"

# Wait a moment for processing
puts "Waiting for document processing..."
sleep(2)

# Now test different types of searches with tracking
puts "\n=== Testing Search Tracking ==="

# 1. Basic semantic search (automatically tracked)
puts "\n1. Basic semantic search:"
result1 = client.search(
  query: "what is machine learning?",
  limit: 3
)
puts "Results: #{result1[:total_results]} found"
puts "Query: #{result1[:query]}"

# 2. Search with session and user tracking
puts "\n2. Search with session/user tracking:"
result2 = client.search(
  query: "neural networks deep learning",
  limit: 5,
  session_id: "test_session_123",
  user_id: "test_user_456"
)
puts "Results: #{result2[:total_results]} found"

# 3. Hybrid search (also tracked)
puts "\n3. Hybrid search:"
result3 = client.hybrid_search(
  query: "artificial intelligence algorithms",
  session_id: "hybrid_session_789",
  user_id: "test_user_456"
)
puts "Hybrid results: #{result3[:total_results]} found"
puts "Search type: #{result3[:search_type]}"

# 4. Search with tracking disabled
puts "\n4. Search with tracking disabled:"
result4 = client.search(
  query: "this search won't be tracked",
  track_search: false
)
puts "Results: #{result4[:total_results]} found (not tracked)"

# Check what searches were tracked
puts "\n=== Checking Tracked Searches ==="
tracked_searches = Ragdoll::Search.all
puts "Total searches tracked: #{tracked_searches.count}"

tracked_searches.each_with_index do |search, index|
  puts "\nSearch #{index + 1}:"
  puts "  Query: #{search.query}"
  puts "  Type: #{search.search_type}"
  puts "  Results: #{search.results_count}"
  puts "  Execution time: #{search.execution_time_ms}ms"
  puts "  Session: #{search.session_id || 'none'}"
  puts "  User: #{search.user_id || 'none'}"
  puts "  Created: #{search.created_at}"
end

# Check search analytics
puts "\n=== Search Analytics ==="
analytics = Ragdoll::Search.search_analytics(days: 1)
puts "Analytics for today:"
puts "  Total searches: #{analytics[:total_searches]}"
puts "  Unique queries: #{analytics[:unique_queries]}"
puts "  Avg results per search: #{analytics[:avg_results_per_search]}"
puts "  Avg execution time: #{analytics[:avg_execution_time]}ms"
puts "  Search types: #{analytics[:search_types]}"

# Test similar search functionality
if tracked_searches.any?
  puts "\n=== Finding Similar Searches ==="
  first_search = tracked_searches.first
  similar = Ragdoll::Search.find_similar(first_search.query_embedding, limit: 3, threshold: 0.5)
  puts "Found #{similar.count} similar searches to: '#{first_search.query}'"
  similar.each do |sim_search|
    puts "  - '#{sim_search.query}' (similarity: #{sim_search.similarity_score.round(3)})"
  end
end

puts "\n=== Manual Testing Complete ==="
puts "You can now run additional searches and check Ragdoll::Search.count to see tracking in action!"
