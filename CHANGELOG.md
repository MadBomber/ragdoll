# Changelog

All notable changes to the Ragdoll Core project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `MIT-LICENSE` file, so the gem now ships the license its gemspec declares; the stale `Thorfile` entry is dropped from `spec.files` (#29)

### Changed
- Development and CI `Gemfile.lock`: activerecord, activejob, activemodel and activesupport (8.1.1 to 8.1.4.1), addressable, concurrent-ruby, faraday, json, nokogiri and rubyzip move to newer patch or minor releases within their current majors (the gemspec is unchanged, so gem users are unaffected)
- Search filter conditions now use bound parameters: the keyword array filters in `Document.search_by_keywords`, `Document.search_by_keywords_all`, `Embedding.search_similar` and `Embedding.search_similar_with_stats`, and the status filter in `Document.search_content` and `UnifiedDocument.search_content`, build their SQL with bound values (`ARRAY[?]::text[]` and `sanitize_sql_array`) instead of string interpolation, consistent with the adjacent `document_type` handling
- Minimum Ruby version is now 3.3 (`required_ruby_version >= 3.3.0`); Ruby 3.2 reached end of life on 2026-03-31 and is dropped from the CI matrix (#38)
- `Search#click_through_rate` returns a percentage rounded to two places (50.0 rather than 0.5), consistent with `SearchResult.analytics` and `Search.search_analytics` (#12)

### Removed
- An unreachable second duplicate lookup in `DocumentManagement.add_document` (location plus `file_modified_at`), which ran only after the location-only lookup had found nothing and so could never match; duplicate detection behaves as before
- The `annotate` development dependency and `lib/tasks/annotate.rake` with its `annotate_models`, `annotate:models`, `remove_annotation`, `set_annotation_options` and `environment` rake tasks. annotate has no release that supports Rails 8, so Bundler fell back to annotate 2.6.5 (2014) and none of those tasks could annotate a model. The models carry no schema annotations

### Fixed
- `DocumentProcessor.create_document_from_file` no longer raises `NoMethodError` after saving the document (#22)
- `Ragdoll::Document#generate_metadata!` no longer raises `LoadError` on every call from a stale `require_relative` (#21)
- `reprocess_document` no longer raises `ArgumentError` when passed conversion options; the options now reach the document converter (#23)
- `Ragdoll::Core::Database.connected?` returns `false` instead of `nil` when no connection pool exists
- `Ragdoll::Core::Database.migration_paths` returns the gem's `db/migrate` directory instead of a nonexistent path one level above the gem root; `migrate!` now reads its migrations from `migration_paths`
- `Search.cleanup_old_unused_searches` no longer deletes an old search that has any clicked result, and returns the number of searches deleted rather than the number of result rows (#28)
- `EmbeddingService#generate_embeddings_batch` fallback no longer returns embeddings for blank or nil texts
- `Ragdoll::Core::Database.disconnect!` no longer raises `NoMethodError` on ActiveRecord 7.2 and later
- `DocumentConverter` now reaches `ImageToTextService` and `AudioToTextService`: image files failed with `ArgumentError` (options passed positionally), and audio files failed with `NameError` because `require "ragdoll"` never loaded `AudioToTextService`; both errors were rescued and a filename placeholder stored instead
- `ImageToTextService` builds its vision model again: the default primary options carried `detail_level:` into `RubyLLM.chat`, which rejected it as an unknown keyword, so images never reached the vision model; the service-only keys `temperature` and `detail_level` are no longer passed to `RubyLLM.chat`, and `detail_level` still shapes the prompt
- `PropositionService.extract` and `TagService.extract` work again without a custom extractor: the default extractors passed `messages:` to `RubyLLM.chat`, which ruby_llm 1.9 rejects as an unknown keyword, so every call raised; they now ask the chat for the prompt (#27)
- `ExtractKeywordsJob` stores the extracted keywords as an array; it joined them into one comma-separated string, which PostgreSQL parsed as an array literal and saved as garbled fragments in the `keywords` column
- Search tracking now records `hybrid_rrf`, `text_fallback` and `semantic_with_keywords` searches; `query_embedding` is nullable and text-fallback searches no longer store document ids as embedding results (#41)
- ragdoll loads on Ruby 4.1, where `tsort` is no longer a default gem: `tsort` is now a runtime dependency, because `simple_flow` requires it without declaring it. This also silences the Ruby 4.0 "tsort was loaded from the standard library" warning (#37)
- `TextGenerationService` configures ruby_llm again by delegating to `Config#configure_ruby_llm`, as `EmbeddingService` does. Its own `RubyLLM.configure` block called setters ruby_llm 1.9 does not have (such as `ollama_endpoint=`), so configuration always failed and summaries and keywords always used the non-LLM fallback (#34)
- Document enrichment stores a summary and keywords again: `DocumentEnrichmentWorkflow` called `TextGenerationService.summarize` and `.extract_keywords` as class methods, which do not exist, so both steps raised `NoMethodError`; it now calls `generate_summary` / `extract_keywords` on a `TextGenerationService` instance (#40)
- `DocumentProcessor.create_document_from_upload` no longer raises `NoMethodError` after saving the document; it extracts content from the upload itself instead of assigning a `document.file` attachment that `Ragdoll::Document` does not have (#22)
- `rake db:console` opens psql (or mysql) on the configured database as the configured user: it read `username` / `database`, but the database config keys are `user` / `name`. The arguments are now passed to `system` as an array. The MySQL branch of `db:drop` uses the same corrected keys (#36)
- README examples read `Ragdoll.search`, `add_document` and content-quality results in the shapes the API returns: search results come from `response[:results]`, the add result has no `content_preview`, quality comes from `UnifiedDocument#content_quality_score`, and the troubleshooting query names the `ragdoll_unified_contents` table (#55)
- `TimeframeExtractor` resolves "since X" to a range from the start of X until now, reading X in the past; it handed the whole phrase to Chronic, which ignored "since" and resolved X alone, often in the future (#54)
- `TextChunker` no longer moves the first letter of the next sentence onto the end of a chunk when it breaks at a sentence boundary; the next chunk now starts at the beginning of the word (#53)
- A configured OpenAI organization and project now reach ruby_llm: `Config#configure_ruby_llm` sets `openai_organization_id` / `openai_project_id` (the ruby_llm 1.9 names) instead of guarded setters that never existed, which silently dropped both values (#35)
- `Client#add_directory` (and `Ragdoll.add_directory`) reports files that `add_document` failed to add as `status: "error"` with the error message, and stores the document id rather than the whole result hash in `document_id:` (#33)
- `Client#add_tags` (and `Ragdoll::Core.add_tags`) no longer raises `ArgumentError`; it passes the document id and tags to `TagService.add_tags_to_document` positionally (#39). `DocumentEnrichmentWorkflow`'s tag step made the same call and raised on every document, so extracted tags were never stored; it is fixed the same way

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
