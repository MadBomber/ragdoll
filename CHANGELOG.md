# Changelog

All notable changes to the Ragdoll Core project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.12] - 2025-09-23

### Changed
- **BREAKING**: Complete architectural migration from multi-modal polymorphic to unified text-based RAG
  - All media types now converted to text before vectorization
  - Single embedding model for all content types instead of type-specific models
  - Simplified database schema with unified content storage
  - Removed Single Table Inheritance (STI) complexity

### Added
- **Unified Document Models**: New `UnifiedDocument` and `UnifiedContent` models
  - Single content model replacing TextContent, ImageContent, AudioContent
  - Content quality scoring system (0.0 to 1.0 scale)
  - Original media type tracking for cross-modal search

- **Text Conversion Services**: Comprehensive media-to-text conversion pipeline
  - `DocumentConverter`: Orchestrates conversion of all media types
  - `TextExtractionService`: Extracts text from PDF, DOCX, HTML, CSV, JSON, XML, YAML
  - `ImageToTextService`: AI-powered image descriptions using vision models
  - `AudioToTextService`: Speech-to-text transcription with multiple providers

- **Cross-Modal Search**: Find any media type through natural language queries
  - Search images by describing their visual content
  - Find audio by spoken topics in transcripts
  - Unified semantic search across all converted content

- **CSV and Structured Data Support**: New file format support
  - CSV files converted to readable key-value text
  - JSON and XML converted to hierarchical text representation
  - YAML processing with front matter extraction
  - Custom CSV parser handles complex quoting and encoding

- **Migration Services**: Tools for transitioning from multi-modal architecture
  - `MigrationService`: Migrates documents from old to new architecture
  - Batch migration with progress tracking
  - Content quality assessment and reporting
  - Migration validation and integrity checks

- **Content Quality Assessment**: Automatic quality scoring for converted content
  - Length-based scoring (optimal: 50-2000 words)
  - Media type weighting (text > documents > descriptions > placeholders)
  - Quality distribution analytics

### Configuration
- New `use_unified_content` configuration option
- Single `embedding_model` configuration replaces type-specific models
- `text_conversion` settings for image detail levels and audio providers
- Vision model configuration for image descriptions
- Audio transcription provider settings

### Database Schema Changes
- New `ragdoll_unified_documents` table
- New `ragdoll_unified_contents` table with quality scoring
- Simplified embeddings table structure
- Migration from polymorphic to unified schema

### API Changes
- `add_document` now converts all media types to text automatically
- Search methods work across all content types transparently
- New `UnifiedDocumentManagement` service for document operations
- Backward compatibility maintained through abstraction layer

### Performance Improvements
- Single embedding pipeline reduces complexity
- Unified search index improves query performance
- Cached text conversions avoid reprocessing
- Smaller vector storage requirements

### Documentation
- Updated README.md with unified architecture explanation
- New migration guide for transitioning systems
- Cross-modal search examples
- Content quality management documentation

## [0.1.11] - 2025-01-17

### Added
- **Force Option for Document Addition**: New `force` parameter in document management to override duplicate detection
  - Allows forced document addition even when duplicate titles exist
  - Enables overwriting existing documents when needed
  
### Fixed
- **Search Query Embedding**: Made `query_embedding` parameter optional in search methods
  - Improved flexibility for search operations that don't require embeddings
  - Better error handling for search queries without embeddings

### Changed
- **Database Setup**: Enhanced database role handling and setup procedures
  - Improved database connection configuration
  - Better handling of database roles and permissions
  
### Removed
- **Obsolete Migrations**: Removed outdated RagdollDocuments migration files
  - Cleaned up legacy migration structure
  - Streamlined database migration path

## [0.1.10] - 2025-01-15

### Changed
- Continued improvements to search performance and accuracy

### Added
- **Hybrid Search**: Complete implementation combining semantic and full-text search capabilities
  - Configurable weights for semantic vs text search (default: 70% semantic, 30% text)
  - Deduplication of results by document ID
  - Combined scoring system for unified result ranking
- **Full-text Search**: PostgreSQL full-text search with tsvector indexing
  - Per-word match ratio scoring (0.0 to 1.0)
  - GIN index for high-performance text search
  - Search across title, summary, keywords, and description fields
- **Enhanced Search API**: Complete search type delegation at top-level Ragdoll namespace
  - `Ragdoll.hybrid_search` method for combined semantic and text search
  - `Ragdoll::Document.search_content` for full-text search capabilities
  - Consistent parameter handling across all search methods

### Changed
- **Search Architecture**: Unified search interface supporting semantic, fulltext, and hybrid modes
- **Database Schema**: Added search_vector column with GIN indexing for full-text search performance

### Technical Details
- Full-text search uses PostgreSQL's built-in tsvector capabilities
- Hybrid search combines cosine similarity (semantic) with text match ratios
- Results are ranked by weighted combined scores
- All search methods maintain backward compatibility

## [0.1.9] - 2025-01-10

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
- **Unified Text-Based RAG**: All media types converted to searchable text before vectorization
- **Cross-Modal Search**: Find images through descriptions, audio through transcripts, documents through content
- **Text Document Processing**: PDF, DOCX, HTML, Markdown, CSV, JSON, XML, YAML files
- **Image Processing**: AI-powered image descriptions using vision models (GPT-4 Vision, Claude 3, etc.)
- **Audio Processing**: Speech-to-text transcription (OpenAI Whisper, Azure Speech, Google Cloud Speech)
- **Embedding Generation**: Single text embedding model for all content types
- **Database Schema**: Unified content architecture with PostgreSQL + pgvector
- **Content Quality Assessment**: Automatic quality scoring for converted content
- **Search Functionality**: Semantic search with cosine similarity and usage analytics
- **Hybrid Search**: Complete implementation combining semantic and full-text search with configurable weights
- **Full-text Search**: PostgreSQL tsvector-based text search with GIN indexing
- **Search Tracking System**: Comprehensive analytics with query embeddings, click-through tracking, and performance monitoring
- **Document Management**: Add, update, delete, list operations with unified pipeline
- **Migration Services**: Tools for transitioning from multi-modal to unified architecture
- **Background Processing**: ActiveJob integration for async embedding generation
- **LLM Metadata Generation**: AI-powered structured content analysis with schema validation
- **Logging**: Configurable file-based logging with multiple levels

### 🚧 In Development
- **Video Processing**: Framework for extracting audio tracks and keyframes
- **Enhanced Quality Scoring**: Machine learning-based quality assessment

### 📋 Planned Features
- **Advanced Text Conversion**: OCR for scanned documents, handwriting recognition
- **Multi-language Support**: Transcription and translation for non-English content
- **Enhanced Metadata Schemas**: Domain-specific metadata templates

---

## Migration Guide

### From 0.1.11 to 0.1.12 - Unified Text-Based RAG Architecture
- **BREAKING CHANGE**: Complete architectural shift from multi-modal to unified text-based RAG
- **Database Migration Required**: New schema with UnifiedDocument and UnifiedContent models
- **Configuration Changes**:
  - Set `config.use_unified_content = true` to enable new architecture
  - Replace type-specific embedding models with single `config.embedding_model`
  - Configure text conversion settings for images and audio
- **Model Changes**:
  - TextContent, ImageContent, AudioContent replaced by UnifiedContent
  - Document model replaced by UnifiedDocument
  - Polymorphic relationships simplified to direct associations
- **API Compatibility**:
  - Existing `add_document` and `search` methods continue to work
  - New cross-modal search capabilities automatically enabled
  - Content type filtering deprecated (all content is now text)
- **Migration Process**:
  ```ruby
  # Use MigrationService to migrate existing documents
  migration_service = Ragdoll::MigrationService.new
  results = Ragdoll::MigrationService.migrate_all_documents(
    batch_size: 50,
    process_embeddings: true
  )
  ```
- **Benefits**:
  - Simplified architecture with single embedding model
  - Cross-modal search (find images by description, audio by transcript)
  - Better search results through unified text representation
  - Reduced storage and API costs

### From 0.1.9 to 0.1.10
- **New Search Methods**: `Ragdoll.hybrid_search` and `Ragdoll::Document.search_content` methods now available
- **Database Migration**: New search_vector column added to documents table with GIN index for full-text search
- **API Enhancement**: All search methods now support unified parameter interface
- **Backward Compatibility**: Existing `Ragdoll.search` method unchanged, continues to work as before
- **CLI Integration**: ragdoll-cli now requires ragdoll >= 0.1.10 for hybrid and full-text search support

### From 0.1.8 to 0.1.9
- **CHANGELOG Addition**: Comprehensive changelog and feature tracking added
- **API Method Consistency**: `hybrid_search` method properly delegated to top-level namespace
- **No Breaking Changes**: All existing functionality remains compatible

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

### Version 0.1.12
- **Architecture Change**: Complete migration from multi-modal polymorphic to unified text-based RAG
- **Model Restructure**: TextContent, ImageContent, AudioContent models replaced by UnifiedContent
- **Configuration**: Type-specific embedding models replaced by single embedding model
- **Database Schema**: New unified schema requires migration from polymorphic structure

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
