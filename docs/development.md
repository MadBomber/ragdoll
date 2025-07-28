# Development Setup

## Setting Up Development Environment

This guide covers the complete development environment setup for Ragdoll, including prerequisites, configuration, workflows, and development tools.

### Quick Start for Contributors

```bash
# Clone the repository
git clone https://github.com/your-org/ragdoll.git
cd ragdoll

# Install dependencies
bundle install

# Set up database
./bin/setup_postgresql.rb

# Run tests to verify setup
bundle exec rake test
```

## Prerequisites

### System Requirements

#### Ruby Version Requirements
- **Ruby 3.0+** (recommended: Ruby 3.2+)
- **Bundler 2.0+** for dependency management
- **Git 2.0+** for version control

```bash
# Check versions
ruby --version    # Should be >= 3.0.0
bundle --version  # Should be >= 2.0.0
git --version     # Should be >= 2.0.0
```

#### Database Requirements
- **PostgreSQL 12+** (required - no SQLite support)
- **pgvector extension** for vector similarity search
- **Development and test databases**

```bash
# macOS with Homebrew
brew install postgresql pgvector
brew services start postgresql

# Ubuntu/Debian
sudo apt-get install postgresql-14 postgresql-14-pgvector
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

#### System Dependencies

```bash
# macOS
brew install libpq imagemagick

# Ubuntu/Debian
sudo apt-get install libpq-dev imagemagick libmagickwand-dev

# CentOS/RHEL
sudo yum install postgresql-devel ImageMagick-devel
```

### Environment Setup

#### Repository Cloning and Setup

```bash
# Clone repository
git clone https://github.com/your-org/ragdoll.git
cd ragdoll

# Create and switch to development branch
git checkout -b feature/your-feature-name

# Install Ruby dependencies
bundle install

# Set up git hooks (optional)
cp .githooks/* .git/hooks/
chmod +x .git/hooks/*
```

#### Environment Variables

Create `.env` file for development:
```bash
# .env (not committed to git)
# LLM Provider API Keys
OPENAI_API_KEY=your_openai_api_key
ANTHROPIC_API_KEY=your_anthropic_api_key
GOOGLE_API_KEY=your_google_api_key

# Database Configuration
DATABASE_PASSWORD=your_secure_password
TEST_DATABASE_PASSWORD=test_password

# Development Settings
RAGDOLL_LOG_LEVEL=debug
RAGDOLL_DEVELOPMENT=true
```

#### Database Initialization

```ruby
# Run the setup script
./bin/setup_postgresql.rb

# Or manual setup
# Create databases
sudo -u postgres createdb ragdoll_development
sudo -u postgres createdb ragdoll_test

# Create user
sudo -u postgres psql <<EOF
CREATE USER ragdoll WITH PASSWORD 'secure_password';
ALTER USER ragdoll CREATEDB;
GRANT ALL PRIVILEGES ON DATABASE ragdoll_development TO ragdoll;
GRANT ALL PRIVILEGES ON DATABASE ragdoll_test TO ragdoll;
\q
EOF

# Enable pgvector extension
psql -U ragdoll -d ragdoll_development -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql -U ragdoll -d ragdoll_test -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

## Development Configuration

### Development-Specific Configuration

```ruby
# config/development.rb (create if needed)
Ragdoll::Core.configure do |config|
  # Database configuration for development
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_development',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true,
    logger: Logger.new(STDOUT, level: Logger::DEBUG)
  }
  
  # Logging configuration
  config.logging_config = {
    level: :debug,
    filepath: './logs/development.log'
  }
  
  # LLM provider configuration
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
  config.ruby_llm_config[:anthropic][:api_key] = ENV['ANTHROPIC_API_KEY']
  
  # Development-friendly settings
  config.search[:similarity_threshold] = 0.5  # Lower threshold for testing
  config.embedding_config[:cache_embeddings] = false  # Fresh embeddings
end
```

### Test Environment Configuration

```ruby
# test/test_helper.rb configuration
Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_test',
    username: 'ragdoll',
    password: ENV['TEST_DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true,
    logger: Logger.new('/dev/null')  # Suppress SQL logs in tests
  }
  
  # Use inline job processing for tests
  ActiveJob::Base.queue_adapter = :test
  
  # Mock LLM providers in tests
  config.ruby_llm_config[:openai][:api_key] = 'test_key'
end
```

### Local Model Setup (Ollama)

```bash
# Install Ollama for local development
curl -fsSL https://ollama.ai/install.sh | sh

# Pull models for development
ollama pull llama2
ollama pull nomic-embed-text

# Start Ollama server
ollama serve
```

```ruby
# Configure Ollama in development
Ragdoll::Core.configure do |config|
  config.ruby_llm_config[:ollama] = {
    endpoint: 'http://localhost:11434/v1'
  }
  
  # Use local models
  config.models[:default] = 'ollama/llama2'
  config.models[:embedding][:text] = 'ollama/nomic-embed-text'
end
```

## Development Workflow

### Code Organization

```
lib/ragdoll/core/
├── client.rb              # Main client interface
├── configuration.rb       # Configuration management
├── database.rb           # Database connection and migrations
├── document_processor.rb # Multi-format document parsing
├── embedding_service.rb  # Vector embedding generation
├── search_engine.rb      # Semantic search implementation
├── text_chunker.rb       # Intelligent text segmentation
├── jobs/                 # ActiveJob background jobs
│   ├── generate_embeddings.rb
│   ├── extract_keywords.rb
│   └── generate_summary.rb
├── models/               # ActiveRecord models
│   ├── document.rb
│   ├── embedding.rb
│   └── content/          # STI content models
└── services/             # Business logic services
    ├── metadata_generator.rb
    └── image_description_service.rb
```

### Naming Conventions

- **Classes**: `PascalCase` (e.g., `DocumentProcessor`)
- **Methods**: `snake_case` (e.g., `generate_embedding`)
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `DEFAULT_CONFIG`)
- **Files**: `snake_case.rb` (e.g., `document_processor.rb`)
- **Database tables**: `ragdoll_` prefix (e.g., `ragdoll_documents`)

### Git Workflow

```bash
# Feature development workflow
git checkout main
git pull origin main
git checkout -b feature/add-new-processor

# Make changes
git add .
git commit -m "Add support for Excel file processing

- Implement ExcelProcessor class
- Add Excel MIME type detection
- Include tests for Excel parsing
- Update documentation"

# Push feature branch
git push origin feature/add-new-processor

# Create pull request (via GitHub UI)
```

#### Commit Message Format

```
Type: Brief description (50 chars max)

- Detailed bullet point 1
- Detailed bullet point 2
- Reference to issue #123

Types: feat, fix, docs, style, refactor, test, chore
```

## Testing Setup

### Test Framework Configuration

Ragdoll uses **Minitest** with custom helpers:

```ruby
# test/test_helper.rb
require 'minitest/autorun'
require 'minitest/reporters'
require 'simplecov'

# Start SimpleCov for coverage analysis
SimpleCov.start do
  add_filter '/test/'
  add_filter '/vendor/'
  minimum_coverage 85
end

require 'ragdoll'

# Test database setup
class Minitest::Test
  def setup
    # Clean database before each test
    Ragdoll::Core::Database.reset!
  end
  
  def teardown
    # Clean up after each test
    ActiveRecord::Base.clear_all_connections!
  end
end

# Custom assertions
module TestHelpers
  def assert_embedding_generated(text)
    service = Ragdoll::Core::EmbeddingService.new
    embedding = service.generate_embedding(text)
    assert embedding.is_a?(Array), "Expected array, got #{embedding.class}"
    assert embedding.length > 0, "Expected non-empty embedding"
  end
  
  def assert_document_processed(document_id)
    document = Ragdoll::Core::Models::Document.find(document_id)
    assert_equal 'processed', document.status
    assert document.content.present?
  end
end

Minitest::Test.include(TestHelpers)
```

### Running Tests

```bash
# Run all tests
bundle exec rake test

# Run specific test file
bundle exec rake test test/core/client_test.rb

# Run tests with coverage report
RAILS_ENV=test bundle exec rake test
open coverage/index.html

# Run tests with verbose output
bundle exec rake test TESTOPTS="-v"

# Run performance tests (if implemented)
bundle exec rake test:performance
```

### Test Categories

#### Unit Tests
```ruby
# test/core/embedding_service_test.rb
class EmbeddingServiceTest < Minitest::Test
  def setup
    @service = Ragdoll::Core::EmbeddingService.new
  end
  
  def test_generates_embedding_for_text
    text = "This is a test document"
    embedding = @service.generate_embedding(text)
    
    assert_instance_of Array, embedding
    assert embedding.length > 0
    assert embedding.all? { |val| val.is_a?(Numeric) }
  end
end
```

#### Integration Tests
```ruby
# test/integration/document_processing_test.rb
class DocumentProcessingTest < Minitest::Test
  def test_complete_document_workflow
    # Add document
    client = Ragdoll::Core.client
    result = client.add_document(path: 'test/fixtures/sample.pdf')
    
    assert result[:success]
    document_id = result[:document_id]
    
    # Verify processing (background jobs run inline in test)
    document = Ragdoll::Core::Models::Document.find(document_id)
    assert_equal 'processed', document.status
    assert document.embeddings.any?
    
    # Test search
    search_results = client.search(query: "sample document")
    assert search_results[:results].any?
  end
end
```

## Development Tools

### Code Quality Tools

#### RuboCop Configuration

```yaml
# .rubocop.yml
AllCops:
  TargetRubyVersion: 3.0
  NewCops: enable
  Exclude:
    - 'vendor/**/*'
    - 'db/migrate/*'
    - 'coverage/**/*'
    - 'pkg/**/*'
    - 'tmp/**/*'

Metrics/LineLength:
  Max: 120
  AllowedPatterns: ['^\s*#']

Style/Documentation:
  Enabled: false  # Disable for now, enable later

Style/FrozenStringLiteralComment:
  Enabled: true
  EnforcedStyle: always
```

```bash
# Run RuboCop
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -a

# Check specific files
bundle exec rubocop lib/ragdoll/core/client.rb
```

#### SimpleCov Configuration

```ruby
# .simplecov
SimpleCov.configure do
  load_profile 'test_frameworks'
  
  add_filter '/test/'
  add_filter '/vendor/'
  add_filter 'version.rb'
  
  add_group 'Models', 'lib/ragdoll/core/models'
  add_group 'Services', 'lib/ragdoll/core/services'
  add_group 'Jobs', 'lib/ragdoll/core/jobs'
  
  minimum_coverage 85
  minimum_coverage_by_file 70
end
```

### Debugging Tools

#### Console Development

```ruby
# bin/console (create executable script)
#!/usr/bin/env ruby

require 'bundler/setup'
require 'ragdoll'
require 'irb'

# Load development configuration
Ragdoll::Core.configure do |config|
  # Development-friendly settings
end

# Helper methods for console
def reload!
  load 'lib/ragdoll.rb'
end

def test_client
  @test_client ||= Ragdoll::Core.client
end

def sample_document
  test_client.add_document(path: 'test/fixtures/sample.pdf')
end

puts "Ragdoll development console"
puts "Available helpers: reload!, test_client, sample_document"

IRB.start
```

```bash
# Make console executable and run
chmod +x bin/console
./bin/console
```

#### Memory Profiling

```ruby
# Development memory profiler
require 'memory_profiler'

report = MemoryProfiler.report do
  # Code to profile
  client = Ragdoll::Core.client
  client.add_document(path: 'large_document.pdf')
end

report.pretty_print
```

#### Performance Monitoring

```ruby
# lib/ragdoll/core/development/profiler.rb
module Ragdoll
  module Core
    module Development
      class Profiler
        def self.benchmark(description, &block)
          puts "Benchmarking: #{description}"
          start_time = Time.current
          start_memory = get_memory_usage
          
          result = yield
          
          end_time = Time.current
          end_memory = get_memory_usage
          
          puts "  Time: #{((end_time - start_time) * 1000).round(2)}ms"
          puts "  Memory: #{(end_memory - start_memory).round(2)}MB"
          
          result
        end
        
        private
        
        def self.get_memory_usage
          `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
        end
      end
    end
  end
end
```

## Local Development Features

### Development Scripts

```bash
# bin/dev_server (development server script)
#!/bin/bash
echo "Starting Ragdoll development environment..."

# Start PostgreSQL if not running
if ! pgrep -x "postgres" > /dev/null; then
    echo "Starting PostgreSQL..."
    brew services start postgresql
fi

# Start Ollama if configured
if command -v ollama &> /dev/null; then
    echo "Starting Ollama server..."
    ollama serve &
fi

# Run tests to verify setup
echo "Running quick health check..."
bundle exec rake test:quick

echo "Development environment ready!"
echo "Run './bin/console' to start interactive session"
```

### Auto-reloading Development

```ruby
# Development auto-reloader using Listen gem
require 'listen'

listener = Listen.to('lib') do |modified, added, removed|
  puts "Files changed: #{modified + added + removed}"
  puts "Reloading Ragdoll..."
  
  # Reload the library
  Object.send(:remove_const, :Ragdoll) if defined?(Ragdoll)
  load 'lib/ragdoll.rb'
  
  puts "Reload complete!"
end

listener.start
sleep
```

## Contributing Workflow

### Setting Up for Contribution

1. **Fork the Repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/ragdoll.git
   cd ragdoll
   
   # Add upstream remote
   git remote add upstream https://github.com/original-org/ragdoll.git
   ```

2. **Create Feature Branch**
   ```bash
   git checkout -b feature/your-awesome-feature
   ```

3. **Development Process**
   - Write tests first (TDD approach)
   - Implement feature
   - Ensure all tests pass
   - Run RuboCop for style compliance
   - Update documentation

4. **Testing Requirements**
   ```bash
   # All tests must pass
   bundle exec rake test
   
   # Code coverage must be >= 85%
   # RuboCop must pass
   bundle exec rubocop
   
   # Documentation must be updated
   ```

### Submission Process

1. **Pre-submission Checklist**
   - [ ] All tests pass
   - [ ] Code coverage maintained
   - [ ] RuboCop passes
   - [ ] Documentation updated
   - [ ] Commit messages follow conventions

2. **Create Pull Request**
   ```bash
   git push origin feature/your-awesome-feature
   # Create PR via GitHub UI
   ```

3. **PR Requirements**
   - Clear description of changes
   - Reference to related issues
   - Before/after examples if applicable
   - Migration notes if needed

## Development Best Practices

### Code Style Guidelines
- Follow Ruby community conventions
- Use meaningful variable and method names
- Keep methods focused and small
- Write self-documenting code
- Add comments for complex business logic

### Testing Philosophy
- Write tests first (TDD)
- Test behavior not implementation
- Use descriptive test names
- Keep tests isolated and fast
- Mock external services

### Performance Considerations
- Profile code changes with large datasets
- Monitor memory usage in background jobs
- Use database indexes appropriately
- Cache expensive operations when possible
- Consider batch processing for large operations

### Documentation Standards
- Update documentation with code changes
- Include code examples in documentation
- Use Mermaid diagrams for complex workflows
- Document breaking changes clearly
- Maintain accurate API references

---

*This document is part of the Ragdoll documentation suite. For immediate help, see the [Quick Start Guide](quick-start.md) or [API Reference](api-client.md).*