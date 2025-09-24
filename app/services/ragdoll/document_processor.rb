# frozen_string_literal: true

require "pdf-reader"
require "docx"
require "rmagick"
require "yaml"
require "date"

module Ragdoll
  class DocumentProcessor
    class ParseError < Ragdoll::Core::DocumentError; end
    class UnsupportedFormatError < ParseError; end

    def self.parse(file_path)
      new(file_path).parse
    end

    # Parse from Shrine attached file
    def self.parse_attachment(attached_file)
      attached_file.open do |tempfile|
        new(tempfile.path, attached_file).parse
      end
    end

    # Create document from file path
    def self.create_document_from_file(file_path, **options)
      parsed = parse(file_path)

      # Get file modification time
      file_modified_at = File.exist?(file_path) ? File.mtime(file_path) : Time.current

      document = Ragdoll::Document.create!(
        location: File.expand_path(file_path),
        title: parsed[:title] || File.basename(file_path, File.extname(file_path)),
        content: parsed[:content],
        document_type: parsed[:document_type] || determine_document_type(file_path),
        metadata: parsed[:metadata] || {},
        status: "processed",
        file_modified_at: file_modified_at,
        **options
      )

      # Attach the file if it exists
      document.file = File.open(file_path) if File.exist?(file_path)

      document
    end

    # Create document from uploaded file (Shrine compatible)
    def self.create_document_from_upload(uploaded_file, **options)
      # Create document first
      document = Ragdoll::Document.create!(
        location: uploaded_file.original_filename || "uploaded_file",
        title: options[:title] || File.basename(uploaded_file.original_filename || "uploaded_file",
                                                File.extname(uploaded_file.original_filename || "")),
        content: "", # Will be extracted after file attachment
        document_type: determine_document_type_from_content_type(uploaded_file.mime_type),
        status: "processing",
        metadata: options[:metadata] || {},
        file_modified_at: Time.current
      )

      # Attach the file
      document.file = uploaded_file

      # Extract content from attached file
      if document.file.present?
        parsed = parse_attachment(document.file)
        document.update!(
          content: parsed[:content],
          title: parsed[:title] || document.title,
          metadata: document.metadata.merge(parsed[:metadata] || {}),
          status: "processed"
        )
      end

      document
    end

    def initialize(file_path, attached_file = nil)
      @file_path = file_path
      @attached_file = attached_file
      @file_extension = File.extname(file_path).downcase
    end

    def parse
      # Check if file exists first
      unless File.exist?(@file_path)
        raise ParseError, "File does not exist: #{@file_path}"
      end

      # Use the new unified document converter
      document_type = determine_document_type(@file_path)

      begin
        # Convert to text using the unified pipeline
        text_content = Ragdoll::DocumentConverter.convert_to_text(@file_path, document_type)

        # Extract metadata based on document type
        metadata = extract_metadata_for_type(document_type)

        # Add encoding information for text files
        if %w[text markdown html].include?(document_type)
          encoding = detect_file_encoding(@file_path) || "UTF-8"
          metadata[:encoding] = encoding
        end

        # Get title from metadata or filename
        title = metadata[:title] || extract_title_from_filepath

        {
          content: text_content,
          metadata: metadata,
          title: title,
          document_type: document_type
        }
      rescue StandardError => e
        raise ParseError, "Failed to parse document: #{e.message}"
      end
    end

    # Helper methods for document type determination
    def self.determine_document_type(file_path)
      Ragdoll::DocumentConverter.new.determine_document_type(file_path)
    end

    def self.determine_document_type_from_content_type(content_type)
      case content_type
      when "application/pdf" then "pdf"
      when "application/vnd.openxmlformats-officedocument.wordprocessingml.document" then "docx"
      when "text/plain" then "text"
      when "text/markdown" then "markdown"
      when "text/html" then "html"
      when %r{^image/} then "image"
      when %r{^audio/} then "audio"
      when %r{^video/} then "video"
      else "text"
      end
    end

    def self.determine_content_type(file_path)
      case File.extname(file_path).downcase
      when ".pdf" then "application/pdf"
      when ".docx" then "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      when ".txt" then "text/plain"
      when ".md", ".markdown" then "text/markdown"
      when ".html", ".htm" then "text/html"
      when ".jpg", ".jpeg" then "image/jpeg"
      when ".png" then "image/png"
      when ".gif" then "image/gif"
      when ".webp" then "image/webp"
      when ".bmp" then "image/bmp"
      when ".svg" then "image/svg+xml"
      when ".ico" then "image/x-icon"
      when ".tiff", ".tif" then "image/tiff"
      when ".mp3" then "audio/mpeg"
      when ".wav" then "audio/wav"
      when ".m4a" then "audio/mp4"
      when ".flac" then "audio/flac"
      when ".ogg" then "audio/ogg"
      when ".mp4" then "video/mp4"
      when ".mov" then "video/quicktime"
      when ".avi" then "video/x-msvideo"
      when ".webm" then "video/webm"
      else "application/octet-stream"
      end
    end

    private

    def determine_document_type(file_path)
      Ragdoll::DocumentConverter.new.determine_document_type(file_path)
    end

    def extract_metadata_for_type(document_type)
      metadata = basic_file_metadata

      case document_type
      when "pdf"
        metadata.merge!(extract_pdf_metadata)
      when "docx"
        metadata.merge!(extract_docx_metadata)
      when "image"
        metadata.merge!(extract_image_metadata)
      when "audio"
        metadata.merge!(extract_audio_metadata)
      when "video"
        metadata.merge!(extract_video_metadata)
      end

      metadata
    end

    def basic_file_metadata
      metadata = {}

      if File.exist?(@file_path)
        metadata[:file_size] = File.size(@file_path)
        metadata[:file_hash] = calculate_file_hash(@file_path)
        metadata[:file_modified_at] = File.mtime(@file_path)
      end

      metadata[:original_filename] = File.basename(@file_path)
      metadata[:file_extension] = File.extname(@file_path).downcase
      metadata
    end

    def extract_pdf_metadata
      return {} unless File.exist?(@file_path)

      begin
        metadata = {}
        PDF::Reader.open(@file_path) do |reader|
          if reader.info
            metadata[:pdf_title] = reader.info[:Title] if reader.info[:Title]
            metadata[:pdf_author] = reader.info[:Author] if reader.info[:Author]
            metadata[:pdf_subject] = reader.info[:Subject] if reader.info[:Subject]
            metadata[:pdf_creator] = reader.info[:Creator] if reader.info[:Creator]
            metadata[:pdf_producer] = reader.info[:Producer] if reader.info[:Producer]
            metadata[:pdf_creation_date] = reader.info[:CreationDate] if reader.info[:CreationDate]
            metadata[:pdf_modification_date] = reader.info[:ModDate] if reader.info[:ModDate]
          end
          metadata[:page_count] = reader.page_count
        end

        # Use PDF title as main title if available
        metadata[:title] = metadata[:pdf_title] if metadata[:pdf_title]
        metadata
      rescue StandardError => e
        puts "Warning: Failed to extract PDF metadata: #{e.message}"
        {}
      end
    end

    def extract_docx_metadata
      return {} unless File.exist?(@file_path)

      begin
        metadata = {}
        doc = Docx::Document.open(@file_path)

        if doc.core_properties
          metadata[:docx_title] = doc.core_properties.title if doc.core_properties.title
          metadata[:docx_author] = doc.core_properties.creator if doc.core_properties.creator
          metadata[:docx_subject] = doc.core_properties.subject if doc.core_properties.subject
          metadata[:docx_description] = doc.core_properties.description if doc.core_properties.description
          metadata[:docx_keywords] = doc.core_properties.keywords if doc.core_properties.keywords
          metadata[:docx_created] = doc.core_properties.created if doc.core_properties.created
          metadata[:docx_modified] = doc.core_properties.modified if doc.core_properties.modified
          metadata[:docx_last_modified_by] = doc.core_properties.last_modified_by if doc.core_properties.last_modified_by
        end

        metadata[:paragraph_count] = doc.paragraphs.count
        metadata[:table_count] = doc.tables.count

        # Use DOCX title as main title if available
        metadata[:title] = metadata[:docx_title] if metadata[:docx_title]
        metadata
      rescue StandardError => e
        puts "Warning: Failed to extract DOCX metadata: #{e.message}"
        {}
      end
    end

    def extract_image_metadata
      return {} unless File.exist?(@file_path)

      begin
        metadata = {}
        img = Magick::Image.read(@file_path).first

        metadata[:width] = img.columns
        metadata[:height] = img.rows
        metadata[:image_format] = img.format
        metadata[:mime_type] = img.mime_type
        metadata[:number_colors] = img.number_colors

        metadata
      rescue StandardError => e
        puts "Warning: Failed to extract image metadata: #{e.message}"
        {}
      end
    end

    def extract_audio_metadata
      # Basic audio file metadata
      # In production, you might use audio analysis libraries
      {
        media_type: "audio",
        file_type: File.extname(@file_path).sub(".", "")
      }
    end

    def extract_video_metadata
      # Basic video file metadata
      # In production, you might use video analysis libraries
      {
        media_type: "video",
        file_type: File.extname(@file_path).sub(".", "")
      }
    end

    # Extract a meaningful title from the file path as a fallback
    def extract_title_from_filepath(file_path = @file_path)
      filename = File.basename(file_path, File.extname(file_path))

      # Clean up common patterns in filenames to make them more readable
      title = filename
               .gsub(/[-_]+/, ' ')           # Replace hyphens and underscores with spaces
               .gsub(/([a-z])([A-Z])/, '\1 \2') # Add space before capital letters (camelCase)
               .gsub(/\s+/, ' ')             # Normalize multiple spaces
               .strip

      # Capitalize words for better readability
      title.split(' ').map(&:capitalize).join(' ')
    end

    # Calculate SHA256 hash of file content for duplicate detection
    def calculate_file_hash(file_path)
      require 'digest'
      Digest::SHA256.file(file_path).hexdigest
    rescue StandardError => e
      Rails.logger.warn "Failed to calculate file hash for #{file_path}: #{e.message}" if defined?(Rails)
      puts "Warning: Failed to calculate file hash for #{file_path}: #{e.message}"
      nil
    end

    # Calculate SHA256 hash of text content for duplicate detection
    def calculate_content_hash(content)
      require 'digest'
      Digest::SHA256.hexdigest(content)
    rescue StandardError => e
      Rails.logger.warn "Failed to calculate content hash: #{e.message}" if defined?(Rails)
      puts "Warning: Failed to calculate content hash: #{e.message}"
      nil
    end

    # Detect file encoding for text files
    def detect_file_encoding(file_path)
      return nil unless File.exist?(file_path)

      # Read a sample to detect encoding
      sample = File.read(file_path, 1000, encoding: 'ASCII-8BIT')

      # Check for common encodings
      if sample.valid_encoding?
        # Try to convert to UTF-8
        utf8_content = sample.encode('UTF-8', invalid: :replace, undef: :replace)
        return 'UTF-8' if utf8_content.valid_encoding?
      end

      # Try common encodings
      ['UTF-8', 'ISO-8859-1', 'Windows-1252'].each do |encoding|
        begin
          test_content = sample.force_encoding(encoding)
          return encoding if test_content.valid_encoding?
        rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
          next
        end
      end

      'UTF-8' # Default fallback
    rescue StandardError
      'UTF-8'
    end
  end
end