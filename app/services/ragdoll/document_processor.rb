# frozen_string_literal: true

require "pdf-reader"
require "docx"
require "rmagick"
# Image description service is auto-loaded from app/services

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
        document_type: determine_document_type(file_path),
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
      case @file_extension
      when ".pdf"
        parse_pdf
      when ".docx"
        parse_docx
      when ".txt", ".md", ".markdown"
        parse_text
      when ".html", ".htm"
        parse_html
      when ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".svg", ".ico", ".tiff", ".tif"
        parse_image
      else
        parse_text # Default to text parsing for unknown formats
      end
    rescue StandardError => e # StandardError => e
      raise ParseError, "#{__LINE__} Failed to parse #{@file_path}: #{e.message}"
    end

    private

    def parse_pdf
      content = ""
      metadata = {}

      begin
        PDF::Reader.open(@file_path) do |reader|
          # Extract metadata
          if reader.info
            metadata[:title] = reader.info[:Title] if reader.info[:Title]
            metadata[:author] = reader.info[:Author] if reader.info[:Author]
            metadata[:subject] = reader.info[:Subject] if reader.info[:Subject]
            metadata[:creator] = reader.info[:Creator] if reader.info[:Creator]
            metadata[:producer] = reader.info[:Producer] if reader.info[:Producer]
            metadata[:creation_date] = reader.info[:CreationDate] if reader.info[:CreationDate]
            metadata[:modification_date] = reader.info[:ModDate] if reader.info[:ModDate]
          end

          metadata[:page_count] = reader.page_count

          # Extract text from all pages
          reader.pages.each_with_index do |page, index|
            page_text = page.text.strip
            next if page_text.empty?

            content += "\n\n--- Page #{index + 1} ---\n\n" if content.length.positive?
            content += page_text
          end
        end
      rescue PDF::Reader::MalformedPDFError => e
        raise ParseError, "Malformed PDF: #{e.message}"
      rescue PDF::Reader::UnsupportedFeatureError => e
        raise ParseError, "Unsupported PDF feature: #{e.message}"
      end

      {
        content: content.strip,
        metadata: metadata,
        document_type: "pdf"
      }
    end

    def parse_docx
      content = ""
      metadata = {}

      begin
        doc = Docx::Document.open(@file_path)

        # Extract core properties
        if doc.core_properties
          metadata[:title] = doc.core_properties.title if doc.core_properties.title
          metadata[:author] = doc.core_properties.creator if doc.core_properties.creator
          metadata[:subject] = doc.core_properties.subject if doc.core_properties.subject
          metadata[:description] = doc.core_properties.description if doc.core_properties.description
          metadata[:keywords] = doc.core_properties.keywords if doc.core_properties.keywords
          metadata[:created] = doc.core_properties.created if doc.core_properties.created
          metadata[:modified] = doc.core_properties.modified if doc.core_properties.modified
          if doc.core_properties.last_modified_by
            metadata[:last_modified_by] =
              doc.core_properties.last_modified_by
          end
        end

        # Extract text from paragraphs
        doc.paragraphs.each do |paragraph|
          paragraph_text = paragraph.text.strip
          next if paragraph_text.empty?

          content += "#{paragraph_text}\n\n"
        end

        # Extract text from tables
        doc.tables.each_with_index do |table, table_index|
          content += "\n--- Table #{table_index + 1} ---\n\n"

          table.rows.each do |row|
            row_text = row.cells.map(&:text).join(" | ")
            content += "#{row_text}\n" unless row_text.strip.empty?
          end

          content += "\n"
        end

        metadata[:paragraph_count] = doc.paragraphs.count
        metadata[:table_count] = doc.tables.count
      rescue StandardError => e # StandardError => e
        raise ParseError, "#{__LINE__} Failed to parse DOCX: #{e.message}"
      end

      {
        content: content.strip,
        metadata: metadata,
        document_type: "docx"
      }
    end

    def parse_text
      content = File.read(@file_path, encoding: "UTF-8")
      metadata = {
        file_size: File.size(@file_path),
        encoding: "UTF-8"
      }

      document_type = case @file_extension
                      when ".md", ".markdown" then "markdown"
                      when ".txt" then "text"
                      else "text"
                      end

      {
        content: content,
        metadata: metadata,
        document_type: document_type
      }
    rescue Encoding::InvalidByteSequenceError
      # Try with different encoding
      content = File.read(@file_path, encoding: "ISO-8859-1")
      metadata = {
        file_size: File.size(@file_path),
        encoding: "ISO-8859-1"
      }

      {
        content: content,
        metadata: metadata,
        document_type: "text"
      }
    end

    def parse_html
      content = File.read(@file_path, encoding: "UTF-8")

      # Basic HTML tag stripping (for more advanced parsing, consider using Nokogiri)
      clean_content = content
                      .gsub(%r{<script[^>]*>.*?</script>}mi, "") # Remove script tags
                      .gsub(%r{<style[^>]*>.*?</style>}mi, "")   # Remove style tags
                      .gsub(/<[^>]+>/, " ")                     # Remove all HTML tags
                      .gsub(/\s+/, " ")                         # Normalize whitespace
                      .strip

      metadata = {
        file_size: File.size(@file_path),
        original_format: "html"
      }

      {
        content: clean_content,
        metadata: metadata,
        document_type: "html"
      }
    end

    def parse_image
      puts "🖼️  DocumentProcessor: Starting image parsing for #{@file_path}"

      metadata = {
        file_size: File.size(@file_path),
        file_type: @file_extension.sub(".", ""),
        original_filename: File.basename(@file_path)
      }

      # Extract image dimensions
      begin
        img = Magick::Image.read(@file_path).first
        metadata[:width]  = img.columns
        metadata[:height] = img.rows
        puts "📏 DocumentProcessor: Image dimensions: #{img.columns}x#{img.rows}"
      rescue StandardError => e # StandardError
        puts "❌ DocumentProcessor: Failed to get image dimensions: #{e.message}"
        metadata[:width]  = nil
        metadata[:height] = nil
      end

      puts "🤖 DocumentProcessor: Creating ImageDescriptionService and calling generate_description..."
      desc = Ragdoll::ImageDescriptionService.new.generate_description(@file_path)

      puts "📝 DocumentProcessor: Received description: '#{desc}'"

      metadata[:description] = desc if desc && !desc.empty?

      # Use AI-generated description or fallback placeholder
      content = desc && !desc.empty? ? desc : "Image file: #{File.basename(@file_path)}"

      puts "✅ DocumentProcessor: Image parsing complete. Content: '#{content[0..100]}...'"

      {
        content: content,
        metadata: metadata,
        document_type: "image"
      }
    end

    # Helper methods for document type determination
    def self.determine_document_type(file_path)
      case File.extname(file_path).downcase
      when ".pdf" then "pdf"
      when ".docx" then "docx"
      when ".txt" then "text"
      when ".md", ".markdown" then "markdown"
      when ".html", ".htm" then "html"
      when ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".svg", ".ico", ".tiff", ".tif" then "image"
      else "text"
      end
    end

    def self.determine_document_type_from_content_type(content_type)
      case content_type
      when "application/pdf" then "pdf"
      when "application/vnd.openxmlformats-officedocument.wordprocessingml.document" then "docx"
      when "text/plain" then "text"
      when "text/markdown" then "markdown"
      when "text/html" then "html"
      when %r{^image/} then "image"
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
      else "application/octet-stream"
      end
    end
  end
end