# Changelog

All notable changes to the Ragdoll Core project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

*Note: These features will be included in the next release (likely v0.1.9) featuring comprehensive search tracking and analytics capabilities.*

### Added
- **Initial CHANGELOG**: Added comprehensive CHANGELOG.md following Keep a Changelog format
  - Complete version history from git log analysis
  - Feature status tracking (implemented vs planned)
  - Migration guides and breaking changes documentation
  - Structured release notes with proper categorization
- **Search Tracking System**: Comprehensive analytics with query embeddings, click-through tracking, and performance monitoring
  - Automatic search recording with vector embeddings for similarity analysis
  - Click-through rate tracking and user engagement monitoring
  - Session and user behavior tracking capabilities
  - Performance metrics including execution time and result quality analysis
  - Search similarity analysis using vector embeddings
  - Automatic cleanup of orphaned and unused searches
- **Enhanced README**: Updated documentation with search tracking examples and analytics usage
  - Comprehensive search analytics examples and usage patterns
  - Updated API examples to use proper top-level Ragdoll methods
  - Added search tracking configuration and usage examples
- **API Method Consistency**: Added `hybrid_search` delegation to top-level Ragdoll namespace
  - Complete documentation with examples and parameter descriptions
  - Consistent API experience across all search methods
  - Verified method availability at both Ragdoll and Ragdoll::Core levels

### Fixed
- **Model Resolution Warning**: Fixed "undefined method 'empty?' for an instance of Ragdoll::Core::Model" warning
  - Added defensive `empty?` method to Model class
  - Enhanced constructor to handle polymorphic Model objects
  - Added nil/empty checks in embedding service

### Changed
- **Test Coverage**: Added coverage directory to .gitignore for cleaner repository state

### Technical Details
- Commits: `9186067`, `cb952d3`, `e902a5f`, `632527b` 
- All changes maintain backward compatibility
- No breaking API changes

## [0.1.8] - 2025-01-04

### Added
- **Search Analytics Foundation**: Added `Ragdoll::Search` model with query embedding and result tracking capabilities
- **Embedding Service Enhancements**: Fallback mechanism for model resolution in embedding service
- **Test Coverage**: Added coverage directory to gitignore and improved test infrastructure

### Changed
- Updated Gemfile.lock with latest gem versions
- Enhanced runtime dependencies and version management

### Fixed
- Package directory exclusion in gitignore

## [0.1.7] - 2025-01-04

### Added
- **Multi-Modal Content Models**: Added AudioContent model for comprehensive audio processing support
- **Background Job Processing**: New Ragdoll job classes for asynchronous document processing
- **Metadata Schemas**: Structured metadata schemas for text and image documents with validation

### Changed
- Updated ragdoll gem dependencies
- Improved submodule management for documentation

## [0.1.6] - 2025-01-04

### Added
- **Documentation Restructure**: Replaced local docs with ragdoll-docs submodule
- **Conventional Commits**: Updated and restructured Conventional Commits specification
- **CI/CD Improvements**: Enhanced GitHub Actions workflow and dropped JRuby support for RMagick compatibility

### Fixed
- Test skipping logic for CI environments
- Automated release workflow adjustments

## [0.1.5] - 2025-01-04

### Added
- Enhanced document processing pipeline
- Improved error handling and logging

### Fixed
- Version management and release process refinements

## [0.1.4] - 2025-01-04

### Added
- Extended multi-modal architecture support
- Performance optimizations for large document processing

### Changed
- Refined version numbering and release process

## [0.1.3] - 2025-01-04

### Added
- **Core RAG Architecture**: Multi-modal RAG (Retrieval-Augmented Generation) library built on ActiveRecord
- **PostgreSQL + pgvector Integration**: High-performance semantic search with vector similarity
- **Polymorphic Content Architecture**: Unified handling of text, image, and audio content types
- **Dual Metadata Design**: Separation of LLM-generated content analysis and system file properties
- **Document Processing Pipeline**: Support for PDF, DOCX, HTML, Markdown, and plain text files
- **Embedding Generation**: Text chunking and vector embedding creation with multiple LLM provider support
- **Semantic Search**: Cosine similarity search with usage analytics
- **Background Processing**: ActiveJob integration for asynchronous document processing
- **Logging System**: Configurable file-based logging with multiple levels

### Technical Features
- **Database Schema**: Multi-modal polymorphic architecture optimized for PostgreSQL
- **IVFFlat Indexing**: Fast approximate nearest neighbor search for vector similarity
- **Connection Pooling**: High-concurrency support for production workloads
- **Configuration Management**: Comprehensive configuration system for LLM providers and processing settings

## [0.1.1] - 2024-12-XX

### Added
- Initial project structure and basic functionality
- Core document management capabilities
- Basic search and retrieval features

## [0.0.2] - 2024-12-XX

### Added
- Initial alpha release
- Basic RAG architecture foundation
- PostgreSQL database integration

---

## Feature Status

### ✅ Fully Implemented
- **Text Document Processing**: PDF, DOCX, HTML, Markdown, plain text files
- **Embedding Generation**: Text chunking and vector embedding creation
- **Database Schema**: Multi-modal polymorphic architecture with PostgreSQL + pgvector
- **Dual Metadata Architecture**: Separate LLM-generated content analysis and file properties
- **Search Functionality**: Semantic search with cosine similarity and usage analytics
- **Search Tracking System**: Comprehensive analytics with query embeddings, click-through tracking, and performance monitoring
- **Document Management**: Add, update, delete, list operations
- **Background Processing**: ActiveJob integration for async embedding generation
- **LLM Metadata Generation**: AI-powered structured content analysis with schema validation
- **Logging**: Configurable file-based logging with multiple levels

### 🚧 In Development
- **Image Processing**: Framework exists but vision AI integration needs completion
- **Audio Processing**: Framework exists but speech-to-text integration needs completion
- **Hybrid Search**: Combining semantic and full-text search capabilities

### 📋 Planned Features
- **Multi-modal Search**: Search across text, image, and audio content types
- **Content-type Specific Embedding Models**: Different models for text, image, audio
- **Enhanced Metadata Schemas**: Domain-specific metadata templates

---

## Migration Guide

### From 0.1.7 to 0.1.8
- New search tracking tables will be automatically created via migrations
- No breaking changes to existing API
- Search tracking is enabled by default but can be disabled per search

### From 0.1.6 to 0.1.7
- AudioContent model added - existing installations will auto-migrate
- New background job classes available for improved processing
- Metadata schemas provide enhanced validation

### From 0.1.5 to 0.1.6
- Documentation moved to submodule - update local references
- CI/CD improvements may affect development workflows
- JRuby support removed due to RMagick dependency

---

## Breaking Changes

### Version 0.1.6
- **JRuby Support Removed**: RMagick dependency incompatibility
- **Documentation Structure**: Local docs replaced with submodule

---

## Contributors

- **Dewayne VanHoozer** - Primary developer and maintainer

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

*This changelog is automatically maintained and reflects the actual implementation status of features.*