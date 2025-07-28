# Testing Guide

## Running Tests and Coverage Analysis

Ragdoll uses **Minitest** as its primary testing framework with comprehensive coverage analysis via SimpleCov. All tests require PostgreSQL with pgvector extension and focus on real database integration rather than mocking.

### Quick Test Commands

```bash
# Run all tests
bundle exec rake test

# Run specific test file
bundle exec rake test test/core/client_test.rb

# Run with coverage report
RAILS_ENV=test bundle exec rake test
open coverage/index.html

# Run tests with verbose output
bundle exec rake test TESTOPTS="-v"

# Run specific test method
bundle exec rake test TESTOPTS="--name test_method_name"
```

## Test Framework

### Minitest Configuration

Ragdoll uses Minitest with custom reporting and database management:

```ruby
# test/test_helper.rb highlights
require "simplecov"
require "minitest/autorun"
require "minitest/reporters"

# Custom reporter for better test output
class CompactTestReporter < Minitest::Reporters::BaseReporter
  def record(result)
    status = case result.result_code
             when "." then "\e[32mPASS\e[0m"
             when "F" then "\e[31mFAIL\e[0m"
             when "E" then "\e[31mERROR\e[0m"
             when "S" then "\e[33mSKIP\e[0m"
             end
    
    time_str = result.time >= 1.0 ? 
      "\e[31m(#{result.time.round(2)}s)\e[0m" : 
      "(#{result.time.round(3)}s)"
    
    puts "#{result.klass}##{result.name} ... #{status} #{time_str}"
  end
end
```

### Test Database Configuration

Each test gets a clean PostgreSQL database state:

```ruby
module Minitest
  class Test
    def setup
      Ragdoll::Core.reset_configuration!
      
      # Setup PostgreSQL test database
      Ragdoll::Core::Database.setup({
        adapter: "postgresql",
        database: "ragdoll_test",
        username: ENV["POSTGRES_USER"] || "postgres",
        password: ENV["POSTGRES_PASSWORD"] || "",
        host: ENV["POSTGRES_HOST"] || "localhost",
        port: ENV["POSTGRES_PORT"] || 5432,
        auto_migrate: true,
        logger: nil
      })
    end
    
    def teardown
      # Clean database in foreign key order
      %w[ragdoll_embeddings ragdoll_contents ragdoll_documents].each do |table|
        ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
      end
      
      Ragdoll::Core.reset_configuration!
    end
  end
end
```

### Custom Test Helpers

```ruby
# Custom assertions for Ragdoll-specific testing
module RagdollTestHelpers
  def assert_embedding_generated(text)
    service = Ragdoll::Core::EmbeddingService.new
    embedding = service.generate_embedding(text)
    assert embedding.is_a?(Array), "Expected array, got #{embedding.class}"
    assert embedding.length > 0, "Expected non-empty embedding"
    assert embedding.all?(Numeric), "All embedding values must be numeric"
  end
  
  def assert_document_processed(document_id)
    document = Ragdoll::Core::Models::Document.find(document_id)
    assert_equal 'processed', document.status
    assert document.content.present?
    refute_empty document.all_embeddings
  end
  
  def assert_search_results_valid(results)
    assert_instance_of Array, results
    results.each do |result|
      assert result.key?(:similarity)
      assert result.key?(:content)
      assert result.key?(:document_id)
      assert result[:similarity].between?(0.0, 1.0)
    end
  end
  
  def create_test_document(content: "Test content", title: "Test Document")
    doc_id = Ragdoll::Core::DocumentManagement.add_document(
      "test://#{title}", content, { title: title }
    )
    
    # Process immediately for tests (no background jobs)
    document = Ragdoll::Core::Models::Document.find(doc_id)
    document.update!(status: 'processed')
    doc_id
  end
end

# Include helpers in all tests
Minitest::Test.include(RagdollTestHelpers)
```

## Test Categories

### Unit Tests

Unit tests focus on individual classes and methods:

```ruby
# test/core/embedding_service_test.rb
class EmbeddingServiceTest < Minitest::Test
  def setup
    super
    @service = Ragdoll::Core::EmbeddingService.new
  end
  
  def test_generates_embedding_for_text
    # Mock LLM API to avoid external dependencies
    mock_client = Minitest::Mock.new
    mock_client.expect(:embed, 
      { "embeddings" => [Array.new(1536) { rand }] },
      [Hash]
    )
    
    service = Ragdoll::Core::EmbeddingService.new(client: mock_client)
    embedding = service.generate_embedding("test text")
    
    assert_instance_of Array, embedding
    assert_equal 1536, embedding.length
    assert embedding.all?(Numeric)
    
    mock_client.verify
  end
  
  def test_handles_empty_text
    embedding = @service.generate_embedding("")
    assert_nil embedding
  end
  
  def test_handles_very_long_text
    long_text = "word " * 10_000
    embedding = @service.generate_embedding(long_text)
    
    # Should truncate and still generate embedding
    assert_instance_of Array, embedding
  end
end
```

```ruby
# test/core/models/document_test.rb
class DocumentTest < Minitest::Test
  def test_creates_document_with_required_fields
    document = Ragdoll::Core::Models::Document.create!(
      location: "/test/path.txt",
      title: "Test Document",
      document_type: "text",
      status: "pending",
      file_modified_at: Time.current
    )
    
    assert document.persisted?
    assert_equal "text", document.document_type
    assert_equal "pending", document.status
  end
  
  def test_validates_required_fields
    document = Ragdoll::Core::Models::Document.new
    
    refute document.valid?
    assert document.errors[:location].present?
    assert document.errors[:title].present?
  end
  
  def test_normalizes_file_paths
    document = Ragdoll::Core::Models::Document.create!(
      location: "relative/path.txt",
      title: "Test",
      document_type: "text",
      status: "pending",
      file_modified_at: Time.current
    )
    
    # Should convert to absolute path
    assert document.location.start_with?("/")
    assert document.location.include?("relative/path.txt")
  end
end
```

### Integration Tests

Integration tests verify component interactions:

```ruby
# test/core/client_integration_test.rb
class ClientIntegrationTest < Minitest::Test
  def setup
    super
    @client = Ragdoll::Core.client
  end
  
  def test_complete_document_workflow
    # Create temporary test file
    Tempfile.create(['test', '.txt']) do |file|
      file.write("This is test content about machine learning algorithms.")
      file.rewind
      
      # Add document
      result = @client.add_document(path: file.path)
      assert result[:success]
      
      document_id = result[:document_id]
      assert document_id.present?
      
      # Verify document was created
      document = Ragdoll::Core::Models::Document.find(document_id)
      assert_equal "text", document.document_type
      
      # Simulate background job processing
      document.generate_embeddings_for_all_content!
      
      # Verify embeddings were created
      assert document.all_embeddings.any?
      
      # Test search functionality
      search_results = @client.search(query: "machine learning")
      assert search_results[:results].any?
      
      # Verify search result structure
      result = search_results[:results].first
      assert result[:document_id] == document_id
      assert result[:similarity] > 0.5
    end
  end
  
  def test_document_management_operations
    # Add document
    doc_id = create_test_document(
      content: "Integration test content",
      title: "Integration Test Doc"
    )
    
    # Test retrieval
    document = @client.get_document(id: doc_id)
    assert_equal "Integration Test Doc", document[:title]
    assert_equal "Integration test content", document[:content]
    
    # Test update
    updated = @client.update_document(
      id: doc_id,
      metadata: { category: "test" }
    )
    assert_equal "test", updated[:metadata]["category"]
    
    # Test deletion
    assert @client.delete_document(id: doc_id)
    assert_nil @client.get_document(id: doc_id)
  end
end
```

### System Tests

System tests verify end-to-end workflows:

```ruby
# test/system/rag_workflow_test.rb
class RAGWorkflowTest < Minitest::Test
  def test_complete_rag_system
    client = Ragdoll::Core.client
    
    # Add multiple documents
    documents = [
      { content: "Ruby is a programming language", title: "Ruby Intro" },
      { content: "Python is used for data science", title: "Python Guide" },
      { content: "JavaScript runs in browsers", title: "JS Basics" }
    ]
    
    doc_ids = documents.map do |doc|
      create_test_document(content: doc[:content], title: doc[:title])
    end
    
    # Process all documents
    doc_ids.each do |doc_id|
      document = Ragdoll::Core::Models::Document.find(doc_id)
      document.generate_embeddings_for_all_content!
    end
    
    # Test semantic search
    results = client.search(query: "programming languages")
    assert results[:results].length >= 2
    
    # Results should be ordered by relevance
    first_result = results[:results].first
    assert first_result[:similarity] > 0.3
    
    # Test context enhancement
    enhanced = client.enhance_prompt(
      prompt: "What programming languages are mentioned?",
      context_limit: 3
    )
    
    assert enhanced[:context_count] > 0
    assert enhanced[:enhanced_prompt].include?("programming")
    assert enhanced[:context_sources].any?
  end
end
```

## Test Execution

### Running Specific Tests

```bash
# Run all tests in a directory
bundle exec rake test test/core/

# Run specific test class
bundle exec rake test test/core/client_test.rb

# Run specific test method
bundle exec rake test TESTOPTS="--name test_specific_method"

# Run tests matching pattern
bundle exec rake test TESTOPTS="--name /embedding/"

# Run with seed for reproducible randomization
bundle exec rake test TESTOPTS="--seed 12345"
```

### Test Configuration

#### Environment Variables

```bash
# Database configuration
export POSTGRES_USER=ragdoll_test
export POSTGRES_PASSWORD=test_password
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432

# Test-specific settings
export RAGDOLL_LOG_LEVEL=error
export COVERAGE_UNDERCOVER=true

# LLM API keys for integration tests
export OPENAI_API_KEY=test_key
export ANTHROPIC_API_KEY=test_key
```

#### Mock Service Setup

```ruby
# test/support/mock_services.rb
class MockLLMClient
  def embed(input:, model:)
    # Return consistent mock embeddings
    embeddings = Array.new(input.is_a?(Array) ? input.length : 1) do
      Array.new(1536) { rand(-1.0..1.0) }
    end
    
    { "embeddings" => embeddings }
  end
  
  def chat(model:, messages:, **options)
    # Return mock chat completion
    {
      "choices" => [{
        "message" => {
          "content" => "This is a mock response to: #{messages.last[:content][0..50]}..."
        }
      }]
    }
  end
end

# Use in tests
class ServiceTest < Minitest::Test
  def setup
    super
    @mock_client = MockLLMClient.new
    @service = Ragdoll::Core::EmbeddingService.new(client: @mock_client)
  end
end
```

## Coverage Analysis

### SimpleCov Configuration

```ruby
# test/test_helper.rb - SimpleCov setup
SimpleCov.start do
  add_filter "/test/"
  track_files "lib/**/*.rb"
  
  # Coverage groups for better reporting
  add_group "Core", "lib/ragdoll/core"
  add_group "Models", "lib/ragdoll/core/models"
  add_group "Services", "lib/ragdoll/core/services"
  add_group "Jobs", "lib/ragdoll/core/jobs"
  
  # Coverage thresholds
  minimum_coverage 85
  minimum_coverage_by_file 70
  
  # Exclude version file and generated files
  add_filter "version.rb"
  add_filter "migrate/"
end
```

### Coverage Metrics and Reporting

```bash
# Generate coverage report
bundle exec rake test

# View HTML coverage report
open coverage/index.html

# Check coverage percentage
grep -A 5 "covered at" coverage/index.html

# Coverage by file type
grep "LOC:" coverage/.resultset.json
```

### Coverage Analysis Tools

```ruby
# Custom coverage analysis
class CoverageAnalyzer
  def self.analyze_uncovered_lines
    if defined?(SimpleCov)
      SimpleCov.result.files.each do |file|
        uncovered = file.missed_lines
        if uncovered.any?
          puts "#{file.filename}: #{uncovered.length} uncovered lines"
          uncovered.first(5).each do |line_num|
            puts "  Line #{line_num}: #{file.src[line_num - 1].strip}"
          end
        end
      end
    end
  end
end

# Run after tests
CoverageAnalyzer.analyze_uncovered_lines
```

## Mocking and Stubbing

### External Service Mocking

#### LLM Provider Mocking

```ruby
# Mock OpenAI API responses
class MockOpenAIService
  def initialize(responses = {})
    @responses = responses
    @call_count = Hash.new(0)
  end
  
  def embed(input:, model:)
    @call_count[:embed] += 1
    
    if @responses[:embed_error]
      raise StandardError, @responses[:embed_error]
    end
    
    # Return mock embedding
    {
      "embeddings" => [Array.new(1536) { rand(-1.0..1.0) }]
    }
  end
  
  def call_count(method)
    @call_count[method]
  end
end

# Use in tests
def test_handles_api_failures
  mock_service = MockOpenAIService.new(embed_error: "Rate limit exceeded")
  service = Ragdoll::Core::EmbeddingService.new(client: mock_service)
  
  assert_raises(Ragdoll::Core::EmbeddingError) do
    service.generate_embedding("test text")
  end
  
  assert_equal 1, mock_service.call_count(:embed)
end
```

#### Database Mocking (Advanced)

```ruby
# Mock specific database operations
class DatabaseMockTest < Minitest::Test
  def test_handles_database_connection_failure
    # Temporarily break database connection
    original_connection = ActiveRecord::Base.connection
    
    ActiveRecord::Base.stub(:connection, nil) do
      client = Ragdoll::Core.client
      
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        client.add_document(path: "test.txt")
      end
    end
  end
end
```

### Test Doubles and Stubs

```ruby
# Minitest stub examples
def test_file_processing_with_stub
  # Stub File.read to return controlled content
  File.stub(:read, "mocked file content") do
    result = Ragdoll::Core::DocumentProcessor.parse("any_path.txt")
    assert_equal "mocked file content", result[:content]
  end
end

# Class method stubbing
def test_with_time_stub
  fixed_time = Time.parse("2024-01-01 00:00:00 UTC")
  
  Time.stub(:current, fixed_time) do
    document = create_test_document
    doc = Ragdoll::Core::Models::Document.find(document)
    assert_equal fixed_time.to_i, doc.created_at.to_i
  end
end
```

## Performance Testing

### Benchmark Tests

```ruby
# test/performance/embedding_benchmark_test.rb
require 'benchmark'

class EmbeddingBenchmarkTest < Minitest::Test
  def test_embedding_generation_performance
    service = Ragdoll::Core::EmbeddingService.new
    texts = Array.new(100) { "Sample text #{rand(1000)}" }
    
    time = Benchmark.measure do
      service.generate_embeddings_batch(texts)
    end
    
    # Should process 100 embeddings in under 30 seconds
    assert time.real < 30, "Batch embedding too slow: #{time.real}s"
    
    puts "Processed #{texts.length} embeddings in #{time.real.round(2)}s"
    puts "Average: #{(time.real / texts.length * 1000).round(2)}ms per embedding"
  end
  
  def test_search_performance
    # Create test dataset
    10.times do |i|
      create_test_document(
        content: "Test document #{i} with unique content about topic #{i}",
        title: "Doc #{i}"
      )
    end
    
    client = Ragdoll::Core.client
    
    # Benchmark search performance
    time = Benchmark.measure do
      100.times do
        client.search(query: "test content")
      end
    end
    
    avg_time = time.real / 100
    assert avg_time < 0.5, "Search too slow: #{avg_time}s per query"
    
    puts "Average search time: #{(avg_time * 1000).round(2)}ms"
  end
end
```

### Memory Usage Testing

```ruby
# test/performance/memory_test.rb
class MemoryTest < Minitest::Test
  def test_memory_usage_during_processing
    start_memory = get_memory_usage
    
    # Process multiple large documents
    10.times do |i|
      large_content = "Large content " * 10_000
      create_test_document(
        content: large_content,
        title: "Large Doc #{i}"
      )
    end
    
    end_memory = get_memory_usage
    memory_increase = end_memory - start_memory
    
    # Should not use more than 500MB
    assert memory_increase < 500, "Memory usage too high: #{memory_increase}MB"
    
    puts "Memory usage increased by #{memory_increase}MB"
  end
  
  private
  
  def get_memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0  # Convert to MB
  end
end
```

## Continuous Integration

### GitHub Actions Configuration

```yaml
# .github/workflows/test.yml
name: Test Suite

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: pgvector/pgvector:pg14
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: ragdoll_test
        options: >
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    
    strategy:
      matrix:
        ruby-version: ['3.0', '3.1', '3.2']
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: ${{ matrix.ruby-version }}
        bundler-cache: true
    
    - name: Set up database
      env:
        POSTGRES_USER: postgres
        POSTGRES_PASSWORD: postgres
        POSTGRES_HOST: localhost
        POSTGRES_PORT: 5432
      run: |
        sudo apt-get update
        sudo apt-get install -y postgresql-client
        createdb -h localhost -U postgres ragdoll_test
        psql -h localhost -U postgres -d ragdoll_test -c "CREATE EXTENSION IF NOT EXISTS vector;"
    
    - name: Run tests
      env:
        POSTGRES_USER: postgres
        POSTGRES_PASSWORD: postgres
        POSTGRES_HOST: localhost
        POSTGRES_PORT: 5432
      run: bundle exec rake test
    
    - name: Upload coverage reports
      uses: codecov/codecov-action@v3
      with:
        files: ./coverage/.resultset.json
        flags: unittests
        name: codecov-umbrella
```

### CI-Specific Test Configuration

```ruby
# test/support/ci_configuration.rb
module CIConfiguration
  def self.setup
    if ENV['CI']
      # CI-specific settings
      Ragdoll::Core.configure do |config|
        config.logging_config[:level] = :error
        config.embedding_config[:cache_embeddings] = false
      end
      
      # Use faster, less accurate models for CI
      ENV['OPENAI_API_KEY'] = 'test_key_for_ci'
    end
  end
end

# Include in test_helper.rb
CIConfiguration.setup if ENV['CI']
```

## Testing Best Practices

### Test Organization

```
test/
├── test_helper.rb         # Global test setup
├── support/               # Test utilities
│   ├── mock_services.rb
│   ┗── test_helpers.rb
├── core/                  # Unit tests
│   ├── client_test.rb
│   ├── models/
│   └── services/
├── integration/           # Integration tests
│   ┗── workflow_test.rb
├── performance/           # Performance tests
│   ┗── benchmark_test.rb
├── system/                # End-to-end tests
│   ┗── rag_system_test.rb
└── fixtures/              # Test data
    ├── sample.pdf
    ├── test_image.png
    └── documents/
```

### Test Naming Conventions

```ruby
# Test class naming: [ClassName]Test
class DocumentProcessorTest < Minitest::Test
  # Test method naming: test_[action]_[condition]_[expected_result]
  def test_parse_pdf_with_valid_file_returns_content
    # Test implementation
  end
  
  def test_parse_pdf_with_corrupted_file_raises_error
    # Test implementation
  end
  
  def test_parse_pdf_with_empty_file_returns_empty_content
    # Test implementation
  end
end
```

### Quality Assurance

#### Test Coverage Goals

- **Overall Coverage**: ≥ 85%
- **Critical Paths**: ≥ 95% (search, embedding, document processing)
- **New Code**: 100% (enforced in CI)
- **Integration Points**: ≥ 90%

#### Code Quality in Tests

```ruby
# Good test structure
class WellStructuredTest < Minitest::Test
  def test_descriptive_name_following_convention
    # Arrange - Set up test data
    document = create_test_document(content: "test content")
    client = Ragdoll::Core.client
    
    # Act - Perform the action being tested
    result = client.search(query: "test")
    
    # Assert - Verify the expected outcome
    assert result[:results].any?
    assert_search_results_valid(result[:results])
    
    # Cleanup (if needed beyond teardown)
    # Usually handled by teardown method
  end
end
```

### Test Debugging

```ruby
# Debug failing tests
class DebugTest < Minitest::Test
  def test_with_debugging
    # Use pry for interactive debugging
    require 'pry'; binding.pry if ENV['DEBUG']
    
    # Add detailed logging
    puts "Starting test with data: #{@test_data.inspect}" if ENV['VERBOSE']
    
    # Your test code here
  end
end
```

```bash
# Run tests with debugging
DEBUG=true VERBOSE=true bundle exec rake test TESTOPTS="--name test_specific_method"
```

## Test Checklist

### Before Committing

- [ ] All tests pass locally
- [ ] Coverage is ≥ 85%
- [ ] New code has 100% test coverage
- [ ] Tests follow naming conventions
- [ ] No hardcoded values or paths
- [ ] Tests are isolated and repeatable
- [ ] Performance tests run within limits
- [ ] Integration tests cover happy path and error cases
- [ ] Mock services are used appropriately
- [ ] Database is properly cleaned between tests

### For New Features

- [ ] Unit tests for all new classes/methods
- [ ] Integration tests for feature workflows
- [ ] Error handling tests for edge cases
- [ ] Performance tests for critical paths
- [ ] Documentation tests for examples
- [ ] Backward compatibility tests

---

*This document is part of the Ragdoll documentation suite. For immediate help, see the [Quick Start Guide](quick-start.md) or [API Reference](api-client.md).*