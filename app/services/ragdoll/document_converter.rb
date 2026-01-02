# frozen_string_literal: true

module Ragdoll
  # Unified document-to-text conversion pipeline
  #
  # Converts various document formats (PDF, DOCX, images, audio, video)
  # to plain text for embedding and search. Delegates to specialized
  # extraction services based on document type.
  #
  # @example Convert a PDF to text
  #   text = Ragdoll::DocumentConverter.convert_to_text("/path/to/doc.pdf")
  #
  # @example With explicit document type
  #   converter = Ragdoll::DocumentConverter.new
  #   text = converter.convert_to_text("/path/to/file", "image")
  #
  class DocumentConverter
    # Raised when document conversion fails
    class ConversionError < StandardError; end

    # Convert a file to text using class method convenience
    #
    # @param file_path [String] Path to the document file
    # @param document_type [String, nil] Document type override
    # @param options [Hash] Options passed to extraction services
    # @return [String] Extracted text content
    #
    def self.convert_to_text(file_path, document_type = nil, **options)
      new(**options).convert_to_text(file_path, document_type)
    end

    # Initialize the converter
    #
    # @param options [Hash] Options passed to extraction services
    #
    def initialize(**options)
      @options = options
    end

    # Convert a document to text
    #
    # @param file_path [String] Path to the document file
    # @param document_type [String, nil] Document type (auto-detected if nil)
    # @return [String] Extracted text content
    #
    def convert_to_text(file_path, document_type = nil)
      return "" unless File.exist?(file_path)

      document_type ||= determine_document_type(file_path)

      begin
        case document_type
        when "text", "markdown", "html", "pdf", "docx", "csv", "json", "xml", "yaml"
          convert_text_based_document(file_path, document_type)
        when "image"
          convert_image_to_text(file_path)
        when "audio"
          convert_audio_to_text(file_path)
        when "video"
          convert_video_to_text(file_path)
        else
          convert_unknown_document(file_path)
        end
      rescue StandardError => e
        puts "Warning: Document conversion failed for #{file_path}: #{e.message}"
        generate_fallback_text(file_path, document_type)
      end
    end

    # Determine document type from file extension
    #
    # @param file_path [String] Path to the file
    # @return [String] Document type (pdf, docx, text, image, audio, video, etc.)
    #
    def determine_document_type(file_path)
      extension = File.extname(file_path).downcase

      case extension
      when ".pdf" then "pdf"
      when ".docx" then "docx"
      when ".txt" then "text"
      when ".md", ".markdown" then "markdown"
      when ".html", ".htm" then "html"
      when ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".svg", ".ico", ".tiff", ".tif"
        "image"
      when ".mp3", ".wav", ".m4a", ".flac", ".ogg", ".aac", ".wma"
        "audio"
      when ".mp4", ".mov", ".avi", ".webm", ".mkv"
        "video"
      when ".csv" then "csv"
      when ".json" then "json"
      when ".xml" then "xml"
      when ".yml", ".yaml" then "yaml"
      else
        "text"  # Default to text for unknown extensions
      end
    end

    # List of supported file formats by category
    #
    # @return [Hash] Supported formats organized by type
    #
    def supported_formats
      {
        text: %w[.txt .md .markdown .html .htm .csv .json .xml .yml .yaml],
        documents: %w[.pdf .docx],
        images: %w[.jpg .jpeg .png .gif .bmp .webp .svg .ico .tiff .tif],
        audio: %w[.mp3 .wav .m4a .flac .ogg .aac .wma],
        video: %w[.mp4 .mov .avi .webm .mkv]
      }
    end

    private

    def convert_text_based_document(file_path, document_type)
      service = Ragdoll::TextExtractionService.new(file_path, document_type)
      service.extract
    end

    def convert_image_to_text(file_path)
      service = Ragdoll::ImageToTextService.new(@options)
      service.convert(file_path)
    end

    def convert_audio_to_text(file_path)
      service = Ragdoll::AudioToTextService.new(@options)
      service.transcribe(file_path)
    end

    def convert_video_to_text(file_path)
      # For video files, we'll extract audio and transcribe it
      # This is a simplified approach - in production you might want to:
      # 1. Extract keyframes as images and describe them
      # 2. Extract audio track and transcribe it
      # 3. Combine both approaches

      begin
        # Try to extract basic metadata
        video_info = extract_video_metadata(file_path)
        audio_text = attempt_video_audio_extraction(file_path)

        if audio_text && !audio_text.empty?
          if video_info
            "Video content: #{video_info}\n\nAudio transcript: #{audio_text}"
          else
            "Video with audio transcript: #{audio_text}"
          end
        else
          video_info || generate_fallback_text(file_path, "video")
        end
      rescue StandardError => e
        puts "Warning: Video conversion failed: #{e.message}"
        generate_fallback_text(file_path, "video")
      end
    end

    def convert_unknown_document(file_path)
      # Try to read as text first
      begin
        content = File.read(file_path, encoding: "UTF-8")
        return content if looks_like_text?(content)
      rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        # Try with different encoding
        begin
          content = File.read(file_path, encoding: "ISO-8859-1")
                        .encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
          return content if looks_like_text?(content)
        rescue StandardError
          # Fall through to binary handling
        end
      rescue StandardError
        # Fall through to fallback
      end

      # If not readable as text, generate metadata-based description
      generate_fallback_text(file_path, "unknown")
    end

    def extract_video_metadata(file_path)
      # Basic video metadata extraction
      # In production, you might use ffmpeg or similar tools
      file_size = File.size(file_path)
      filename = File.basename(file_path, File.extname(file_path))

      # Extract meaningful parts from filename
      descriptive_parts = filename
                         .gsub(/[-_]+/, ' ')
                         .gsub(/([a-z])([A-Z])/, '\1 \2')
                         .split(' ')
                         .reject { |part| part.match?(/^\d+$/) }
                         .map(&:capitalize)

      if descriptive_parts.any?
        "Video: #{descriptive_parts.join(' ')} (#{format_file_size(file_size)})"
      else
        "Video file: #{File.basename(file_path)} (#{format_file_size(file_size)})"
      end
    end

    def attempt_video_audio_extraction(file_path)
      # Placeholder for video audio extraction
      # In production, you would:
      # 1. Use ffmpeg to extract audio track
      # 2. Save to temporary audio file
      # 3. Transcribe the audio file
      # 4. Clean up temporary file

      # For now, return nil to indicate no audio extraction
      nil
    end

    def looks_like_text?(content)
      # Simple heuristic to determine if content is text
      return false if content.empty?

      # Check for reasonable ratio of printable characters
      printable_chars = content.count(" -~")
      total_chars = content.length

      printable_ratio = printable_chars.to_f / total_chars
      printable_ratio > 0.8 && total_chars > 0
    end

    def generate_fallback_text(file_path, document_type)
      filename = File.basename(file_path)
      file_size = File.size(file_path)

      case document_type
      when "image"
        "Image file: #{filename} (#{format_file_size(file_size)})"
      when "audio"
        "Audio file: #{filename} (#{format_file_size(file_size)})"
      when "video"
        "Video file: #{filename} (#{format_file_size(file_size)})"
      else
        "Document: #{filename} (#{format_file_size(file_size)})"
      end
    end

    def format_file_size(size)
      units = %w[B KB MB GB TB]
      unit_index = 0

      while size >= 1024 && unit_index < units.length - 1
        size /= 1024.0
        unit_index += 1
      end

      if unit_index == 0
        "#{size} #{units[unit_index]}"
      else
        "#{size.round(1)} #{units[unit_index]}"
      end
    end
  end
end