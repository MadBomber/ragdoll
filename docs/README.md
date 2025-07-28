# Ragdoll Documentation

Welcome to the comprehensive documentation for **Ragdoll**, a sophisticated multi-modal document intelligence platform built on ActiveRecord. This documentation accurately reflects the advanced capabilities and production-ready features of the system.

## 📚 Documentation Overview

### Getting Started
- **[Quick Start Guide](quick-start.md)** - Get up and running with Ragdoll in minutes
- **[Installation & Setup](installation.md)** - Complete installation and environment setup
- **[Configuration Guide](configuration.md)** - Comprehensive configuration system documentation

### Core Architecture
- **[Architecture Overview](architecture.md)** - System design and component relationships
- **[Multi-Modal Support](multi-modal.md)** - Text, image, and audio content handling
- **[Database Schema](database-schema.md)** - Polymorphic multi-modal database design
- **[Background Processing](background-processing.md)** - ActiveJob integration and async operations

### Features & Capabilities
- **[Document Processing](document-processing.md)** - File parsing, metadata extraction, and content analysis
- **[Search & Analytics](search-analytics.md)** - Advanced semantic search with usage analytics
- **[Embedding System](embedding-system.md)** - Vector generation and similarity search
- **[File Upload System](file-uploads.md)** - Shrine-based production file handling

### API Documentation
- **[Client API Reference](api-client.md)** - High-level client interface methods
- **[Models Reference](api-models.md)** - ActiveRecord models and relationships
- **[Services Reference](api-services.md)** - Business logic and processing services
- **[Jobs Reference](api-jobs.md)** - Background job system

### Deployment & Operations
- **[Production Deployment](deployment.md)** - Production setup with PostgreSQL + pgvector
- **[Performance Tuning](performance.md)** - Optimization strategies and monitoring
- **[Monitoring & Analytics](monitoring.md)** - Usage tracking and system health
- **[Troubleshooting](troubleshooting.md)** - Common issues and solutions

### Advanced Topics
- **[LLM Integration](llm-integration.md)** - Multiple provider support and configuration
- **[Metadata Schemas](metadata-schemas.md)** - Structured content analysis and validation
- **[Extending the System](extending.md)** - Adding new content types and processors
- **[Security Considerations](security.md)** - Production security best practices

### Development
- **[Development Setup](development.md)** - Setting up development environment
- **[Testing Guide](testing.md)** - Running tests and coverage analysis
- **[Contributing](contributing.md)** - Guidelines for contributing to the project

## 🚀 What Makes Ragdoll Special

Ragdoll is not just a "simple RAG library" - it's a **production-ready document intelligence platform** with enterprise-grade features:

### 🎯 **Multi-Modal First**
Unlike most RAG systems that retrofit multi-modal support, Ragdoll was designed from the ground up to handle text, image, and audio content as first-class citizens through a sophisticated polymorphic architecture.

### 🏗️ **Sophisticated Architecture**
- **Dual Metadata Design**: Separates LLM-generated content analysis from system file properties
- **Polymorphic Database Schema**: Unified search across all content types
- **Background Processing**: Complete ActiveJob integration for scalable operations
- **Production File Handling**: Shrine-based upload system with validation

### 📊 **Advanced Analytics**
- **Usage Tracking**: Sophisticated ranking algorithms based on frequency and recency
- **Performance Monitoring**: Built-in analytics for search patterns and system health
- **Smart Ranking**: Combines similarity scores with usage analytics for better results

### 🔧 **Enterprise Features**
- **7 LLM Providers**: OpenAI, Anthropic, Google, Azure, Ollama, HuggingFace, OpenRouter
- **Production Database Support**: PostgreSQL + pgvector
- **Comprehensive Error Handling**: Custom exception hierarchy with detailed logging
- **Health Monitoring**: System diagnostics and status reporting

### ⚡ **Performance Optimized**
- **pgvector Integration**: Hardware-accelerated vector operations
- **Intelligent Indexing**: Optimized database indexes for fast search
- **Background Processing**: Non-blocking document processing
- **Connection Pooling**: Scalable database connections

## 📖 Documentation Philosophy

This documentation is **implementation-driven** - every feature documented here is fully implemented and tested. We believe in accurate documentation that matches the actual capabilities of the system.

### What You'll Find Here:
- ✅ **Accurate Examples**: All code examples are tested and working
- ✅ **Production-Ready Guidance**: Real-world deployment and optimization advice
- ✅ **Complete Feature Coverage**: Documentation for all implemented features
- ✅ **Advanced Use Cases**: Enterprise scenarios and complex integrations

### What You Won't Find:
- ❌ **Vapor Features**: We don't document features that don't exist
- ❌ **Oversimplified Examples**: Our examples reflect real-world complexity
- ❌ **Marketing Fluff**: Technical accuracy over marketing copy

## 🤝 Getting Help

### Documentation Issues
If you find any discrepancies between the documentation and actual implementation, please file an issue. We maintain strict accuracy standards.

### Feature Requests
Ragdoll has many undocumented capabilities. Before requesting a feature, check if it already exists by reviewing the complete documentation.

### Support Channels
- **GitHub Issues**: Bug reports and feature requests
- **Documentation**: Comprehensive guides and references
- **Code Examples**: Working examples for all major features

## 🎯 Quick Navigation

**New to Ragdoll?** Start with:
1. [Quick Start Guide](quick-start.md) - Basic usage in 5 minutes
2. [Architecture Overview](architecture.md) - Understand the system design
3. [Multi-Modal Support](multi-modal.md) - See what makes us different

**Ready for Production?** Focus on:
1. [Production Deployment](deployment.md) - PostgreSQL setup
2. [Configuration Guide](configuration.md) - Enterprise configuration
3. [Performance Tuning](performance.md) - Optimization strategies

**Integrating with Existing Systems?** Review:
1. [API Reference](api-client.md) - Client interface methods
2. [LLM Integration](llm-integration.md) - Provider configuration
3. [Security Considerations](security.md) - Production security

---

*This documentation reflects the actual implementation of Ragdoll v0.1.0 and is updated with each release to maintain accuracy.*