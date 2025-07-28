# Installation & Setup

This comprehensive guide covers installing Ragdoll in various environments, from development setup to production deployment with all dependencies and configuration options.

## System Requirements

### Minimum Requirements

- **Ruby**: 3.0 or higher
- **Database**: PostgreSQL 12+ (with pgvector extension) - REQUIRED
- **Memory**: 2 GB RAM minimum, 4 GB recommended
- **Storage**: 1 GB free space (plus document storage)
- **Network**: Internet access for LLM API calls

### Recommended Production Requirements

- **Ruby**: 3.2+ 
- **Database**: PostgreSQL 14+ with pgvector extension
- **Memory**: 8 GB RAM or more
- **Storage**: 10 GB+ SSD storage
- **CPU**: 4+ cores for background processing
- **Network**: Stable internet with low latency to LLM providers

## Installation Methods

### Method 1: Gem Installation (Recommended)

```bash
# Install the gem
gem install ragdoll

# Verify installation
ruby -e "require 'ragdoll'; puts Ragdoll::Core::VERSION"
```

### Method 2: Bundler (For Applications)

Add to your `Gemfile`:

```ruby
# Gemfile
gem 'ragdoll', '~> 0.1.0'

# Required: PostgreSQL adapter  
gem 'pg', '~> 1.5'        # PostgreSQL - REQUIRED

# Optional: background job adapter
gem 'sidekiq', '~> 7.0'   # For production background processing
```

Install dependencies:

```bash
bundle install
```

### Method 3: Development Installation

```bash
# Clone the repository
git clone https://github.com/madbomber/ragdoll.git
cd ragdoll

# Install dependencies
bundle install

# Run tests to verify installation
bundle exec rake test

# Install locally
bundle exec rake install
```

## Database Setup

### PostgreSQL with pgvector (Recommended for Production)

#### Installation

**Ubuntu/Debian:**
```bash
# Install PostgreSQL
sudo apt update
sudo apt install postgresql-14 postgresql-contrib-14

# Install pgvector
sudo apt install postgresql-14-pgvector

# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

**macOS (Homebrew):**
```bash
# Install PostgreSQL
brew install postgresql@14

# Install pgvector
brew install pgvector

# Start PostgreSQL
brew services start postgresql@14
```

**CentOS/RHEL:**
```bash
# Install PostgreSQL
sudo dnf install postgresql14-server postgresql14-contrib

# Install pgvector
sudo dnf install postgresql14-pgvector

# Initialize and start
sudo postgresql-setup --initdb
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

#### Database Configuration

```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE ragdoll_development;
CREATE DATABASE ragdoll_test;
CREATE DATABASE ragdoll_production;

CREATE USER ragdoll WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE ragdoll_development TO ragdoll;
GRANT ALL PRIVILEGES ON DATABASE ragdoll_test TO ragdoll;
GRANT ALL PRIVILEGES ON DATABASE ragdoll_production TO ragdoll;

# Enable pgvector extension on each database
\c ragdoll_development
CREATE EXTENSION vector;

\c ragdoll_test  
CREATE EXTENSION vector;

\c ragdoll_production
CREATE EXTENSION vector;

\q
```

#### pgvector Verification

```bash
# Test pgvector installation
psql -U ragdoll -d ragdoll_development -c "SELECT vector('[1,2,3]') <-> vector('[4,5,6]');"
# Should return a distance value
```

**Note**: Ragdoll ONLY supports PostgreSQL. SQLite is not supported due to the requirement for pgvector extension and PostgreSQL-specific features.

### Database Migration

```ruby
# Create and configure Ragdoll client
require 'ragdoll'

Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: 'postgresql',  # PostgreSQL REQUIRED
    database: 'ragdoll_development',
    username: 'ragdoll',
    password: 'your_secure_password',
    host: 'localhost',
    port: 5432,
    auto_migrate: true  # Automatically run migrations
  }
end

# The schema will be created automatically on first use
client = Ragdoll::Core.client
```

## LLM Provider Setup

### OpenAI (Recommended)

```bash
# Set your OpenAI API key
export OPENAI_API_KEY='sk-your-openai-api-key-here'

# Add to your shell profile for persistence
echo 'export OPENAI_API_KEY="sk-your-openai-api-key-here"' >> ~/.bashrc
source ~/.bashrc
```

**Configuration:**
```ruby
Ragdoll::Core.configure do |config|
  # Configure Ruby LLM providers
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
  
  # Configure embedding models
  config.models[:embedding][:text] = 'text-embedding-3-small'  # Recommended
  # config.models[:embedding][:text] = 'text-embedding-3-large'  # Higher quality
  
  # Set default model
  config.models[:default] = 'openai/gpt-4o-mini'
end
```

### Anthropic Claude

```bash
# Set your Anthropic API key
export ANTHROPIC_API_KEY='sk-ant-your-anthropic-key-here'
```

**Configuration:**
```ruby
Ragdoll::Core.configure do |config|
  # Configure Ruby LLM providers
  config.ruby_llm_config[:anthropic][:api_key] = ENV['ANTHROPIC_API_KEY']
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']  # Still needed for embeddings
  
  # Configure models
  config.models[:default] = 'anthropic/claude-3-sonnet-20240229'
  config.models[:summary] = 'anthropic/claude-3-sonnet-20240229'
  config.models[:embedding][:text] = 'text-embedding-3-small'  # OpenAI embeddings
end
```

### Google Gemini

```bash
# Set your Google API key
export GOOGLE_API_KEY='your-google-api-key-here'
```

**Configuration:**
```ruby
Ragdoll::Core.configure do |config|
  # Configure Ruby LLM providers
  config.ruby_llm_config[:google][:api_key] = ENV['GOOGLE_API_KEY']
  
  # Configure models
  config.models[:default] = 'google/gemini-1.5-pro'
  config.models[:summary] = 'google/gemini-1.5-pro'
end
```

### Ollama (Local LLM)

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull models
ollama pull llama3:8b
ollama pull nomic-embed-text

# Start Ollama service
ollama serve
```

**Configuration:**
```ruby
Ragdoll::Core.configure do |config|
  # Configure Ruby LLM providers
  config.ruby_llm_config[:ollama][:endpoint] = 'http://localhost:11434/v1'
  
  # Configure models
  config.models[:default] = 'ollama/llama3:8b'
  config.models[:summary] = 'ollama/llama3:8b'
  config.models[:embedding][:text] = 'nomic-embed-text'
end
```

## Development Environment Setup

### Basic Development Configuration

Create a configuration file:

```ruby
# config/ragdoll.rb
require 'ragdoll'

Ragdoll::Core.configure do |config|
  # Configure Ruby LLM providers
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
  
  # Configure models
  config.models[:embedding][:text] = 'text-embedding-3-small'
  config.models[:default] = 'openai/gpt-4o-mini'
  
  # Development database (PostgreSQL)
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_development',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }
  
  # Development settings
  config.logging_config[:log_level] = :debug
  config.chunking[:text][:max_tokens] = 800
  config.chunking[:text][:overlap] = 100
end
```

### Rails Integration

For Rails applications:

```ruby
# config/initializers/ragdoll.rb
Ragdoll::Core.configure do |config|
  # Configure Ruby LLM providers
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
  
  # Configure models
  config.models[:embedding][:text] = 'text-embedding-3-small'
  config.models[:default] = 'openai/gpt-4o-mini'
  
  # Use Rails database configuration
  config.database_config = Rails.application.config.database_configuration[Rails.env]
  
  # Logging configuration
  config.logging_config[:log_level] = Rails.logger.level
  config.logging_config[:log_filepath] = Rails.root.join('log', 'ragdoll.log').to_s
end
```

### Environment-Specific Configuration

```ruby
# config/environments/development.rb
Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_development',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }
  config.logging_config[:log_level] = :debug
end

# config/environments/test.rb  
Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_test',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }
  config.logging_config[:log_level] = :fatal
end

# config/environments/production.rb
Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: 'postgresql',
    url: ENV['DATABASE_URL'],
    pool: 25,
    auto_migrate: false
  }
  config.logging_config[:log_level] = :info
end
```

## Background Processing Setup

### Sidekiq (Recommended for Production)

```bash
# Install Redis
# Ubuntu/Debian
sudo apt install redis-server

# macOS
brew install redis

# Start Redis
redis-server
```

**Configuration:**
```ruby
# Gemfile
gem 'sidekiq', '~> 7.0'
gem 'redis', '~> 5.0'

# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end

# Enable background processing in Ragdoll
Ragdoll::Core.configure do |config|
  # Background processing configuration would go here
  # (Current implementation handles this automatically)
end
```

**Start Sidekiq workers:**
```bash
# Development
bundle exec sidekiq

# Production with specific queues
bundle exec sidekiq -q embeddings:3 -q processing:2 -q analysis:1
```

### Alternative: Async (Development)

```ruby
# For development/testing (processing handled automatically)
Ragdoll::Core.configure do |config|
  # No special configuration needed for development
end
```

## File Storage Configuration

### Local Storage (Development)

File storage is handled internally by the content models (TextContent, ImageContent, AudioContent). No additional configuration is required for basic file handling.

## Verification and Testing

### Basic Verification

```ruby
# test_installation.rb
require 'ragdoll'

# Configure with minimal settings
Ragdoll::Core.configure do |config|
  # Configure Ruby LLM providers
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
  
  # Configure models
  config.models[:embedding][:text] = 'text-embedding-3-small'
  config.models[:default] = 'openai/gpt-4o-mini'
  
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_test',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }
end

# Test basic functionality
puts "Testing Ragdoll installation..."

# Test database connection
client = Ragdoll::Core.client
puts "✓ Database connection successful"

# Test document addition
result = Ragdoll.add_document(
  path: __FILE__,  # Add this test file as a document
  title: "Installation Test"
)
puts "✓ Document addition successful: #{result[:success] ? 'OK' : 'FAILED'}"

# Test search
search_results = Ragdoll.search(query: "test document")
puts "✓ Search functionality working: #{search_results[:results]&.size || 0} results"

# Test system health
healthy = Ragdoll.healthy?
puts "✓ System health: #{healthy ? 'OK' : 'ISSUES DETECTED'}"

puts "\nInstallation verification complete! 🎉"
puts "Ragdoll is ready to use."
```

Run the verification:
```bash
ruby test_installation.rb
```

### Component Testing

```bash
# Test database connection
ruby -e "
require 'ragdoll'
Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_development',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost'
  }
end
puts 'Database connection: ' + (Ragdoll::Core::Database.connection.active? ? 'OK' : 'FAILED')
"

# Test LLM provider
ruby -e "
require 'ragdoll'
puts 'OpenAI API: ' + (ENV['OPENAI_API_KEY'] ? 'OK' : 'MISSING')
"

# Test pgvector
psql -U ragdoll -d ragdoll_development -c "SELECT vector('[1,2,3]') <-> vector('[4,5,6]');"
```

## Troubleshooting

### Common Installation Issues

#### 1. Database Connection Errors

**Error:** `PG::ConnectionBad: could not connect to server`

**Solutions:**
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Start PostgreSQL if stopped
sudo systemctl start postgresql

# Check connection parameters
psql -U ragdoll -d ragdoll_development -h localhost

# Verify pg_hba.conf allows connections
sudo nano /etc/postgresql/14/main/pg_hba.conf
# Add: local   all   ragdoll   md5
```

#### 2. pgvector Extension Issues

**Error:** `PG::UndefinedFile: could not open extension control file`

**Solutions:**
```bash
# Reinstall pgvector
sudo apt remove postgresql-14-pgvector
sudo apt install postgresql-14-pgvector

# Manually install extension
sudo -u postgres psql -d ragdoll_development -c "CREATE EXTENSION vector;"
```

#### 3. Ruby Gem Dependencies

**Error:** `LoadError: cannot load such file`

**Solutions:**
```bash
# Update bundler
gem update bundler

# Clean and reinstall
bundle clean --force
bundle install

# Check Ruby version
ruby --version  # Should be 3.0+
```

#### 4. LLM API Issues

**Error:** `OpenAI API key not set`

**Solutions:**
```bash
# Check environment variable
echo $OPENAI_API_KEY

# Set temporarily
export OPENAI_API_KEY='sk-your-key-here'

# Add to shell profile permanently
echo 'export OPENAI_API_KEY="sk-your-key-here"' >> ~/.bashrc
source ~/.bashrc
```

#### 5. Permission Issues

**Error:** `Permission denied` for database or file operations

**Solutions:**
```bash
# Fix database permissions
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ragdoll_development TO ragdoll;"

# Fix file permissions
sudo chown -R $USER:$USER ~/.ragdoll/
chmod -R 755 ~/.ragdoll/
```

### Performance Issues

#### Slow Embedding Generation

```ruby
# Optimize configuration for better performance
Ragdoll::Core.configure do |config|
  config.chunking[:text][:max_tokens] = 800        # Smaller chunks for faster processing
  config.models[:embedding][:text] = 'text-embedding-3-small'  # Faster model
end
```

#### Database Performance

```sql
-- Add indexes for better query performance
CREATE INDEX CONCURRENTLY idx_embeddings_vector_search 
ON ragdoll_embeddings USING ivfflat (embedding_vector vector_cosine_ops);

-- Update statistics
ANALYZE ragdoll_embeddings;
```

### Getting Help

1. **Check Documentation**: Review the complete documentation in `docs/`
2. **Enable Debug Logging**: Set `config.log_level = :debug`
3. **Health Check**: Run `Ragdoll::Core.health_check` to identify issues
4. **GitHub Issues**: Report bugs and feature requests
5. **Community**: Join discussions and get help from other users

## Next Steps

After successful installation:

1. **Quick Start**: Follow the [Quick Start Guide](quick-start.md) for basic usage
2. **Configuration**: Read the [Configuration Guide](configuration.md) for advanced setup
3. **API Reference**: Explore the [Client API Reference](api-client.md)
4. **Production Deployment**: Plan your [Production Deployment](deployment.md)

Congratulations! You now have Ragdoll installed and ready to build sophisticated document intelligence applications.