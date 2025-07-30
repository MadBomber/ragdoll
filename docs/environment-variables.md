# Environment Variables Reference

This document provides a comprehensive reference for all environment variables used in the Ragdoll Core system, organized by category with their default values and usage examples.

## Model Configuration

These environment variables control which LLM models are used for different purposes in the Ragdoll system.

### Text Generation Models

| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `RAGDOLL_DEFAULT_TEXT_MODEL` | `openai/gpt-4o` | Default model for general text generation tasks |
| `RAGDOLL_SUMMARY_MODEL` | `openai/gpt-4o` | Model used for document summarization |
| `RAGDOLL_KEYWORDS_MODEL` | `openai/gpt-4o` | Model used for keyword extraction |

### Embedding Models

| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `RAGDOLL_TEXT_EMBEDDING_MODEL` | `openai/text-embedding-3-small` | Model for generating text embeddings |
| `RAGDOLL_IMAGE_EMBEDDING_MODEL` | `openai/clip-vit-base-patch32` | Model for generating image embeddings |
| `RAGDOLL_AUDIO_EMBEDDING_MODEL` | `openai/whisper-1` | Model for generating audio embeddings |

## Database Configuration

These environment variables configure the PostgreSQL database connection.

| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `RAGDOLL_DATABASE_PASSWORD` | _(none)_ | Password for database authentication |
| `POSTGRES_SUPERUSER` | `postgres` | Superuser for database setup operations |
| `POSTGRES_SUPERUSER_PASSWORD` | _(none)_ | Password for the PostgreSQL superuser |

## LLM Provider Configuration

These environment variables configure access to various LLM providers.

### OpenAI

| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `OPENAI_API_KEY` | _(none)_ | API key for OpenAI services |
| `OPENAI_ORGANIZATION` | _(none)_ | OpenAI organization ID |
| `OPENAI_PROJECT` | _(none)_ | OpenAI project ID |
| `OPENAI_API_BASE` | _(none)_ | Custom OpenAI API base URL |

### Anthropic

| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `ANTHROPIC_API_KEY` | _(none)_ | API key for Anthropic Claude services |

### Google

| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `GOOGLE_API_KEY` | _(none)_ | API key for Google AI services |
| `GOOGLE_PROJECT_ID` | _(none)_ | Google Cloud project ID |
| `GEMINI_API_KEY` | _(none)_ | API key for Google Gemini services |

### Azure OpenAI

| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `AZURE_OPENAI_API_KEY` | _(none)_ | API key for Azure OpenAI services |
| `AZURE_OPENAI_ENDPOINT` | _(none)_ | Azure OpenAI endpoint URL |
| `AZURE_OPENAI_API_VERSION` | `2024-02-01` | Azure OpenAI API version |

### Ollama

| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `OLLAMA_ENDPOINT` | `http://localhost:11434` | Ollama server endpoint |
| `OLLAMA_API_BASE` | `http://localhost:11434` | Alternative Ollama API base (used in image service) |

### Other Providers

| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `HUGGINGFACE_API_KEY` | _(none)_ | API key for Hugging Face services |
| `OPENROUTER_API_KEY` | _(none)_ | API key for OpenRouter services |
| `DEEPSEEK_API_KEY` | _(none)_ | API key for DeepSeek services |
| `BEDROCK_ACCESS_KEY_ID` | _(none)_ | AWS Bedrock access key ID |
| `BEDROCK_SECRET_ACCESS_KEY` | _(none)_ | AWS Bedrock secret access key |
| `BEDROCK_REGION` | _(none)_ | AWS Bedrock region |
| `BEDROCK_SESSION_TOKEN` | _(none)_ | AWS Bedrock session token |

## Legacy Environment Variables

These environment variables are deprecated but may still be referenced in older code:

| Variable | Status | Replacement |
|----------|--------|-------------|
| `DATABASE_PASSWORD` | Deprecated | Use `RAGDOLL_DATABASE_PASSWORD` |
| `OPENAI_ORGANIZATION_ID` | Legacy alias | Use `OPENAI_ORGANIZATION` |
| `OPENAI_PROJECT_ID` | Legacy alias | Use `OPENAI_PROJECT` |

## Usage Examples

### Basic Configuration

```bash
# Required for OpenAI integration
export OPENAI_API_KEY="sk-..."

# Database configuration
export RAGDOLL_DATABASE_PASSWORD="your_password"

# Optional: Use different models
export RAGDOLL_DEFAULT_TEXT_MODEL="openai/gpt-3.5-turbo"
export RAGDOLL_TEXT_EMBEDDING_MODEL="openai/text-embedding-ada-002"
```

### Development Setup

```bash
# Development database
export RAGDOLL_DATABASE_PASSWORD="dev_password"
export POSTGRES_SUPERUSER="postgres"
export POSTGRES_SUPERUSER_PASSWORD="postgres"

# Local Ollama setup
export OLLAMA_ENDPOINT="http://localhost:11434"
```

### Production Environment

```bash
# Production OpenAI configuration
export OPENAI_API_KEY="sk-prod-..."
export OPENAI_ORGANIZATION="org-..."
export OPENAI_PROJECT="proj_..."

# Production database
export RAGDOLL_DATABASE_PASSWORD="$(cat /secrets/db-password)"

# Azure OpenAI for enterprise
export AZURE_OPENAI_API_KEY="..."
export AZURE_OPENAI_ENDPOINT="https://your-resource.openai.azure.com/"
export AZURE_OPENAI_API_VERSION="2024-02-01"
```

## Environment Variable Patterns

### Naming Convention
- All Ragdoll-specific variables use the `RAGDOLL_` prefix
- Provider-specific variables follow the provider's standard naming
- Database variables use the `RAGDOLL_DATABASE_` prefix for clarity

### Default Value Handling
The codebase uses a consistent pattern for environment variable handling:

**ENV.fetch pattern**: All environment variable access uses `ENV.fetch("VAR_NAME", default_value)` for consistency and explicit default handling:

1. **Variables with defaults**: `ENV.fetch("AZURE_OPENAI_API_VERSION", "2024-02-01")`
2. **Variables without defaults**: `ENV.fetch("OPENAI_API_KEY", nil)` (for secrets that shouldn't have fallback values)

This approach provides:
- **Explicit defaults**: Clear indication of what happens when a variable is unset
- **Consistent behavior**: Same pattern throughout the codebase
- **Better debugging**: Easier to track environment variable usage
- **Security**: Secrets explicitly default to `nil` rather than having fallback values

### Security Considerations
- API keys and secrets use `ENV.fetch("KEY", nil)` to explicitly return `nil` when unset
- Database passwords are handled securely with the RAGDOLL_ prefix
- Never commit actual API keys or passwords to version control
- Use environment-specific configuration files or secret management systems
- The proc-based lazy evaluation (`-> { ENV.fetch("KEY", nil) }`) ensures credentials are only accessed when needed

## Troubleshooting

### Common Issues

1. **Missing API Key**: Ensure the required provider API key is set
2. **Database Connection**: Verify `RAGDOLL_DATABASE_PASSWORD` is set correctly
3. **Model Not Found**: Check that the model name in the environment variable is correct
4. **Ollama Connection**: Ensure Ollama is running and `OLLAMA_ENDPOINT` points to the correct URL

### Debug Environment Variables

To check which environment variables are currently set:

```bash
# Show all Ragdoll-related variables
env | grep RAGDOLL

# Show all LLM provider variables
env | grep -E "(OPENAI|ANTHROPIC|GOOGLE|GEMINI|AZURE|OLLAMA|HUGGINGFACE|OPENROUTER|DEEPSEEK|BEDROCK)"
```

### Configuration Validation

Use the Ragdoll configuration system to validate your environment setup:

```ruby
# Check if configuration loads correctly
config = Ragdoll::Core.configuration
puts "Configuration loaded successfully!"

# Test database connection
Ragdoll::Core::Database.setup(config.database_config)
puts "Database connection successful!"
```