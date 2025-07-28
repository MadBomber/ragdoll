# File Upload System

Ragdoll implements a robust file upload and management system using the Shrine gem, providing secure, scalable file handling with multi-modal content support. The system handles documents, images, and audio files through a unified interface with comprehensive validation and processing capabilities.

## Shrine-based Production File Handling

The file upload system is built around Shrine's flexible architecture, offering:

- **Multi-Modal Support**: Dedicated uploaders for text documents, images, and audio files
- **Storage Flexibility**: Configurable backends (filesystem, S3, Google Cloud, Azure)
- **Security Focus**: Comprehensive file validation, MIME type checking, and size limits
- **Processing Pipeline**: Integration with content extraction and embedding generation
- **Metadata Extraction**: Automatic file property detection and storage
- **Production Ready**: Designed for high-volume, concurrent file processing

## Shrine Integration

Shrine provides the foundation for all file operations in Ragdoll, with specialized configurations for different content types.

### Core Configuration

```ruby
# lib/ragdoll/core/shrine_config.rb
require "shrine"
require "shrine/storage/file_system"

# Configure Shrine with filesystem storage
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("tmp/uploads", prefix: "cache"),
  store: Shrine::Storage::FileSystem.new("uploads")
}

# Essential plugins for Ragdoll functionality
Shrine.plugin :activerecord           # ActiveRecord integration
Shrine.plugin :cached_attachment_data # Handle cached file data
Shrine.plugin :restore_cached_data    # Restore cached attachments
Shrine.plugin :rack_file             # Handle Rack file uploads
Shrine.plugin :validation_helpers     # File validation utilities
Shrine.plugin :determine_mime_type    # Automatic MIME type detection
```

### Storage Backend Configuration

**Filesystem Storage (Development/Small Scale):**
```ruby
# Basic filesystem configuration
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("tmp/uploads", prefix: "cache"),
  store: Shrine::Storage::FileSystem.new("public/uploads")
}

# With custom directory structure
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new(
    "tmp/ragdoll_cache", 
    prefix: "cache",
    permissions: 0644
  ),
  store: Shrine::Storage::FileSystem.new(
    "storage/ragdoll_files",
    prefix: "files",
    permissions: 0644
  )
}
```

**Amazon S3 Storage (Production Recommended):**
```ruby
# Gemfile
gem "aws-sdk-s3", "~> 1.14"

# Configuration
require "shrine/storage/s3"

Shrine.storages = {
  cache: Shrine::Storage::S3.new(
    bucket: ENV['S3_CACHE_BUCKET'],
    region: ENV['AWS_REGION'],
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    prefix: "ragdoll/cache"
  ),
  store: Shrine::Storage::S3.new(
    bucket: ENV['S3_STORAGE_BUCKET'],
    region: ENV['AWS_REGION'],
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    prefix: "ragdoll/files",
    public: false  # Private files for security
  )
}

# S3-specific plugins
Shrine.plugin :presign_endpoint  # Generate presigned URLs
Shrine.plugin :upload_endpoint   # Direct uploads to S3
```

**Google Cloud Storage:**
```ruby
# Gemfile
gem "google-cloud-storage", "~> 1.11"

# Configuration
require "shrine/storage/google_cloud_storage"

Shrine.storages = {
  cache: Shrine::Storage::GoogleCloudStorage.new(
    bucket: ENV['GCS_CACHE_BUCKET'],
    project: ENV['GOOGLE_CLOUD_PROJECT'],
    credentials: ENV['GOOGLE_CLOUD_KEYFILE'],
    prefix: "ragdoll/cache"
  ),
  store: Shrine::Storage::GoogleCloudStorage.new(
    bucket: ENV['GCS_STORAGE_BUCKET'],
    project: ENV['GOOGLE_CLOUD_PROJECT'],
    credentials: ENV['GOOGLE_CLOUD_KEYFILE'],
    prefix: "ragdoll/files"
  )
}
```

### Content-Specific Uploaders

Ragdoll defines specialized uploaders for different content types:

```ruby
# File uploader for documents (PDF, DOCX, TXT, etc.)
class FileUploader < Shrine
  plugin :validation_helpers
  plugin :determine_mime_type
  plugin :add_metadata
  
  # Add custom metadata extraction
  add_metadata :custom_properties do |io|
    {
      original_filename: extract_filename(io),
      file_signature: calculate_file_signature(io),
      processing_metadata: extract_processing_hints(io)
    }
  end

  Attacher.validate do
    validate_max_size 50.megabytes
    validate_mime_type %w[
      application/pdf
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      text/plain
      text/html
      text/markdown
      application/json
      application/rtf
      application/msword
    ]
    validate_extension %w[pdf docx txt html md json rtf doc]
  end
  
  private
  
  def extract_filename(io)
    io.respond_to?(:original_filename) ? io.original_filename : nil
  end
  
  def calculate_file_signature(io)
    require 'digest'
    Digest::SHA256.hexdigest(io.read).tap { io.rewind }
  end
end

# Image uploader for visual content
class ImageUploader < Shrine
  plugin :validation_helpers
  plugin :determine_mime_type
  plugin :store_dimensions  # Extract image dimensions
  plugin :add_metadata
  
  add_metadata :image_analysis do |io|
    {
      color_profile: extract_color_profile(io),
      has_transparency: detect_transparency(io),
      estimated_quality: assess_image_quality(io)
    }
  end

  Attacher.validate do
    validate_max_size 10.megabytes
    validate_mime_type %w[
      image/jpeg
      image/png
      image/gif
      image/webp
      image/bmp
      image/tiff
      image/svg+xml
    ]
    validate_extension %w[jpg jpeg png gif webp bmp tiff svg]
    
    # Custom validations
    validate :acceptable_resolution
    validate :safe_image_content
  end
  
  private
  
  def acceptable_resolution
    return unless file
    
    width, height = file[:metadata]["width"], file[:metadata]["height"]
    if width && height
      total_pixels = width * height
      errors << "Image resolution too high (#{total_pixels} pixels)" if total_pixels > 50_000_000
      errors << "Image too small (#{width}x#{height})" if width < 10 || height < 10
    end
  end
end

# Audio uploader for audio content
class AudioUploader < Shrine
  plugin :validation_helpers
  plugin :determine_mime_type
  plugin :add_metadata
  
  add_metadata :audio_properties do |io|
    {
      duration: extract_audio_duration(io),
      sample_rate: extract_sample_rate(io),
      channels: extract_channel_count(io),
      bitrate: extract_bitrate(io)
    }
  end

  Attacher.validate do
    validate_max_size 100.megabytes
    validate_mime_type %w[
      audio/mpeg
      audio/wav
      audio/mp4
      audio/webm
      audio/ogg
      audio/flac
      audio/aac
      audio/x-wav
    ]
    validate_extension %w[mp3 wav m4a webm ogg flac aac]
    
    # Audio-specific validations
    validate :acceptable_duration
    validate :acceptable_quality
  end
  
  private
  
  def acceptable_duration
    return unless file
    
    duration = file[:metadata]["audio_properties"]&.dig("duration")
    if duration
      errors << "Audio too long (#{duration}s)" if duration > 3600 # 1 hour max
      errors << "Audio too short (#{duration}s)" if duration < 1   # 1 second min
    end
  end
end
```

### Processing Pipelines

Integrated processing workflows with background jobs:

```ruby
# Processing pipeline integration
module Ragdoll
  module Core
    module FileProcessing
      def self.process_uploaded_file(content_model)
        case content_model.type
        when 'Ragdoll::Core::Models::TextContent'
          process_text_file(content_model)
        when 'Ragdoll::Core::Models::ImageContent'
          process_image_file(content_model)
        when 'Ragdoll::Core::Models::AudioContent'
          process_audio_file(content_model)
        end
      end
      
      private
      
      def self.process_text_file(text_content)
        # Extract text content from file
        if text_content.data.present?
          extracted_text = extract_text_from_file(text_content.data)
          text_content.update!(content: extracted_text)
          
          # Queue embedding generation
          Ragdoll::Core::Jobs::GenerateEmbeddings.perform_later(
            text_content.document_id
          )
        end
      end
      
      def self.process_image_file(image_content)
        # Generate image description using vision AI
        if image_content.data.present?
          description = generate_image_description(image_content.data)
          image_content.update!(content: description) # Store description in content field
          
          # Queue embedding generation for the description
          Ragdoll::Core::Jobs::GenerateEmbeddings.perform_later(
            image_content.document_id
          )
        end
      end
      
      def self.process_audio_file(audio_content)
        # Transcribe audio to text
        if audio_content.data.present?
          transcript = transcribe_audio(audio_content.data)
          audio_content.update!(content: transcript) # Store transcript in content field
          
          # Queue embedding generation for the transcript
          Ragdoll::Core::Jobs::GenerateEmbeddings.perform_later(
            audio_content.document_id
          )
        end
      end
    end
  end
end

# Automatic processing triggers
module Ragdoll
  module Core
    module Models
      class Content < ActiveRecord::Base
        # Trigger processing after file attachment
        after_commit :process_file_if_attached, on: [:create, :update]
        
        private
        
        def process_file_if_attached
          if data_previously_changed? && data.present?
            FileProcessing.process_uploaded_file(self)
          end
        end
      end
    end
  end
end
```

## Supported File Types

Ragdoll provides comprehensive support for multiple file formats across text, image, and audio content types.

### Text Documents

Extensive document format support with intelligent content extraction:

**Primary Formats:**
```ruby
SUPPORTED_TEXT_FORMATS = {
  'application/pdf' => {
    extensions: ['.pdf'],
    max_size: 50.megabytes,
    extraction_method: :pdf_reader,
    features: [:text_extraction, :metadata_extraction, :page_analysis]
  },
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => {
    extensions: ['.docx'],
    max_size: 25.megabytes,
    extraction_method: :docx_parser,
    features: [:text_extraction, :formatting_preservation, :image_extraction]
  },
  'text/plain' => {
    extensions: ['.txt'],
    max_size: 5.megabytes,
    extraction_method: :direct_read,
    features: [:encoding_detection, :charset_conversion]
  },
  'text/html' => {
    extensions: ['.html', '.htm'],
    max_size: 10.megabytes,
    extraction_method: :html_parser,
    features: [:tag_stripping, :link_extraction, :metadata_extraction]
  },
  'text/markdown' => {
    extensions: ['.md', '.markdown'],
    max_size: 5.megabytes,
    extraction_method: :markdown_parser,
    features: [:structure_preservation, :link_extraction, :code_block_handling]
  },
  'application/json' => {
    extensions: ['.json'],
    max_size: 10.megabytes,
    extraction_method: :json_parser,
    features: [:structure_analysis, :key_value_extraction]
  }
}
```

**Extended Support:**
- **RTF Documents** (`.rtf`): Rich Text Format with formatting preservation
- **Legacy Word** (`.doc`): Microsoft Word 97-2003 format
- **CSV Files** (`.csv`): Structured data with column analysis
- **XML Files** (`.xml`): Structured markup with schema detection
- **YAML Files** (`.yml`, `.yaml`): Configuration and data files

**Content Extraction Examples:**
```ruby
# PDF text extraction with metadata
def extract_pdf_content(file_path)
  require 'pdf-reader'
  
  reader = PDF::Reader.new(file_path)
  content = {
    text: reader.pages.map(&:text).join("\n\n"),
    metadata: {
      page_count: reader.page_count,
      pdf_version: reader.pdf_version,
      info: reader.info,
      encrypted: reader.encrypted?
    }
  }
  
  content
end

# DOCX extraction with structure preservation
def extract_docx_content(file_path)
  require 'docx'
  
  doc = Docx::Document.open(file_path)
  {
    text: doc.paragraphs.map(&:text).join("\n"),
    metadata: {
      paragraph_count: doc.paragraphs.length,
      has_tables: doc.tables.any?,
      has_images: doc.images.any?,
      word_count: doc.paragraphs.map(&:text).join(' ').split.length
    }
  }
end
```

### Image Files

Comprehensive image format support with AI-powered content analysis:

**Supported Formats:**
```ruby
SUPPORTED_IMAGE_FORMATS = {
  'image/jpeg' => {
    extensions: ['.jpg', '.jpeg'],
    max_size: 10.megabytes,
    features: [:exif_extraction, :quality_assessment, :color_analysis]
  },
  'image/png' => {
    extensions: ['.png'],
    max_size: 15.megabytes,
    features: [:transparency_detection, :compression_analysis, :metadata_extraction]
  },
  'image/gif' => {
    extensions: ['.gif'],
    max_size: 20.megabytes,
    features: [:animation_detection, :frame_extraction, :color_palette_analysis]
  },
  'image/webp' => {
    extensions: ['.webp'],
    max_size: 10.megabytes,
    features: [:modern_compression, :quality_optimization', :animation_support]
  },
  'image/svg+xml' => {
    extensions: ['.svg'],
    max_size: 2.megabytes,
    features: [:vector_analysis, :text_extraction, :element_parsing]
  },
  'image/tiff' => {
    extensions: ['.tiff', '.tif'],
    max_size: 50.megabytes,
    features: [:multi_page_support, :high_quality_preservation, :metadata_rich]
  },
  'image/bmp' => {
    extensions: ['.bmp'],
    max_size: 25.megabytes,
    features: [:uncompressed_quality, :color_depth_analysis]
  }
}
```

**AI-Powered Image Analysis:**
```ruby
module Ragdoll
  module Core
    class ImageAnalyzer
      def self.analyze_image(image_file)
        {
          description: generate_description(image_file),
          objects_detected: detect_objects(image_file),
          text_content: extract_text_ocr(image_file),
          visual_features: analyze_visual_features(image_file),
          metadata: extract_technical_metadata(image_file)
        }
      end
      
      private
      
      def self.generate_description(image_file)
        # Integration with vision AI services
        # OpenAI GPT-4 Vision, Google Vision AI, etc.
        "A detailed description of the image content"
      end
      
      def self.detect_objects(image_file)
        # Object detection using AI models
        [
          { object: 'person', confidence: 0.95, bbox: [10, 20, 100, 200] },
          { object: 'building', confidence: 0.87, bbox: [150, 30, 300, 250] }
        ]
      end
      
      def self.extract_text_ocr(image_file)
        # OCR text extraction for images with text
        "Text found in image through OCR"
      end
    end
  end
end
```

### Audio Files

Comprehensive audio format support with transcription and analysis:

**Supported Formats:**
```ruby
SUPPORTED_AUDIO_FORMATS = {
  'audio/mpeg' => {
    extensions: ['.mp3'],
    max_size: 100.megabytes,
    max_duration: 3600, # 1 hour
    features: [:id3_metadata, :variable_bitrate, :wide_compatibility]
  },
  'audio/wav' => {
    extensions: ['.wav'],
    max_size: 500.megabytes,
    max_duration: 3600,
    features: [:uncompressed_quality, :professional_standard, :metadata_support]
  },
  'audio/mp4' => {
    extensions: ['.m4a', '.mp4'],
    max_size: 150.megabytes,
    max_duration: 3600,
    features: [:aac_compression, :chapter_support, :metadata_rich]
  },
  'audio/webm' => {
    extensions: ['.webm'],
    max_size: 100.megabytes,
    max_duration: 3600,
    features: [:web_optimized, :open_standard, :good_compression]
  },
  'audio/ogg' => {
    extensions: ['.ogg'],
    max_size: 100.megabytes,
    max_duration: 3600,
    features: [:open_source, :good_quality, :vorbis_codec]
  },
  'audio/flac' => {
    extensions: ['.flac'],
    max_size: 1000.megabytes,
    max_duration: 3600,
    features: [:lossless_compression, :high_quality, :metadata_support]
  },
  'audio/aac' => {
    extensions: ['.aac'],
    max_size: 100.megabytes,
    max_duration: 3600,
    features: [:efficient_compression, :good_quality, :mobile_optimized]
  }
}
```

**Audio Processing and Transcription:**
```ruby
module Ragdoll
  module Core
    class AudioProcessor
      def self.process_audio(audio_file)
        {
          transcript: transcribe_audio(audio_file),
          metadata: extract_audio_metadata(audio_file),
          analysis: analyze_audio_content(audio_file),
          quality_metrics: assess_audio_quality(audio_file)
        }
      end
      
      private
      
      def self.transcribe_audio(audio_file)
        # Integration with speech-to-text services
        # OpenAI Whisper, Google Speech-to-Text, AWS Transcribe
        {
          text: "Transcribed text from audio",
          confidence: 0.95,
          language: 'en',
          timestamps: [
            { start: 0.0, end: 5.2, text: "Hello, this is the beginning" },
            { start: 5.2, end: 10.1, text: "of the audio transcription" }
          ]
        }
      end
      
      def self.extract_audio_metadata(audio_file)
        # Extract technical and ID3 metadata
        {
          duration: 180.5, # seconds
          sample_rate: 44100,
          channels: 2,
          bitrate: 320, # kbps
          format: 'MP3',
          id3_tags: {
            title: 'Audio Title',
            artist: 'Artist Name',
            album: 'Album Name',
            year: 2024
          }
        }
      end
      
      def self.analyze_audio_content(audio_file)
        # Audio content analysis (speech patterns, music detection, etc.)
        {
          content_type: 'speech', # speech, music, mixed, silence
          speech_segments: 15,
          music_segments: 0,
          silence_percentage: 5.2,
          dominant_language: 'english',
          speaker_count: 2,
          audio_quality: 'high'
        }
      end
    end
  end
end
```

## File Validation

Comprehensive file validation ensures security, quality, and system stability through multiple validation layers.

### Multi-Layer Validation System

```ruby
module Ragdoll
  module Core
    module FileValidation
      class ValidationEngine
        VALIDATION_LAYERS = [
          :basic_file_checks,
          :mime_type_validation,
          :file_size_validation,
          :security_scanning,
          :content_validation,
          :malware_detection
        ]
        
        def self.validate_file(file, content_type)
          results = {
            valid: true,
            errors: [],
            warnings: [],
            metadata: {}
          }
          
          VALIDATION_LAYERS.each do |layer|
            layer_result = send(layer, file, content_type)
            
            results[:errors].concat(layer_result[:errors])
            results[:warnings].concat(layer_result[:warnings])
            results[:metadata].merge!(layer_result[:metadata])
            
            # Stop validation if critical errors found
            if layer_result[:errors].any? { |e| e[:severity] == :critical }
              results[:valid] = false
              break
            end
          end
          
          results[:valid] = results[:errors].empty?
          results
        end
        
        private
        
        def self.basic_file_checks(file, content_type)
          errors = []
          warnings = []
          metadata = {}
          
          # File existence and readability
          unless file.respond_to?(:read)
            errors << { message: 'File is not readable', severity: :critical }
            return { errors: errors, warnings: warnings, metadata: metadata }
          end
          
          # File size basic check
          if file.respond_to?(:size) && file.size == 0
            errors << { message: 'File is empty', severity: :critical }
          end
          
          # Extract basic metadata
          metadata[:original_filename] = file.original_filename if file.respond_to?(:original_filename)
          metadata[:content_type] = file.content_type if file.respond_to?(:content_type)
          metadata[:file_size] = file.size if file.respond_to?(:size)
          
          { errors: errors, warnings: warnings, metadata: metadata }
        end
        
        def self.mime_type_validation(file, content_type)
          errors = []
          warnings = []
          metadata = {}
          
          # Determine actual MIME type
          actual_mime_type = Marcel::MimeType.for(file)
          declared_mime_type = file.content_type if file.respond_to?(:content_type)
          
          metadata[:actual_mime_type] = actual_mime_type
          metadata[:declared_mime_type] = declared_mime_type
          
          # Get allowed MIME types for content type
          allowed_types = get_allowed_mime_types(content_type)
          
          unless allowed_types.include?(actual_mime_type)
            errors << {
              message: "Unsupported file type: #{actual_mime_type}",
              severity: :critical,
              allowed_types: allowed_types
            }
          end
          
          # Check for MIME type spoofing
          if declared_mime_type && declared_mime_type != actual_mime_type
            warnings << {
              message: "MIME type mismatch: declared #{declared_mime_type}, actual #{actual_mime_type}",
              severity: :medium
            }
          end
          
          { errors: errors, warnings: warnings, metadata: metadata }
        end
        
        def self.file_size_validation(file, content_type)
          errors = []
          warnings = []
          metadata = {}
          
          file_size = file.size if file.respond_to?(:size)
          return { errors: errors, warnings: warnings, metadata: metadata } unless file_size
          
          size_limits = get_size_limits(content_type)
          
          if file_size > size_limits[:max_size]
            errors << {
              message: "File too large: #{file_size} bytes (max: #{size_limits[:max_size]})",
              severity: :critical
            }
          end
          
          if file_size < size_limits[:min_size]
            warnings << {
              message: "File very small: #{file_size} bytes (min recommended: #{size_limits[:min_size]})",
              severity: :low
            }
          end
          
          metadata[:size_category] = categorize_file_size(file_size)
          
          { errors: errors, warnings: warnings, metadata: metadata }
        end
        
        def self.security_scanning(file, content_type)
          errors = []
          warnings = []
          metadata = {}
          
          # File signature validation
          file_signature = read_file_signature(file)
          metadata[:file_signature] = file_signature
          
          if suspicious_file_signature?(file_signature)
            errors << {
              message: "Suspicious file signature detected",
              severity: :critical
            }
          end
          
          # Embedded content scanning
          if content_type == 'document'
            embedded_content = scan_for_embedded_content(file)
            
            if embedded_content[:has_macros]
              warnings << {
                message: "Document contains macros",
                severity: :medium
              }
            end
            
            if embedded_content[:has_external_links]
              warnings << {
                message: "Document contains external links",
                severity: :low
              }
            end
            
            metadata[:embedded_content] = embedded_content
          end
          
          { errors: errors, warnings: warnings, metadata: metadata }
        end
        
        def self.content_validation(file, content_type)
          errors = []
          warnings = []
          metadata = {}
          
          case content_type
          when 'document'
            validate_document_content(file, errors, warnings, metadata)
          when 'image'
            validate_image_content(file, errors, warnings, metadata)
          when 'audio'
            validate_audio_content(file, errors, warnings, metadata)
          end
          
          { errors: errors, warnings: warnings, metadata: metadata }
        end
        
        def self.malware_detection(file, content_type)
          errors = []
          warnings = []
          metadata = {}
          
          # Integration with antivirus services
          if ENV['CLAMAV_ENABLED'] == 'true'
            scan_result = scan_with_clamav(file)
            
            if scan_result[:infected]
              errors << {
                message: "Malware detected: #{scan_result[:virus_name]}",
                severity: :critical
              }
            end
            
            metadata[:malware_scan] = scan_result
          end
          
          # Behavioral analysis for suspicious files
          behavioral_analysis = analyze_file_behavior(file)
          metadata[:behavioral_analysis] = behavioral_analysis
          
          if behavioral_analysis[:suspicious_score] > 0.7
            warnings << {
              message: "File shows suspicious characteristics",
              severity: :medium,
              details: behavioral_analysis
            }
          end
          
          { errors: errors, warnings: warnings, metadata: metadata }
        end
        
        # Helper methods
        def self.get_allowed_mime_types(content_type)
          case content_type
          when 'document'
            %w[
              application/pdf
              application/vnd.openxmlformats-officedocument.wordprocessingml.document
              text/plain
              text/html
              text/markdown
              application/json
            ]
          when 'image'
            %w[
              image/jpeg
              image/png
              image/gif
              image/webp
              image/bmp
              image/tiff
              image/svg+xml
            ]
          when 'audio'
            %w[
              audio/mpeg
              audio/wav
              audio/mp4
              audio/webm
              audio/ogg
              audio/flac
              audio/aac
            ]
          else
            []
          end
        end
        
        def self.get_size_limits(content_type)
          case content_type
          when 'document'
            { min_size: 10, max_size: 50.megabytes }
          when 'image'
            { min_size: 100, max_size: 10.megabytes }
          when 'audio'
            { min_size: 1000, max_size: 100.megabytes }
          else
            { min_size: 1, max_size: 10.megabytes }
          end
        end
      end
    end
  end
end
```

### Specialized Validation Rules

**Document-Specific Validation:**
```ruby
def validate_document_content(file, errors, warnings, metadata)
  begin
    case Marcel::MimeType.for(file)
    when 'application/pdf'
      pdf_validation = validate_pdf_document(file)
      errors.concat(pdf_validation[:errors])
      warnings.concat(pdf_validation[:warnings])
      metadata.merge!(pdf_validation[:metadata])
      
    when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      docx_validation = validate_docx_document(file)
      errors.concat(docx_validation[:errors])
      warnings.concat(docx_validation[:warnings])
      metadata.merge!(docx_validation[:metadata])
    end
  rescue => e
    errors << {
      message: "Document validation failed: #{e.message}",
      severity: :high
    }
  end
end

def validate_pdf_document(file)
  errors = []
  warnings = []
  metadata = {}
  
  begin
    reader = PDF::Reader.new(file)
    
    # Check if PDF is encrypted
    if reader.encrypted?
      errors << {
        message: "PDF is password protected",
        severity: :critical
      }
    end
    
    # Check page count
    page_count = reader.page_count
    metadata[:page_count] = page_count
    
    if page_count > 1000
      warnings << {
        message: "PDF has many pages (#{page_count}), processing may be slow",
        severity: :low
      }
    end
    
    # Check PDF version
    pdf_version = reader.pdf_version
    metadata[:pdf_version] = pdf_version
    
    if pdf_version > 1.7
      warnings << {
        message: "PDF version #{pdf_version} may have compatibility issues",
        severity: :low
      }
    end
    
    # Check for text content
    has_text = reader.pages.any? { |page| page.text.strip.length > 0 }
    metadata[:has_extractable_text] = has_text
    
    unless has_text
      warnings << {
        message: "PDF appears to contain no extractable text (may be image-only)",
        severity: :medium
      }
    end
    
  rescue PDF::Reader::MalformedPDFError => e
    errors << {
      message: "PDF file is malformed: #{e.message}",
      severity: :critical
    }
  rescue => e
    errors << {
      message: "PDF validation error: #{e.message}",
      severity: :high
    }
  end
  
  { errors: errors, warnings: warnings, metadata: metadata }
end
```

**Image-Specific Validation:**
```ruby
def validate_image_content(file, errors, warnings, metadata)
  begin
    # Use ImageMagick or similar for image analysis
    image_info = extract_image_info(file)
    metadata.merge!(image_info)
    
    # Check image dimensions
    if image_info[:width] && image_info[:height]
      total_pixels = image_info[:width] * image_info[:height]
      
      if total_pixels > 50_000_000 # 50 megapixels
        warnings << {
          message: "Very high resolution image (#{image_info[:width]}x#{image_info[:height]})",
          severity: :medium
        }
      end
      
      if image_info[:width] < 50 || image_info[:height] < 50
        warnings << {
          message: "Very small image (#{image_info[:width]}x#{image_info[:height]})",
          severity: :low
        }
      end
    end
    
    # Check color depth
    if image_info[:bit_depth] && image_info[:bit_depth] > 16
      warnings << {
        message: "High bit depth (#{image_info[:bit_depth]}) may not be preserved",
        severity: :low
      }
    end
    
    # Check for transparency
    if image_info[:has_alpha]
      metadata[:supports_transparency] = true
    end
    
  rescue => e
    errors << {
      message: "Image validation error: #{e.message}",
      severity: :high
    }
  end
end
```

### Security Integration

**ClamAV Integration:**
```ruby
def scan_with_clamav(file)
  return { scanned: false, reason: 'ClamAV not available' } unless clamav_available?
  
  begin
    # Create temporary file for scanning
    temp_file = Tempfile.new('ragdoll_scan')
    temp_file.binmode
    temp_file.write(file.read)
    temp_file.close
    file.rewind
    
    # Run ClamAV scan
    result = `clamscan --no-summary --infected #{temp_file.path}`
    exit_code = $?.exitstatus
    
    scan_result = {
      scanned: true,
      infected: exit_code == 1,
      virus_name: nil,
      scan_output: result.strip
    }
    
    if scan_result[:infected]
      # Extract virus name from output
      if match = result.match(/: (.+) FOUND$/)
        scan_result[:virus_name] = match[1]
      end
    end
    
    scan_result
    
  rescue => e
    { scanned: false, error: e.message }
  ensure
    temp_file&.unlink
  end
end

def clamav_available?
  `which clamscan` && $?.success?
rescue
  false
end
```

**Behavioral Analysis:**
```ruby
def analyze_file_behavior(file)
  suspicious_score = 0.0
  indicators = []
  
  # Check file extension vs content mismatch
  if extension_content_mismatch?(file)
    suspicious_score += 0.3
    indicators << 'extension_mismatch'
  end
  
  # Check for unusual file patterns
  if unusual_file_pattern?(file)
    suspicious_score += 0.2
    indicators << 'unusual_pattern'
  end
  
  # Check for embedded executables
  if contains_embedded_executable?(file)
    suspicious_score += 0.5
    indicators << 'embedded_executable'
  end
  
  {
    suspicious_score: suspicious_score,
    indicators: indicators,
    risk_level: categorize_risk_level(suspicious_score)
  }
end

def categorize_risk_level(score)
  case score
  when 0...0.3 then 'low'
  when 0.3...0.6 then 'medium'
  when 0.6...0.8 then 'high'
  else 'critical'
  end
end
```

## Storage Configuration

Ragdoll supports multiple storage backends through Shrine's flexible architecture, enabling deployment across various infrastructure scenarios.

### Local Filesystem Storage

Ideal for development, testing, and small-scale deployments:

```ruby
# Basic filesystem configuration
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("tmp/uploads", prefix: "cache"),
  store: Shrine::Storage::FileSystem.new("public/uploads")
}

# Advanced filesystem configuration
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new(
    "tmp/ragdoll_cache",
    prefix: "cache",
    permissions: 0644,
    directory_permissions: 0755,
    clean: true  # Clean up empty directories
  ),
  store: Shrine::Storage::FileSystem.new(
    "storage/ragdoll_files",
    prefix: "#{Rails.env}/files",  # Environment-specific paths
    permissions: 0644,
    directory_permissions: 0755,
    host: "https://example.com"   # For generating URLs
  )
}

# Custom directory structure
class CustomFileSystem < Shrine::Storage::FileSystem
  def generate_location(io, **options)
    # Organize files by date and content type
    date_path = Date.current.strftime("%Y/%m/%d")
    content_type = options[:metadata]&.dig("mime_type") || "unknown"
    type_dir = content_type.split("/").first # e.g., "image", "audio", "application"
    
    "#{type_dir}/#{date_path}/#{super}"
  end
end

Shrine.storages = {
  cache: CustomFileSystem.new("tmp/uploads"),
  store: CustomFileSystem.new("storage/files")
}
```

**Filesystem Storage Benefits:**
- Simple setup and configuration
- No external dependencies
- Full control over file organization
- Easy backup and migration
- No API rate limits or costs

**Considerations:**
- Limited scalability
- Single point of failure
- No built-in CDN capabilities
- Requires local disk space management

### Amazon S3 Integration

Recommended for production deployments with scalability requirements:

```ruby
# Gemfile
gem "aws-sdk-s3", "~> 1.14"

# S3 configuration
require "shrine/storage/s3"

# Basic S3 setup
Shrine.storages = {
  cache: Shrine::Storage::S3.new(
    bucket: ENV['S3_CACHE_BUCKET'],
    region: ENV['AWS_REGION'],
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
  ),
  store: Shrine::Storage::S3.new(
    bucket: ENV['S3_STORAGE_BUCKET'],
    region: ENV['AWS_REGION'],
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
  )
}

# Advanced S3 configuration
Shrine.storages = {
  cache: Shrine::Storage::S3.new(
    bucket: ENV['S3_CACHE_BUCKET'],
    region: ENV['AWS_REGION'],
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    prefix: "ragdoll/cache/#{Rails.env}",
    public: false,
    upload: {
      server_side_encryption: "AES256",
      metadata_directive: "REPLACE"
    },
    signer: { expires_in: 1.hour } # Presigned URL expiration
  ),
  store: Shrine::Storage::S3.new(
    bucket: ENV['S3_STORAGE_BUCKET'],
    region: ENV['AWS_REGION'],
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    prefix: "ragdoll/files/#{Rails.env}",
    public: false,  # Private files for security
    upload: {
      server_side_encryption: "AES256",
      storage_class: "STANDARD_IA", # Infrequent Access for cost optimization
      metadata_directive: "REPLACE"
    },
    signer: { expires_in: 24.hours }
  )
}

# S3-specific plugins
Shrine.plugin :presign_endpoint, presign_options: -> (request) {
  {
    content_length_range: 0..50.megabytes,
    content_type: request.params["content_type"],
    expires_in: 1.hour
  }
}

Shrine.plugin :upload_endpoint, max_size: 50.megabytes
```

**S3 Lifecycle Management:**
```ruby
# S3 lifecycle configuration for cost optimization
class S3LifecycleManager
  def self.configure_lifecycle_rules
    s3_client = Aws::S3::Client.new(
      region: ENV['AWS_REGION'],
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )
    
    # Configure lifecycle rules
    lifecycle_configuration = {
      rules: [
        {
          id: 'ragdoll-cache-cleanup',
          status: 'Enabled',
          filter: { prefix: 'ragdoll/cache/' },
          expiration: { days: 1 }, # Delete cache files after 1 day
        },
        {
          id: 'ragdoll-files-archive',
          status: 'Enabled',
          filter: { prefix: 'ragdoll/files/' },
          transitions: [
            {
              days: 30,
              storage_class: 'STANDARD_IA' # Move to Infrequent Access after 30 days
            },
            {
              days: 90,
              storage_class: 'GLACIER' # Archive to Glacier after 90 days
            }
          ]
        }
      ]
    }
    
    s3_client.put_bucket_lifecycle_configuration(
      bucket: ENV['S3_STORAGE_BUCKET'],
      lifecycle_configuration: lifecycle_configuration
    )
  end
end
```

### Google Cloud Storage

Excellent alternative to S3 with similar features:

```ruby
# Gemfile
gem "google-cloud-storage", "~> 1.11"

# GCS configuration
require "shrine/storage/google_cloud_storage"

Shrine.storages = {
  cache: Shrine::Storage::GoogleCloudStorage.new(
    bucket: ENV['GCS_CACHE_BUCKET'],
    project: ENV['GOOGLE_CLOUD_PROJECT'],
    credentials: ENV['GOOGLE_CLOUD_KEYFILE'],
    prefix: "ragdoll/cache/#{Rails.env}",
    object_options: {
      cache_control: "public, max-age=3600",
      metadata: {
        environment: Rails.env,
        application: "ragdoll"
      }
    }
  ),
  store: Shrine::Storage::GoogleCloudStorage.new(
    bucket: ENV['GCS_STORAGE_BUCKET'],
    project: ENV['GOOGLE_CLOUD_PROJECT'],
    credentials: ENV['GOOGLE_CLOUD_KEYFILE'],
    prefix: "ragdoll/files/#{Rails.env}",
    default_acl: "private", # Private files for security
    object_options: {
      storage_class: "NEARLINE", # Cost-effective for infrequent access
      metadata: {
        environment: Rails.env,
        application: "ragdoll",
        retention_policy: "365days"
      }
    }
  )
}

# GCS-specific features
class GCSManager
  def self.setup_bucket_policies
    storage = Google::Cloud::Storage.new(
      project_id: ENV['GOOGLE_CLOUD_PROJECT'],
      credentials: ENV['GOOGLE_CLOUD_KEYFILE']
    )
    
    bucket = storage.bucket(ENV['GCS_STORAGE_BUCKET'])
    
    # Set up lifecycle management
    bucket.lifecycle do |l|
      l.add_rule {
        l.action :delete
        l.condition age: 365 # Delete files older than 1 year
        l.condition matches_prefix: "ragdoll/cache/"
      }
      
      l.add_rule {
        l.action :set_storage_class, storage_class: "COLDLINE"
        l.condition age: 90
        l.condition matches_prefix: "ragdoll/files/"
      }
    end
    
    # Enable uniform bucket-level access
    bucket.uniform_bucket_level_access = true
  end
end
```

### Azure Blob Storage

Integration with Microsoft Azure ecosystem:

```ruby
# Gemfile
gem "azure-storage-blob", "~> 2.0"

# Custom Azure storage implementation
class AzureBlobStorage
  def initialize(container:, account_name:, account_key:, **options)
    @container = container
    @client = Azure::Storage::Blob::BlobService.create(
      storage_account_name: account_name,
      storage_access_key: account_key
    )
    @prefix = options[:prefix]
    @public = options[:public] != false
  end
  
  def upload(io, id, shrine_metadata: {}, **options)
    content_type = shrine_metadata["mime_type"]
    
    @client.create_block_blob(
      @container,
      path(id),
      io.read,
      content_type: content_type,
      metadata: {
        "shrine_metadata" => JSON.generate(shrine_metadata),
        "ragdoll_version" => Ragdoll::Core::VERSION
      }
    )
  end
  
  def download(id)
    blob, content = @client.get_blob(@container, path(id))
    StringIO.new(content)
  end
  
  def exists?(id)
    @client.get_blob_properties(@container, path(id))
    true
  rescue Azure::Core::Http::HTTPError => e
    raise unless e.status_code == 404
    false
  end
  
  def delete(id)
    @client.delete_blob(@container, path(id))
  end
  
  def url(id, **options)
    if @public
      @client.generate_uri(path(id), @container)
    else
      # Generate SAS token for private access
      @client.generate_uri(path(id), @container, {
        permissions: "r",
        expiry: (Time.now + 1.hour).utc.iso8601
      })
    end
  end
  
  private
  
  def path(id)
    [@prefix, id].compact.join("/")
  end
end

# Azure configuration
Shrine.storages = {
  cache: AzureBlobStorage.new(
    container: ENV['AZURE_CACHE_CONTAINER'],
    account_name: ENV['AZURE_STORAGE_ACCOUNT'],
    account_key: ENV['AZURE_STORAGE_KEY'],
    prefix: "ragdoll/cache/#{Rails.env}",
    public: false
  ),
  store: AzureBlobStorage.new(
    container: ENV['AZURE_STORAGE_CONTAINER'],
    account_name: ENV['AZURE_STORAGE_ACCOUNT'],
    account_key: ENV['AZURE_STORAGE_KEY'],
    prefix: "ragdoll/files/#{Rails.env}",
    public: false
  )
}
```

### CDN Integration

Optimize file delivery with Content Delivery Networks:

**CloudFront (AWS) Integration:**
```ruby
# CloudFront configuration for S3
class CloudFrontIntegration
  def self.configure_distribution
    cloudfront = Aws::CloudFront::Client.new(
      region: 'us-east-1', # CloudFront is global but API is in us-east-1
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )
    
    distribution_config = {
      caller_reference: "ragdoll-#{Time.current.to_i}",
      aliases: {
        quantity: 1,
        items: [ENV['CDN_DOMAIN']] # e.g., cdn.example.com
      },
      default_root_object: "index.html",
      origins: {
        quantity: 1,
        items: [{
          id: "ragdoll-s3-origin",
          domain_name: "#{ENV['S3_STORAGE_BUCKET']}.s3.#{ENV['AWS_REGION']}.amazonaws.com",
          s3_origin_config: {
            origin_access_identity: "origin-access-identity/cloudfront/#{ENV['OAI_ID']}"
          }
        }]
      },
      default_cache_behavior: {
        target_origin_id: "ragdoll-s3-origin",
        viewer_protocol_policy: "redirect-to-https",
        trusted_signers: {
          enabled: false,
          quantity: 0
        },
        forwarded_values: {
          query_string: false,
          cookies: {
            forward: "none"
          }
        },
        min_ttl: 0,
        default_ttl: 86400, # 24 hours
        max_ttl: 31536000   # 1 year
      },
      comment: "Ragdoll file distribution",
      enabled: true,
      price_class: "PriceClass_100" # Use only North America and Europe edge locations
    }
    
    response = cloudfront.create_distribution(distribution_config: distribution_config)
    response.distribution.domain_name
  end
end

# URL generation with CDN
class CDNFileUploader < Shrine
  def self.cdn_url(file)
    if Rails.env.production? && ENV['CDN_DOMAIN']
      file.url.gsub(
        "#{ENV['S3_STORAGE_BUCKET']}.s3.#{ENV['AWS_REGION']}.amazonaws.com",
        ENV['CDN_DOMAIN']
      )
    else
      file.url
    end
  end
end
```

**Multi-CDN Strategy:**
```ruby
class MultiCDNManager
  CDN_PROVIDERS = {
    cloudflare: {
      domain: ENV['CLOUDFLARE_CDN_DOMAIN'],
      priority: 1
    },
    cloudfront: {
      domain: ENV['CLOUDFRONT_CDN_DOMAIN'],
      priority: 2
    },
    fastly: {
      domain: ENV['FASTLY_CDN_DOMAIN'],
      priority: 3
    }
  }
  
  def self.get_optimized_url(file, user_location: nil)
    # Select best CDN based on user location and CDN health
    best_cdn = select_optimal_cdn(user_location)
    
    if best_cdn && best_cdn[:domain]
      # Replace origin domain with CDN domain
      original_url = file.url
      cdn_url = original_url.gsub(
        /https:\/\/[^.]+\.s3\.[^.]+\.amazonaws\.com/,
        "https://#{best_cdn[:domain]}"
      )
      
      # Add cache busting and optimization parameters
      add_optimization_params(cdn_url, file)
    else
      file.url # Fallback to original URL
    end
  end
  
  private
  
  def self.select_optimal_cdn(user_location)
    # Health check CDNs and select best performing
    available_cdns = CDN_PROVIDERS.select { |name, config| 
      cdn_healthy?(config[:domain]) 
    }
    
    # Select based on priority and user location
    available_cdns.min_by { |name, config| config[:priority] }&.last
  end
  
  def self.cdn_healthy?(domain)
    # Simple health check
    begin
      response = Net::HTTP.get_response(URI("https://#{domain}/health"))
      response.code == '200'
    rescue
      false
    end
  end
  
  def self.add_optimization_params(url, file)
    # Add image optimization parameters for supported CDNs
    if file.metadata['mime_type']&.start_with?('image/')
      "#{url}?auto=compress,format&w=1200&q=85"
    else
      url
    end
  end
end
```

### Hybrid Storage Strategy

Combine multiple storage backends for optimal performance and cost:

```ruby
class HybridStorageManager
  def self.configure_hybrid_storage
    # Hot storage: Frequently accessed files (S3 Standard)
    hot_storage = Shrine::Storage::S3.new(
      bucket: ENV['S3_HOT_BUCKET'],
      region: ENV['AWS_REGION'],
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
      prefix: "ragdoll/hot",
      upload: { storage_class: "STANDARD" }
    )
    
    # Warm storage: Occasionally accessed files (S3 Standard-IA)
    warm_storage = Shrine::Storage::S3.new(
      bucket: ENV['S3_WARM_BUCKET'],
      region: ENV['AWS_REGION'],
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
      prefix: "ragdoll/warm",
      upload: { storage_class: "STANDARD_IA" }
    )
    
    # Cold storage: Rarely accessed files (S3 Glacier)
    cold_storage = Shrine::Storage::S3.new(
      bucket: ENV['S3_COLD_BUCKET'],
      region: ENV['AWS_REGION'],
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
      prefix: "ragdoll/cold",
      upload: { storage_class: "GLACIER" }
    )
    
    {
      cache: Shrine::Storage::FileSystem.new("tmp/uploads"),
      hot: hot_storage,
      warm: warm_storage,
      cold: cold_storage
    }
  end
  
  def self.migrate_files_by_usage
    # Move files between storage tiers based on access patterns
    
    # Move frequently accessed files to hot storage
    frequently_accessed = Ragdoll::Core::Models::Embedding
      .where('usage_count > ? AND returned_at > ?', 10, 30.days.ago)
      .includes(:embeddable)
    
    frequently_accessed.each do |embedding|
      content = embedding.embeddable
      if content.data.storage_key != :hot
        migrate_file_to_storage(content, :hot)
      end
    end
    
    # Move rarely accessed files to cold storage
    rarely_accessed = Ragdoll::Core::Models::Embedding
      .where('usage_count < ? AND (returned_at IS NULL OR returned_at < ?)', 2, 90.days.ago)
      .includes(:embeddable)
    
    rarely_accessed.each do |embedding|
      content = embedding.embeddable
      if content.data.storage_key == :hot
        migrate_file_to_storage(content, :cold)
      end
    end
  end
  
  private
  
  def self.migrate_file_to_storage(content, target_storage)
    # Download from current storage
    current_file = content.data
    
    # Upload to target storage
    new_file = content.data_attacher.upload(
      current_file.download,
      storage: target_storage
    )
    
    # Update content record
    content.update!(data: new_file)
    
    # Delete from old storage
    current_file.delete
  end
end
```

## File Processing Pipeline

Ragdoll implements a comprehensive file processing pipeline that ensures secure, efficient handling of uploaded files through multiple stages.

### Processing Workflow Overview

```mermaid
flowchart TD
    A[File Upload] --> B[Temporary Storage]
    B --> C[File Validation]
    C --> D{Validation Passed?}
    D -->|No| E[Reject Upload]
    D -->|Yes| F[Metadata Extraction]
    F --> G[Security Scanning]
    G --> H{Security Check?}
    H -->|Failed| I[Quarantine File]
    H -->|Passed| J[Content Processing]
    J --> K[Permanent Storage]
    K --> L[Database Record Creation]
    L --> M[Background Job Queuing]
    M --> N[Embedding Generation]
    N --> O[Content Analysis]
    O --> P[Processing Complete]
```

### Stage 1: File Upload and Temporary Storage

Initial file reception with immediate temporary storage:

```ruby
module Ragdoll
  module Core
    class FileUploadHandler
      def self.handle_upload(uploaded_file, document_id, content_type)
        upload_result = {
          success: false,
          file_id: nil,
          metadata: {},
          errors: [],
          processing_stages: []
        }
        
        begin
          # Stage 1: Temporary storage
          upload_result[:processing_stages] << {
            stage: 'temporary_storage',
            started_at: Time.current,
            status: 'started'
          }
          
          # Create temporary file with unique identifier
          temp_file_id = generate_temp_file_id
          temp_file = store_temporarily(uploaded_file, temp_file_id)
          
          upload_result[:file_id] = temp_file_id
          upload_result[:metadata][:temp_location] = temp_file.id
          upload_result[:metadata][:original_filename] = uploaded_file.original_filename
          upload_result[:metadata][:content_type] = uploaded_file.content_type
          upload_result[:metadata][:file_size] = uploaded_file.size
          
          upload_result[:processing_stages].last[:status] = 'completed'
          upload_result[:processing_stages].last[:completed_at] = Time.current
          
          # Proceed to validation
          validation_result = FileValidation::ValidationEngine.validate_file(
            temp_file, content_type
          )
          
          if validation_result[:valid]
            upload_result.merge!(process_validated_file(
              temp_file, document_id, content_type, upload_result
            ))
          else
            upload_result[:errors] = validation_result[:errors]
            cleanup_temp_file(temp_file)
          end
          
        rescue => e
          upload_result[:errors] << {
            stage: 'upload_handling',
            message: e.message,
            backtrace: e.backtrace&.first(5)
          }
          
          cleanup_temp_file(temp_file) if temp_file
        end
        
        upload_result
      end
      
      private
      
      def self.generate_temp_file_id
        "temp_#{SecureRandom.uuid}_#{Time.current.to_i}"
      end
      
      def self.store_temporarily(uploaded_file, temp_id)
        # Use cache storage for temporary files
        cache_storage = Shrine.storages[:cache]
        
        # Store with metadata
        cache_storage.upload(
          uploaded_file,
          temp_id,
          shrine_metadata: {
            'filename' => uploaded_file.original_filename,
            'mime_type' => uploaded_file.content_type,
            'size' => uploaded_file.size
          }
        )
        
        # Return Shrine uploaded file object
        Shrine::UploadedFile.new(
          id: temp_id,
          storage: :cache,
          metadata: {
            'filename' => uploaded_file.original_filename,
            'mime_type' => uploaded_file.content_type,
            'size' => uploaded_file.size
          }
        )
      end
    end
  end
end
```

### Stage 2: Validation and Security Checks

Comprehensive validation using the validation engine:

```ruby
def process_validated_file(temp_file, document_id, content_type, upload_result)
  # Stage 2: Validation and Security
  upload_result[:processing_stages] << {
    stage: 'validation_security',
    started_at: Time.current,
    status: 'started'
  }
  
  begin
    validation_result = FileValidation::ValidationEngine.validate_file(
      temp_file, content_type
    )
    
    upload_result[:metadata].merge!(validation_result[:metadata])
    
    if validation_result[:valid]
      upload_result[:processing_stages].last[:status] = 'completed'
      upload_result[:processing_stages].last[:completed_at] = Time.current
      upload_result[:processing_stages].last[:validation_warnings] = validation_result[:warnings]
      
      # Proceed to metadata extraction
      metadata_result = extract_comprehensive_metadata(temp_file, content_type)
      upload_result[:metadata].merge!(metadata_result)
      
      # Proceed to permanent storage
      storage_result = move_to_permanent_storage(
        temp_file, document_id, content_type, upload_result[:metadata]
      )
      
      upload_result.merge!(storage_result)
      
    else
      upload_result[:errors] = validation_result[:errors]
      upload_result[:processing_stages].last[:status] = 'failed'
      upload_result[:processing_stages].last[:completed_at] = Time.current
    end
    
  rescue => e
    upload_result[:errors] << {
      stage: 'validation',
      message: e.message
    }
    upload_result[:processing_stages].last[:status] = 'error'
    upload_result[:processing_stages].last[:completed_at] = Time.current
  end
  
  upload_result
end
```

### Stage 3: Metadata Extraction

Extract comprehensive metadata from different file types:

```ruby
def extract_comprehensive_metadata(file, content_type)
  metadata = {
    extraction_timestamp: Time.current.iso8601,
    file_signature: calculate_file_signature(file),
    content_type_specific: {}
  }
  
  case content_type
  when 'document'
    metadata[:content_type_specific] = extract_document_metadata(file)
  when 'image'
    metadata[:content_type_specific] = extract_image_metadata(file)
  when 'audio'
    metadata[:content_type_specific] = extract_audio_metadata(file)
  end
  
  # Add processing hints for downstream jobs
  metadata[:processing_hints] = generate_processing_hints(file, content_type, metadata)
  
  metadata
end

def extract_document_metadata(file)
  mime_type = Marcel::MimeType.for(file)
  
  case mime_type
  when 'application/pdf'
    extract_pdf_metadata(file)
  when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    extract_docx_metadata(file)
  when 'text/plain'
    extract_text_metadata(file)
  else
    { type: mime_type, basic_analysis: true }
  end
end

def extract_pdf_metadata(file)
  begin
    reader = PDF::Reader.new(file)
    
    {
      format: 'pdf',
      page_count: reader.page_count,
      pdf_version: reader.pdf_version,
      encrypted: reader.encrypted?,
      info: reader.info.to_h,
      estimated_word_count: estimate_pdf_word_count(reader),
      has_images: detect_pdf_images(reader),
      has_forms: detect_pdf_forms(reader),
      text_extractable: assess_pdf_text_extraction(reader)
    }
  rescue => e
    {
      format: 'pdf',
      error: "Metadata extraction failed: #{e.message}",
      fallback_analysis: true
    }
  end
end

def extract_image_metadata(file)
  begin
    # Use ImageMagick or similar for comprehensive image analysis
    image_info = identify_image(file)
    
    {
      format: image_info[:format],
      dimensions: {
        width: image_info[:width],
        height: image_info[:height],
        aspect_ratio: calculate_aspect_ratio(image_info[:width], image_info[:height])
      },
      color_info: {
        bit_depth: image_info[:bit_depth],
        color_space: image_info[:color_space],
        has_transparency: image_info[:has_alpha],
        color_count: image_info[:colors]
      },
      technical: {
        compression: image_info[:compression],
        quality: image_info[:quality],
        file_size_efficiency: calculate_size_efficiency(image_info)
      },
      exif_data: extract_exif_data(file),
      processing_recommendations: generate_image_processing_recommendations(image_info)
    }
  rescue => e
    {
      format: 'unknown_image',
      error: "Image analysis failed: #{e.message}",
      basic_analysis_only: true
    }
  end
end

def extract_audio_metadata(file)
  begin
    # Use audio analysis libraries
    audio_info = analyze_audio_file(file)
    
    {
      format: audio_info[:format],
      duration: audio_info[:duration],
      audio_properties: {
        sample_rate: audio_info[:sample_rate],
        channels: audio_info[:channels],
        bit_rate: audio_info[:bit_rate],
        bit_depth: audio_info[:bit_depth]
      },
      content_analysis: {
        has_speech: detect_speech_content(file),
        has_music: detect_music_content(file),
        silence_percentage: calculate_silence_percentage(file),
        volume_levels: analyze_volume_levels(file)
      },
      transcription_readiness: assess_transcription_feasibility(audio_info),
      id3_tags: extract_id3_tags(file)
    }
  rescue => e
    {
      format: 'unknown_audio',
      error: "Audio analysis failed: #{e.message}",
      basic_analysis_only: true
    }
  end
end
```

### Stage 4: Content Processing and Analysis

Initial content extraction and preparation:

```ruby
def perform_initial_content_processing(file, content_type, metadata)
  processing_result = {
    content_extracted: false,
    content_preview: nil,
    processing_jobs_queued: [],
    analysis_metadata: {}
  }
  
  case content_type
  when 'document'
    processing_result.merge!(process_document_content(file, metadata))
  when 'image'
    processing_result.merge!(process_image_content(file, metadata))
  when 'audio'
    processing_result.merge!(process_audio_content(file, metadata))
  end
  
  processing_result
end

def process_document_content(file, metadata)
  begin
    # Extract text content immediately for preview
    extracted_text = extract_text_content(file, metadata[:content_type_specific][:format])
    
    {
      content_extracted: true,
      content_preview: extracted_text[0..500], # First 500 characters
      full_content_length: extracted_text.length,
      word_count: extracted_text.split.length,
      language_detected: detect_language(extracted_text),
      processing_jobs_queued: [
        'GenerateEmbeddings',
        'ExtractKeywords',
        'GenerateSummary'
      ]
    }
  rescue => e
    {
      content_extracted: false,
      extraction_error: e.message,
      processing_jobs_queued: ['ExtractText'] # Fallback to background extraction
    }
  end
end

def process_image_content(file, metadata)
  begin
    # Generate quick image description
    quick_description = generate_quick_image_description(file)
    
    {
      content_extracted: true,
      content_preview: quick_description,
      requires_ai_analysis: true,
      processing_jobs_queued: [
        'GenerateImageDescription',
        'ExtractImageText', # OCR if text detected
        'GenerateEmbeddings'
      ],
      analysis_metadata: {
        optimal_ai_model: recommend_vision_model(metadata),
        processing_priority: calculate_processing_priority(metadata)
      }
    }
  rescue => e
    {
      content_extracted: false,
      analysis_error: e.message,
      processing_jobs_queued: ['ProcessImageContent']
    }
  end
end

def process_audio_content(file, metadata)
  begin
    # Quick audio analysis
    audio_analysis = perform_quick_audio_analysis(file)
    
    {
      content_extracted: false, # Audio requires transcription
      content_preview: "Audio file: #{metadata[:content_type_specific][:duration]}s duration",
      transcription_required: true,
      processing_jobs_queued: [
        'TranscribeAudio',
        'GenerateEmbeddings' # Will be queued after transcription
      ],
      analysis_metadata: {
        transcription_service: recommend_transcription_service(metadata),
        estimated_processing_time: estimate_transcription_time(metadata),
        language_hint: audio_analysis[:detected_language]
      }
    }
  rescue => e
    {
      content_extracted: false,
      analysis_error: e.message,
      processing_jobs_queued: ['ProcessAudioContent']
    }
  end
end
```

### Stage 5: Permanent Storage

Move validated files to permanent storage:

```ruby
def move_to_permanent_storage(temp_file, document_id, content_type, metadata)
  storage_result = {
    success: false,
    permanent_file_id: nil,
    storage_location: nil,
    storage_metadata: {}
  }
  
  begin
    # Determine optimal storage based on file characteristics
    target_storage = determine_optimal_storage(metadata, content_type)
    
    # Generate permanent file ID with organized structure
    permanent_id = generate_permanent_file_id(document_id, content_type, metadata)
    
    # Move file to permanent storage
    permanent_file = move_file_to_storage(temp_file, target_storage, permanent_id)
    
    storage_result.merge!({
      success: true,
      permanent_file_id: permanent_file.id,
      storage_location: target_storage,
      storage_metadata: {
        stored_at: Time.current.iso8601,
        storage_class: determine_storage_class(metadata),
        replication_status: 'pending',
        backup_scheduled: true
      }
    })
    
    # Schedule backup and replication
    schedule_file_backup(permanent_file, metadata)
    
    # Clean up temporary file
    cleanup_temp_file(temp_file)
    
  rescue => e
    storage_result[:error] = "Storage failed: #{e.message}"
  end
  
  storage_result
end

def determine_optimal_storage(metadata, content_type)
  file_size = metadata[:file_size]
  access_pattern = predict_access_pattern(metadata, content_type)
  
  case access_pattern
  when :frequent
    :hot_storage  # Fast, expensive storage
  when :occasional
    :warm_storage # Balanced cost/performance
  when :archive
    :cold_storage # Cheap, slower access
  else
    :standard_storage # Default
  end
end

def generate_permanent_file_id(document_id, content_type, metadata)
  # Organized file structure: type/year/month/document_id/hash
  date_path = Date.current.strftime("%Y/%m")
  file_hash = metadata[:file_signature][0..8] # First 8 chars of hash
  extension = extract_file_extension(metadata[:original_filename])
  
  "#{content_type}/#{date_path}/#{document_id}/#{file_hash}#{extension}"
end
```

### Stage 6: Database Record Creation

Create database records with comprehensive metadata:

```ruby
def create_database_records(document_id, content_type, file_info, metadata, processing_info)
  ActiveRecord::Base.transaction do
    # Find or create document
    document = Models::Document.find(document_id)
    
    # Create content record based on type
    content_record = create_content_record(
      document, content_type, file_info, metadata, processing_info
    )
    
    # Update document status and metadata
    update_document_with_file_info(document, content_record, metadata)
    
    # Queue background processing jobs
    queue_processing_jobs(content_record, processing_info[:processing_jobs_queued])
    
    {
      success: true,
      document_id: document.id,
      content_id: content_record.id,
      jobs_queued: processing_info[:processing_jobs_queued].length
    }
  end
rescue => e
  {
    success: false,
    error: "Database record creation failed: #{e.message}"
  }
end

def create_content_record(document, content_type, file_info, metadata, processing_info)
  content_class = case content_type
                  when 'document' then Models::TextContent
                  when 'image' then Models::ImageContent
                  when 'audio' then Models::AudioContent
                  else Models::Content
                  end
  
  content_attributes = {
    document: document,
    data: build_shrine_file_object(file_info),
    embedding_model: determine_embedding_model(content_type, metadata),
    metadata: build_content_metadata(metadata, processing_info)
  }
  
  # Add content-specific attributes
  case content_type
  when 'document'
    content_attributes[:content] = processing_info[:content_preview] if processing_info[:content_extracted]
  when 'image'
    content_attributes[:content] = processing_info[:content_preview] # Description
  when 'audio'
    # Content (transcript) will be added by background job
  end
  
  content_class.create!(content_attributes)
end

def build_shrine_file_object(file_info)
  {
    'id' => file_info[:permanent_file_id],
    'storage' => file_info[:storage_location].to_s,
    'metadata' => file_info[:storage_metadata].merge({
      'filename' => file_info[:original_filename],
      'mime_type' => file_info[:actual_mime_type],
      'size' => file_info[:file_size]
    })
  }
end

def queue_processing_jobs(content_record, job_names)
  job_names.each do |job_name|
    case job_name
    when 'GenerateEmbeddings'
      Ragdoll::Core::Jobs::GenerateEmbeddings.perform_later(content_record.document_id)
    when 'ExtractKeywords'
      Ragdoll::Core::Jobs::ExtractKeywords.perform_later(content_record.document_id)
    when 'GenerateSummary'
      Ragdoll::Core::Jobs::GenerateSummary.perform_later(content_record.document_id)
    when 'TranscribeAudio'
      # Custom job for audio transcription
      TranscribeAudioJob.perform_later(content_record.id)
    when 'GenerateImageDescription'
      # Custom job for image description
      GenerateImageDescriptionJob.perform_later(content_record.id)
    end
  end
end
```

### Pipeline Monitoring and Error Recovery

```ruby
module Ragdoll
  module Core
    class FileProcessingMonitor
      def self.monitor_processing_pipeline
        {
          active_uploads: count_active_uploads,
          processing_stages: analyze_processing_stages,
          error_rates: calculate_error_rates,
          throughput_metrics: calculate_throughput,
          storage_utilization: analyze_storage_usage
        }
      end
      
      def self.recover_failed_processing(document_id)
        document = Models::Document.find(document_id)
        
        # Analyze what went wrong
        failure_analysis = analyze_processing_failure(document)
        
        # Attempt recovery based on failure type
        case failure_analysis[:failure_type]
        when :validation_failure
          # Re-validate with updated rules
          retry_file_validation(document)
        when :storage_failure
          # Retry storage operation
          retry_file_storage(document)
        when :processing_timeout
          # Retry with extended timeout
          retry_processing_jobs(document, timeout: :extended)
        else
          # Manual intervention required
          flag_for_manual_review(document, failure_analysis)
        end
      end
    end
  end
end
```

## Security Considerations

Ragdoll implements comprehensive security measures to protect against malicious files, unauthorized access, and data breaches throughout the file handling lifecycle.

### Multi-Layered Security Architecture

```mermaid
flowchart TD
    A[File Upload] --> B[Input Validation]
    B --> C[MIME Type Verification]
    C --> D[Malware Scanning]
    D --> E[Content Analysis]
    E --> F[Access Control]
    F --> G[Encryption at Rest]
    G --> H[Secure URL Generation]
    H --> I[Audit Logging]
```

### File Type Validation

Strict validation prevents malicious file uploads:

```ruby
module Ragdoll
  module Core
    module Security
      class FileTypeValidator
        # Whitelist approach - only allow explicitly permitted file types
        ALLOWED_SIGNATURES = {
          # PDF files
          'application/pdf' => [
            ['%PDF-1.', 0], # PDF signature at start
          ],
          # DOCX files
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => [
            ['PK', 0], # ZIP signature (DOCX is ZIP-based)
            ['[Content_Types].xml', 30..100] # DOCX-specific content
          ],
          # Image files
          'image/jpeg' => [
            ['\xFF\xD8\xFF', 0], # JPEG signature
          ],
          'image/png' => [
            ['\x89PNG\r\n\x1a\n', 0], # PNG signature
          ],
          # Audio files
          'audio/mpeg' => [
            ['ID3', 0], # MP3 with ID3 tag
            ['\xFF\xFB', 0], # MP3 without ID3
            ['\xFF\xF3', 0], # MP3 alternative
          ]
        }
        
        def self.validate_file_type(file)
          validation_result = {
            valid: false,
            detected_type: nil,
            security_issues: []
          }
          
          # Read file signature
          file_signature = read_file_signature(file, 256) # First 256 bytes
          
          # Detect actual file type by signature
          detected_type = detect_type_by_signature(file_signature)
          validation_result[:detected_type] = detected_type
          
          # Check against declared MIME type
          declared_type = file.content_type if file.respond_to?(:content_type)
          
          if declared_type && declared_type != detected_type
            validation_result[:security_issues] << {
              type: :mime_type_spoofing,
              severity: :high,
              message: "Declared type #{declared_type} doesn't match detected type #{detected_type}"
            }
          end
          
          # Validate against whitelist
          if ALLOWED_SIGNATURES.key?(detected_type)
            validation_result[:valid] = verify_file_signature(file_signature, detected_type)
          else
            validation_result[:security_issues] << {
              type: :unsupported_file_type,
              severity: :critical,
              message: "File type #{detected_type} is not allowed"
            }
          end
          
          # Additional security checks
          validation_result[:security_issues].concat(perform_security_analysis(file))
          
          validation_result
        end
        
        private
        
        def self.read_file_signature(file, bytes = 256)
          file.rewind
          signature = file.read(bytes)
          file.rewind
          signature
        end
        
        def self.detect_type_by_signature(signature)
          ALLOWED_SIGNATURES.each do |mime_type, signatures|
            signatures.each do |sig_pattern, position|
              if position.is_a?(Range)
                # Check if pattern exists within range
                range_content = signature[position]
                return mime_type if range_content&.include?(sig_pattern)
              else
                # Check exact position
                return mime_type if signature[position, sig_pattern.length] == sig_pattern
              end
            end
          end
          
          'application/octet-stream' # Unknown type
        end
        
        def self.perform_security_analysis(file)
          security_issues = []
          
          # Check for embedded executables
          if contains_embedded_executable?(file)
            security_issues << {
              type: :embedded_executable,
              severity: :critical,
              message: "File contains embedded executable content"
            }
          end
          
          # Check for suspicious file patterns
          if suspicious_file_patterns?(file)
            security_issues << {
              type: :suspicious_patterns,
              severity: :medium,
              message: "File contains suspicious patterns"
            }
          end
          
          # Check file size anomalies
          if unusual_file_size?(file)
            security_issues << {
              type: :size_anomaly,
              severity: :low,
              message: "File size is unusual for declared type"
            }
          end
          
          security_issues
        end
        
        def self.contains_embedded_executable?(file)
          # Check for common executable signatures within the file
          executable_signatures = [
            'MZ',      # Windows PE
            '\x7fELF',  # Linux ELF
            '\xCE\xFA\xED\xFE', # Mach-O
            '\xFE\xED\xFA\xCE'  # Mach-O (reverse)
          ]
          
          file.rewind
          content = file.read
          file.rewind
          
          executable_signatures.any? { |sig| content.include?(sig) }
        end
      end
    end
  end
end
```

### Malware and Content Scanning

Integrated malware detection and content analysis:

```ruby
module Ragdoll
  module Core
    module Security
      class MalwareScanner
        def self.scan_file(file)
          scan_results = {
            scanned: false,
            clean: false,
            threats_detected: [],
            scan_engines: []
          }
          
          # Multi-engine scanning approach
          scan_engines = configure_scan_engines
          
          scan_engines.each do |engine|
            begin
              engine_result = engine[:scanner].call(file)
              scan_results[:scan_engines] << {
                name: engine[:name],
                result: engine_result,
                scanned_at: Time.current
              }
              
              if engine_result[:threats_detected]&.any?
                scan_results[:threats_detected].concat(engine_result[:threats_detected])
              end
              
            rescue => e
              scan_results[:scan_engines] << {
                name: engine[:name],
                error: e.message,
                scanned_at: Time.current
              }
            end
          end
          
          scan_results[:scanned] = scan_results[:scan_engines].any? { |e| !e[:error] }
          scan_results[:clean] = scan_results[:threats_detected].empty?
          
          # Quarantine file if threats detected
          if !scan_results[:clean]
            quarantine_file(file, scan_results[:threats_detected])
          end
          
          scan_results
        end
        
        private
        
        def self.configure_scan_engines
          engines = []
          
          # ClamAV integration
          if clamav_available?
            engines << {
              name: 'ClamAV',
              priority: 1,
              scanner: method(:scan_with_clamav)
            }
          end
          
          # Custom pattern matching
          engines << {
            name: 'PatternMatcher',
            priority: 2,
            scanner: method(:scan_with_patterns)
          }
          
          # Behavioral analysis
          engines << {
            name: 'BehavioralAnalysis',
            priority: 3,
            scanner: method(:behavioral_scan)
          }
          
          engines
        end
        
        def self.scan_with_clamav(file)
          temp_file = create_temp_file_for_scanning(file)
          
          begin
            result = `clamscan --no-summary --infected #{temp_file.path} 2>&1`
            exit_code = $?.exitstatus
            
            scan_result = {
              engine: 'clamav',
              threats_detected: [],
              scan_output: result.strip
            }
            
            if exit_code == 1 # Virus found
              if match = result.match(/: (.+) FOUND$/)
                scan_result[:threats_detected] << {
                  name: match[1],
                  type: 'virus',
                  severity: 'critical'
                }
              end
            elsif exit_code > 1 # Scan error
              scan_result[:error] = "ClamAV scan failed: #{result}"
            end
            
            scan_result
            
          ensure
            temp_file&.unlink
          end
        end
        
        def self.scan_with_patterns(file)
          # Custom malware signature patterns
          malware_patterns = [
            {
              pattern: /eval\s*\(\s*base64_decode/i,
              name: 'PHP Base64 Eval',
              type: 'webshell',
              severity: 'high'
            },
            {
              pattern: /<script[^>]*>.*?(document\.write|eval|unescape).*?<\/script>/mi,
              name: 'Malicious JavaScript',
              type: 'script_injection',
              severity: 'high'
            },
            {
              pattern: /cmd\.exe|powershell\.exe|sh\s+-c/i,
              name: 'Command Execution',
              type: 'command_injection',
              severity: 'critical'
            }
          ]
          
          file.rewind
          content = file.read(10.megabytes) # Scan first 10MB
          file.rewind
          
          threats_detected = []
          
          malware_patterns.each do |pattern_info|
            if content.match?(pattern_info[:pattern])
              threats_detected << {
                name: pattern_info[:name],
                type: pattern_info[:type],
                severity: pattern_info[:severity],
                detection_method: 'pattern_matching'
              }
            end
          end
          
          {
            engine: 'pattern_matcher',
            threats_detected: threats_detected
          }
        end
        
        def self.behavioral_scan(file)
          suspicious_behaviors = []
          
          # Analyze file entropy (high entropy might indicate encryption/packing)
          entropy = calculate_file_entropy(file)
          if entropy > 7.5 # High entropy threshold
            suspicious_behaviors << {
              name: 'High Entropy Content',
              type: 'suspicious_structure',
              severity: 'medium',
              details: { entropy: entropy }
            }
          end
          
          # Check for unusual file structure
          if unusual_file_structure?(file)
            suspicious_behaviors << {
              name: 'Unusual File Structure',
              type: 'structural_anomaly',
              severity: 'low'
            }
          end
          
          {
            engine: 'behavioral_analysis',
            threats_detected: suspicious_behaviors.select { |b| b[:severity] == 'critical' },
            suspicious_behaviors: suspicious_behaviors
          }
        end
        
        def self.quarantine_file(file, threats)
          # Move file to quarantine location
          quarantine_id = SecureRandom.uuid
          quarantine_path = "quarantine/#{Date.current.strftime('%Y/%m/%d')}/#{quarantine_id}"
          
          # Store quarantine information
          quarantine_info = {
            id: quarantine_id,
            original_filename: file.original_filename,
            quarantined_at: Time.current,
            threats: threats,
            file_signature: calculate_file_hash(file)
          }
          
          # Log security incident
          log_security_incident('file_quarantined', quarantine_info)
          
          # Notify security team
          notify_security_team(quarantine_info)
        end
      end
    end
  end
end
```

### Access Control and Authorization

Robust access control for file operations:

```ruby
module Ragdoll
  module Core
    module Security
      class FileAccessControl
        def self.authorize_file_access(user, file, operation)
          authorization_result = {
            authorized: false,
            reason: nil,
            restrictions: []
          }
          
          # Check basic permissions
          base_permission = check_base_permission(user, operation)
          unless base_permission[:allowed]
            authorization_result[:reason] = base_permission[:reason]
            return authorization_result
          end
          
          # Check file-specific permissions
          file_permission = check_file_permission(user, file, operation)
          unless file_permission[:allowed]
            authorization_result[:reason] = file_permission[:reason]
            return authorization_result
          end
          
          # Check rate limits
          rate_limit_check = check_rate_limits(user, operation)
          if rate_limit_check[:exceeded]
            authorization_result[:reason] = 'Rate limit exceeded'
            authorization_result[:restrictions] << rate_limit_check
            return authorization_result
          end
          
          # Check file access patterns
          access_pattern_check = analyze_access_pattern(user, file, operation)
          if access_pattern_check[:suspicious]
            # Log suspicious activity but allow access with monitoring
            log_suspicious_access(user, file, operation, access_pattern_check)
            authorization_result[:restrictions] << {
              type: 'enhanced_monitoring',
              reason: access_pattern_check[:reason]
            }
          end
          
          authorization_result[:authorized] = true
          authorization_result
        end
        
        def self.generate_secure_file_url(file, user, options = {})
          # Generate time-limited, signed URLs for file access
          expires_at = options[:expires_at] || 1.hour.from_now
          
          # Create signature
          signature_data = {
            file_id: file.id,
            user_id: user&.id,
            expires_at: expires_at.to_i,
            operation: options[:operation] || 'read'
          }
          
          signature = generate_url_signature(signature_data)
          
          # Build secure URL
          base_url = file.url
          query_params = {
            token: signature,
            expires: expires_at.to_i,
            user: user&.id
          }.compact
          
          "#{base_url}?#{query_params.to_query}"
        end
        
        private
        
        def self.check_base_permission(user, operation)
          # Define operation permissions
          operation_permissions = {
            'read' => ['viewer', 'editor', 'admin'],
            'write' => ['editor', 'admin'],
            'delete' => ['admin'],
            'upload' => ['editor', 'admin']
          }
          
          required_roles = operation_permissions[operation] || []
          
          if user.nil?
            return { allowed: false, reason: 'Authentication required' }
          end
          
          unless required_roles.include?(user.role)
            return { 
              allowed: false, 
              reason: "Insufficient permissions. Required: #{required_roles.join(', ')}" 
            }
          end
          
          { allowed: true }
        end
        
        def self.check_file_permission(user, file, operation)
          # Check file-specific access rules
          
          # Personal files - only owner can access
          if file.metadata&.dig('access_control', 'owner_only')
            file_owner_id = file.metadata.dig('access_control', 'owner_id')
            unless file_owner_id == user.id
              return { 
                allowed: false, 
                reason: 'File is private to owner only' 
              }
            end
          end
          
          # Restricted files - check explicit permissions
          if file.metadata&.dig('access_control', 'restricted')
            allowed_users = file.metadata.dig('access_control', 'allowed_users') || []
            unless allowed_users.include?(user.id)
              return { 
                allowed: false, 
                reason: 'User not in file access list' 
              }
            end
          end
          
          # Quarantined files - admin only
          if file.metadata&.dig('security', 'quarantined')
            unless user.role == 'admin'
              return { 
                allowed: false, 
                reason: 'File is quarantined - admin access only' 
              }
            end
          end
          
          { allowed: true }
        end
        
        def self.generate_url_signature(data)
          # Generate HMAC signature for URL security
          secret_key = ENV['RAGDOLL_URL_SIGNING_KEY'] || Rails.application.secret_key_base
          payload = data.to_json
          
          OpenSSL::HMAC.hexdigest('SHA256', secret_key, payload)
        end
      end
    end
  end
end
```

### Encryption at Rest

Comprehensive encryption for stored files:

```ruby
module Ragdoll
  module Core
    module Security
      class FileEncryption
        def self.configure_encryption
          # S3 server-side encryption configuration
          if Shrine.storages[:store].is_a?(Shrine::Storage::S3)
            configure_s3_encryption
          end
          
          # Application-level encryption for sensitive files
          configure_application_encryption
        end
        
        def self.encrypt_sensitive_file(file)
          # Identify sensitive files that need application-level encryption
          return file unless requires_encryption?(file)
          
          # Generate file-specific encryption key
          encryption_key = generate_file_encryption_key
          
          # Encrypt file content
          encrypted_content = encrypt_content(file.read, encryption_key)
          
          # Store encryption metadata
          encryption_metadata = {
            encrypted: true,
            encryption_algorithm: 'AES-256-GCM',
            key_id: store_encryption_key(encryption_key),
            encrypted_at: Time.current.iso8601
          }
          
          # Create encrypted file object
          encrypted_file = StringIO.new(encrypted_content)
          encrypted_file.define_singleton_method(:metadata) do
            file.metadata.merge(encryption: encryption_metadata)
          end
          
          encrypted_file
        end
        
        def self.decrypt_file(encrypted_file)
          encryption_metadata = encrypted_file.metadata['encryption']
          return encrypted_file unless encryption_metadata&.dig('encrypted')
          
          # Retrieve encryption key
          encryption_key = retrieve_encryption_key(encryption_metadata['key_id'])
          
          # Decrypt content
          decrypted_content = decrypt_content(
            encrypted_file.read, 
            encryption_key, 
            encryption_metadata['encryption_algorithm']
          )
          
          StringIO.new(decrypted_content)
        end
        
        private
        
        def self.configure_s3_encryption
          # Configure S3 server-side encryption
          s3_config = {
            server_side_encryption: 'AES256',
            # Or use KMS for additional key management
            # server_side_encryption: 'aws:kms',
            # ssekms_key_id: ENV['AWS_KMS_KEY_ID']
          }
          
          # Apply to storage configuration
          Shrine.storages[:store].instance_variable_get(:@s3).client.config.update(
            server_side_encryption: s3_config[:server_side_encryption]
          )
        end
        
        def self.requires_encryption?(file)
          # Determine if file needs application-level encryption
          sensitive_patterns = [
            /password/i,
            /confidential/i,
            /private/i,
            /secret/i,
            /ssn/i,
            /social.security/i
          ]
          
          filename = file.original_filename || ''
          content_sample = file.read(1024) # First 1KB
          file.rewind
          
          # Check filename
          return true if sensitive_patterns.any? { |pattern| filename.match?(pattern) }
          
          # Check content
          return true if sensitive_patterns.any? { |pattern| content_sample.match?(pattern) }
          
          false
        end
        
        def self.encrypt_content(content, key)
          cipher = OpenSSL::Cipher.new('AES-256-GCM')
          cipher.encrypt
          cipher.key = key
          
          iv = cipher.random_iv
          encrypted = cipher.update(content) + cipher.final
          tag = cipher.auth_tag
          
          # Combine IV, tag, and encrypted content
          [iv, tag, encrypted].map(&:unpack1).join
        end
        
        def self.decrypt_content(encrypted_data, key, algorithm)
          # Split combined data
          iv_length = 12 # GCM IV length
          tag_length = 16 # GCM tag length
          
          iv = encrypted_data[0, iv_length]
          tag = encrypted_data[iv_length, tag_length]
          encrypted = encrypted_data[iv_length + tag_length..-1]
          
          # Decrypt
          decipher = OpenSSL::Cipher.new(algorithm)
          decipher.decrypt
          decipher.key = key
          decipher.iv = iv
          decipher.auth_tag = tag
          
          decipher.update(encrypted) + decipher.final
        end
      end
    end
  end
end
```

### Security Audit and Logging

Comprehensive security monitoring and audit trails:

```ruby
module Ragdoll
  module Core
    module Security
      class SecurityAuditor
        def self.log_file_operation(operation, file, user, result)
          audit_entry = {
            timestamp: Time.current.iso8601,
            operation: operation,
            file_id: file.id,
            file_path: file.metadata['filename'],
            user_id: user&.id,
            user_ip: get_user_ip,
            result: result,
            metadata: {
              file_size: file.metadata['size'],
              mime_type: file.metadata['mime_type'],
              security_scan_result: file.metadata.dig('security', 'scan_result')
            }
          }
          
          # Log to security audit log
          write_security_log(audit_entry)
          
          # Send to SIEM if configured
          send_to_siem(audit_entry) if siem_configured?
        end
        
        def self.detect_anomalous_activity
          # Analyze recent file operations for suspicious patterns
          
          # Check for unusual upload volumes
          recent_uploads = count_recent_uploads(1.hour)
          if recent_uploads > 100 # Threshold
            create_security_alert('high_upload_volume', {
              count: recent_uploads,
              threshold: 100,
              time_window: '1 hour'
            })
          end
          
          # Check for failed security scans
          failed_scans = count_failed_security_scans(24.hours)
          if failed_scans > 5
            create_security_alert('multiple_security_failures', {
              count: failed_scans,
              time_window: '24 hours'
            })
          end
          
          # Check for unusual access patterns
          detect_unusual_access_patterns
        end
        
        private
        
        def self.write_security_log(entry)
          # Write to dedicated security log
          security_logger = Logger.new(
            ENV['SECURITY_LOG_PATH'] || 'log/security.log',
            formatter: proc { |severity, datetime, progname, msg|
              "#{datetime.iso8601} #{severity} #{msg}\n"
            }
          )
          
          security_logger.info(entry.to_json)
        end
        
        def self.create_security_alert(alert_type, details)
          alert = {
            id: SecureRandom.uuid,
            type: alert_type,
            severity: determine_alert_severity(alert_type),
            details: details,
            created_at: Time.current.iso8601,
            investigated: false
          }
          
          # Store alert
          store_security_alert(alert)
          
          # Notify security team
          notify_security_team(alert)
        end
      end
    end
  end
end
```

---

## Summary

Ragdoll's file upload system provides enterprise-grade file handling through Shrine's flexible architecture. The system offers:

**Core Capabilities:**
- **Multi-Modal Support**: Specialized handling for documents, images, and audio files
- **Flexible Storage**: Support for filesystem, S3, Google Cloud, and Azure backends
- **Comprehensive Validation**: Multi-layer security with MIME type verification and malware scanning
- **Processing Pipeline**: Automated content extraction and AI-powered analysis
- **Security First**: Encryption at rest, access control, and audit logging

**Supported File Types:**
- **Documents**: PDF, DOCX, TXT, HTML, Markdown, JSON, RTF
- **Images**: JPEG, PNG, GIF, WebP, BMP, TIFF, SVG with AI description generation
- **Audio**: MP3, WAV, M4A, FLAC, OGG with automatic transcription

**Security Features:**
- File signature validation and MIME type verification
- Integrated malware scanning with ClamAV and custom patterns
- Role-based access control with secure URL generation
- Application-level encryption for sensitive content
- Comprehensive audit logging and anomaly detection

**Production Ready:**
- CDN integration for optimized delivery
- Hybrid storage strategies for cost optimization
- Automatic backup and replication
- Error recovery and processing monitoring
- Horizontal scaling with load balancing

The system seamlessly integrates with Ragdoll's document processing pipeline, ensuring secure, efficient file handling from upload through AI-powered content analysis and embedding generation.

*This document is part of the Ragdoll documentation suite. For immediate help, see the [Quick Start Guide](quick-start.md) or [API Reference](api-client.md).*