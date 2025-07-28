# Quick Start Guide

Get up and running with Ragdoll in 5 minutes. This guide covers installation, basic configuration, and essential operations to demonstrate the powerful document intelligence capabilities.

## Prerequisites

- Ruby 3.2+
- PostgreSQL database with pgvector extension
- An OpenAI API key (or other supported LLM provider)

## Installation

### Option 1: Gem Installation

```bash
gem install ragdoll
```

### Option 2: Bundler

Add to your Gemfile:

```ruby
gem 'ragdoll'
```

Then run:

```bash
bundle install
```

### Option 3: Development Setup

```bash
git clone https://github.com/madbomber/ragdoll.git
cd ragdoll
bundle install
```

## Basic Configuration

### PostgreSQL Setup

```ruby
require 'ragdoll'

Ragdoll::Core.configure do |config|
  # Configure Ruby LLM providers
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']  # Set your OpenAI API key

  # Configure models
  config.embedding_config[:text][:model] = 'openai/text-embedding-3-small'
  config.embedding_config[:default][:model] = 'openai/gpt-4o-mini'

  # PostgreSQL database
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_development',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true  # Automatically create schema
  }

  # Basic settings
  config.logging_config[:log_level] = :info
  config.chunking[:text][:max_tokens] = 1000
  config.chunking[:text][:overlap] = 200
end
```

### Production PostgreSQL Setup

```ruby
Ragdoll::Core.configure do |config|
  # Configure Ruby LLM providers
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']

  # Configure models
  config.embedding_config[:text][:model] = 'openai/text-embedding-3-small'
  config.embedding_config[:default][:model] = 'openai/gpt-4o-mini'

  # PostgreSQL with pgvector
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_production',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }
end
```

## First Steps

### 1. Add Your First Document

```ruby
# Add a PDF document
result = Ragdoll::Core.add_document(path: 'research_paper.pdf')
puts result[:message]
# => "Document 'research_paper' added successfully with ID 123"

# Store the document ID for later use
doc_id = result[:document_id]
```

### 2. Check Processing Status

```ruby
# Check if document processing is complete
status = Ragdoll::Core.document_status(id: doc_id)
puts "Status: #{status[:status]}"
puts "Progress: #{status[:progress]}%"
puts "Embeddings: #{status[:embeddings_count]} ready"

# Wait for processing to complete (in real applications, use background monitoring)
while status[:status] == 'processing'
  sleep(2)
  status = Ragdoll::Core.document_status(id: doc_id)
  puts "Processing... #{status[:progress]}%"
end
```

### 3. Search Your Document

```ruby
# Search for content
results = Ragdoll::Core.search(query: 'machine learning algorithms')

results.each do |result|
  puts "Score: #{result[:similarity_score]}"
  puts "Content: #{result[:content]}"
  puts "Document: #{result[:document_title]}"
  puts "---"
end
```

### 4. Use RAG Enhancement

```ruby
# Get relevant context for a question
context = Ragdoll::Core.get_context(
  query: 'What are the key benefits of neural networks?',
  limit: 3
)

puts "Found #{context[:context_items].size} relevant passages"

# Enhance a prompt with context
enhanced = Ragdoll::Core.enhance_prompt(
  prompt: 'Explain neural networks',
  context_limit: 3
)

puts "Enhanced prompt:"
puts enhanced[:enhanced_prompt]
```

## Common Use Cases

### Document Intelligence Pipeline

```ruby
# Process a collection of research papers
documents_dir = '/path/to/research/papers'

# Add all PDFs in directory
result = Ragdoll::Core.add_directory(
  path: documents_dir,
  file_patterns: ['*.pdf'],
  recursive: true
)

puts "Processing #{result[:processed_files]} documents..."

# Wait for processing to complete
sleep(30)  # In production, use proper background job monitoring

# Search across all documents
results = Ragdoll::Core.search(
  query: 'deep learning optimization techniques',
  limit: 10
)

puts "Found #{results.size} relevant passages across your research library"
```

### Multi-Modal Content

```ruby
# Add different types of content
text_result = Ragdoll::Core.add_text(
  content: "This is important information about AI safety...",
  title: "AI Safety Notes"
)

# Add an image with description
image_result = Ragdoll::Core.add_image(
  image_path: 'neural_network_diagram.png',
  description: 'Diagram showing the architecture of a convolutional neural network'
)

# Search across all content types
mixed_results = Ragdoll::Core.search(
  query: 'neural network architecture',
  content_types: ['text', 'image']
)

mixed_results.each do |result|
  puts "Type: #{result[:content_type]}"
  puts "Content: #{result[:content]}"
  puts "---"
end
```

### Knowledge Base Q&A

```ruby
# Build a knowledge base
knowledge_files = [
  'company_handbook.pdf',
  'technical_documentation.docx',
  'meeting_notes.txt',
  'presentation_slides.pdf'
]

knowledge_files.each do |file|
  result = Ragdoll::Core.add_document(path: file)
  puts "Added: #{result[:message]}"
end

# Wait for processing
sleep(60)

# Answer questions using RAG
def answer_question(question)
  enhanced = Ragdoll::Core.enhance_prompt(
    prompt: question,
    context_limit: 5,
    include_sources: true
  )

  puts "Question: #{question}"
  puts "Context sources: #{enhanced[:sources].join(', ')}"
  puts "Enhanced prompt ready for LLM"
  puts enhanced[:enhanced_prompt]
end

answer_question("What is our company's policy on remote work?")
answer_question("How do I configure the authentication system?")
```

## Configuration Examples

### Multiple LLM Providers

```ruby
# Use different providers for different tasks
Ragdoll::Core.configure do |config|
  # Configure multiple Ruby LLM providers
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
  config.ruby_llm_config[:anthropic][:api_key] = ENV['ANTHROPIC_API_KEY']
  config.ruby_llm_config[:ollama][:endpoint] = 'http://localhost:11434/v1'

  # Configure models for different tasks
  config.embedding_config[:text][:model] = 'openai/text-embedding-3-small'  # OpenAI embeddings
  config.embedding_config[:default][:model] = 'openai/gpt-4o-mini'          # OpenAI for general tasks
  config.summarization_config[:model] = 'anthropic/claude-3-sonnet-20240229'  # Claude for summarization
  config.keywords_config[:model] = 'ollama/llama3:8b'                         # Local Ollama for keywords
end
```

### Performance Tuning

```ruby
Ragdoll::Core.configure do |config|
  # Optimize for your content
  config.chunking[:text][:max_tokens] = 1500         # Larger chunks for technical documents
  config.chunking[:text][:overlap] = 300             # More overlap for better context
  config.search[:similarity_threshold] = 0.8         # Higher threshold for precision
  config.search[:max_results] = 20                   # More results for comprehensive search

  # Enable advanced features
  config.analytics_config[:enable] = true
  config.summarization_config[:enable] = true
  config.keywords_config[:enable] = true
end
```

## Monitoring and Debugging

### Check System Health

```ruby
# System health check
health = Ragdoll::Core.health_check
puts "System status: #{health[:status]}"
puts "Components:"
health[:components].each do |component, status|
  puts "  #{component}: #{status}"
end
```

### Get System Statistics

```ruby
# Comprehensive statistics
stats = Ragdoll::Core.stats

puts "Documents: #{stats[:documents][:total]}"
puts "Embeddings: #{stats[:embeddings][:total]}"
puts "Searches today: #{stats[:usage][:searches_today]}"
puts "Storage used: #{stats[:usage][:storage_used]}"
```

### View Recent Activity

```ruby
# List recent documents
recent_docs = Ragdoll::Core.list_documents(
  limit: 10,
  sort: 'created_at',
  order: 'desc'
)

puts "Recent documents:"
recent_docs[:documents].each do |doc|
  puts "  #{doc[:title]} (#{doc[:status]}) - #{doc[:created_at]}"
end
```

## Troubleshooting

### Common Issues

#### API Key Not Set
```ruby
# Error: Missing OpenAI API key
# Solution: Set your API key
ENV['OPENAI_API_KEY'] = 'sk-your-actual-api-key'
```

#### Database Connection Issues
```ruby
# Error: Database connection failed
# Solution: Check database configuration
config.database_config = {
  adapter: 'postgresql',
  database: 'ragdoll_development',
  username: 'ragdoll',
  password: ENV['DATABASE_PASSWORD'],
  host: 'localhost',
  port: 5432,
  auto_migrate: true
}
```

#### Document Processing Stuck
```ruby
# Check document status
status = Ragdoll::Core.document_status(id: doc_id)
puts status

# Check background job status
job_status = Ragdoll::Core.job_status
puts "Active jobs: #{job_status[:active_jobs]}"
puts "Failed jobs: #{job_status[:failed_jobs]}"
```

### Enable Debug Logging

```ruby
Ragdoll::Core.configure do |config|
  config.logging_config[:log_level] = :debug
  config.logging_config[:log_filepath] = nil  # Log to stdout for development
end
```

## Next Steps

Now that you have Ragdoll running:

1. **Explore Advanced Features**: Read the [Multi-Modal Architecture](multi-modal.md) guide
2. **Optimize Performance**: Check the [Configuration Guide](configuration.md)
3. **Scale to Production**: Follow the [Deployment Guide](deployment.md)
4. **Build Applications**: Review the [API Reference](api-client.md)

### Example Applications

Try building these common applications:

- **Document Q&A System**: Upload PDFs and ask questions
- **Research Assistant**: Search across academic papers
- **Knowledge Base**: Company documentation with smart search
- **Content Analyzer**: Extract insights from large document collections
- **Multi-Modal Search**: Find content across text, images, and audio

### Community and Support

- **Documentation**: Complete guides in the `docs/` directory
- **Examples**: Working examples for common use cases
- **Issues**: Report issues on GitHub
- **Discussions**: Join community discussions

Ragdoll provides enterprise-grade document intelligence capabilities out of the box. This quick start barely scratches the surface of what's possible with the full feature set!
