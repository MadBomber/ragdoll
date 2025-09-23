# frozen_string_literal: true

require "pdf-reader"
require "docx"
require "yaml"
require "json"

module Ragdoll
  class TextExtractionService
    class ExtractionError < StandardError; end

    def self.extract(file_path, document_type = nil)
      new(file_path, document_type).extract
    end

    def initialize(file_path, document_type = nil)
      @file_path = file_path
      @document_type = document_type || determine_document_type
      @file_extension = File.extname(file_path).downcase
    end

    def extract
      case @document_type
      when "pdf"
        extract_from_pdf
      when "docx"
        extract_from_docx
      when "text", "markdown"
        extract_from_text
      when "html"
        extract_from_html
      when "csv"
        extract_from_csv
      when "json"
        extract_from_json
      when "xml"
        extract_from_xml
      when "yaml"
        extract_from_yaml
      else
        extract_from_text # Default fallback
      end
    end

    private

    def determine_document_type
      case @file_extension
      when ".pdf" then "pdf"
      when ".docx" then "docx"
      when ".txt" then "text"
      when ".md", ".markdown" then "markdown"
      when ".html", ".htm" then "html"
      when ".csv" then "csv"
      when ".json" then "json"
      when ".xml" then "xml"
      when ".yml", ".yaml" then "yaml"
      else "text"
      end
    end

    def extract_from_pdf
      content = ""

      begin
        PDF::Reader.open(@file_path) do |reader|
          reader.pages.each_with_index do |page, index|
            page_text = page.text.strip
            next if page_text.empty?

            content += "\n\n--- Page #{index + 1} ---\n\n" if content.length.positive?
            content += page_text
          end
        end
      rescue PDF::Reader::MalformedPDFError => e
        raise ExtractionError, "Malformed PDF: #{e.message}"
      rescue PDF::Reader::UnsupportedFeatureError => e
        raise ExtractionError, "Unsupported PDF feature: #{e.message}"
      end

      content.strip
    end

    def extract_from_docx
      content = ""

      begin
        doc = Docx::Document.open(@file_path)

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
      rescue StandardError => e
        raise ExtractionError, "Failed to parse DOCX: #{e.message}"
      end

      content.strip
    end

    def extract_from_text
      begin
        content = File.read(@file_path, encoding: "UTF-8")
      rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        # Try with different encoding
        content = File.read(@file_path, encoding: "ISO-8859-1")
                      .encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
      rescue Errno::ENOENT, Errno::EACCES => e
        raise ExtractionError, "Failed to read file #{@file_path}: #{e.message}"
      end

      # Parse YAML front matter for markdown files
      if @document_type == "markdown" && content.start_with?("---\n")
        front_matter, body_content = parse_yaml_front_matter(content)
        content = body_content if front_matter
      end

      content
    end

    def extract_from_html
      content = File.read(@file_path, encoding: "UTF-8")

      # Basic HTML tag stripping
      clean_content = content
                      .gsub(%r{<script[^>]*>.*?</script>}mi, "") # Remove script tags
                      .gsub(%r{<style[^>]*>.*?</style>}mi, "")   # Remove style tags
                      .gsub(/<[^>]+>/, " ")                     # Remove all HTML tags
                      .gsub(/\s+/, " ")                         # Normalize whitespace
                      .strip

      clean_content
    end

    def parse_yaml_front_matter(content)
      return [nil, content] unless content.start_with?("---\n")

      lines = content.lines
      closing_index = nil

      lines.each_with_index do |line, index|
        next if index == 0 # Skip the opening ---
        if line.strip == "---"
          closing_index = index
          break
        end
      end

      return [nil, content] unless closing_index

      yaml_lines = lines[1...closing_index]
      body_lines = lines[(closing_index + 1)..-1]

      yaml_content = yaml_lines.join
      body_content = body_lines&.join || ""

      begin
        front_matter = YAML.safe_load(yaml_content, permitted_classes: [Time, Date])
        front_matter = front_matter.transform_keys(&:to_sym) if front_matter.is_a?(Hash)
        [front_matter, body_content.strip]
      rescue YAML::SyntaxError, Psych::DisallowedClass
        [nil, content]
      end
    end

    def extract_from_csv
      content = []

      begin
        # Simple CSV parsing without using the csv gem
        lines = File.readlines(@file_path, encoding: "UTF-8").map(&:strip).reject(&:empty?)
        return "Empty CSV file" if lines.empty?

        # Assume first line is headers
        header_line = lines.first
        headers = parse_csv_line(header_line)

        return "CSV file with only headers" if lines.length == 1

        # Process data rows
        lines[1..-1].each_with_index do |line, index|
          next if line.strip.empty?

          values = parse_csv_line(line)
          next if values.all?(&:empty?)

          # Create readable row format
          row_pairs = []
          headers.each_with_index do |header, col_index|
            value = values[col_index] || ""
            row_pairs << "#{header}: #{value}" unless value.empty?
          end

          content << row_pairs.join(", ") if row_pairs.any?
        end
      rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        # Try with different encoding
        begin
          lines = File.readlines(@file_path, encoding: "ISO-8859-1").map { |line|
            line.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?").strip
          }.reject(&:empty?)

          return "Empty CSV file" if lines.empty?

          header_line = lines.first
          headers = parse_csv_line(header_line)

          return "CSV file with only headers" if lines.length == 1

          lines[1..-1].each do |line|
            next if line.strip.empty?

            values = parse_csv_line(line)
            next if values.all?(&:empty?)

            row_pairs = []
            headers.each_with_index do |header, col_index|
              value = values[col_index] || ""
              row_pairs << "#{header}: #{value}" unless value.empty?
            end

            content << row_pairs.join(", ") if row_pairs.any?
          end
        rescue StandardError => e
          raise ExtractionError, "Failed to parse CSV with alternative encoding: #{e.message}"
        end
      rescue StandardError => e
        raise ExtractionError, "Failed to read CSV file: #{e.message}"
      end

      if content.empty?
        return "CSV file with no readable data"
      end

      "CSV Data:\n#{content.join("\n")}"
    end

    def parse_csv_line(line)
      # Simple CSV line parser that handles basic quoting
      return [] if line.strip.empty?

      fields = []
      current_field = ""
      in_quotes = false

      i = 0
      while i < line.length
        char = line[i]

        case char
        when '"'
          if in_quotes && i + 1 < line.length && line[i + 1] == '"'
            # Escaped quote
            current_field += '"'
            i += 1
          else
            # Toggle quote state
            in_quotes = !in_quotes
          end
        when ','
          if in_quotes
            current_field += char
          else
            # End of field
            fields << current_field.strip
            current_field = ""
          end
        else
          current_field += char
        end

        i += 1
      end

      # Add the last field
      fields << current_field.strip
      fields
    end

    def extract_from_json
      begin
        content = File.read(@file_path, encoding: "UTF-8")
        parsed_json = JSON.parse(content)

        # Convert JSON to readable text format
        convert_json_to_text(parsed_json)
      rescue JSON::ParserError => e
        raise ExtractionError, "Invalid JSON: #{e.message}"
      rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        # Try with different encoding
        begin
          content = File.read(@file_path, encoding: "ISO-8859-1")
                        .encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
          parsed_json = JSON.parse(content)
          convert_json_to_text(parsed_json)
        rescue StandardError => e
          raise ExtractionError, "Failed to parse JSON with alternative encoding: #{e.message}"
        end
      rescue StandardError => e
        raise ExtractionError, "Failed to read JSON file: #{e.message}"
      end
    end

    def extract_from_xml
      begin
        content = File.read(@file_path, encoding: "UTF-8")

        # Basic XML text extraction - remove tags and normalize whitespace
        clean_content = content
                        .gsub(%r{<!--.*?-->}m, "")  # Remove comments
                        .gsub(/<\?.*?\?>/m, "")     # Remove processing instructions
                        .gsub(/<[^>]+>/, " ")       # Remove all XML tags
                        .gsub(/\s+/, " ")           # Normalize whitespace
                        .strip

        if clean_content.empty?
          "XML document with no readable text content"
        else
          "XML Content:\n#{clean_content}"
        end
      rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        begin
          content = File.read(@file_path, encoding: "ISO-8859-1")
                        .encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")

          clean_content = content
                          .gsub(%r{<!--.*?-->}m, "")
                          .gsub(/<\?.*?\?>/m, "")
                          .gsub(/<[^>]+>/, " ")
                          .gsub(/\s+/, " ")
                          .strip

          if clean_content.empty?
            "XML document with no readable text content"
          else
            "XML Content:\n#{clean_content}"
          end
        rescue StandardError => e
          raise ExtractionError, "Failed to parse XML: #{e.message}"
        end
      rescue StandardError => e
        raise ExtractionError, "Failed to read XML file: #{e.message}"
      end
    end

    def extract_from_yaml
      begin
        content = File.read(@file_path, encoding: "UTF-8")
        parsed_yaml = YAML.safe_load(content, permitted_classes: [Time, Date])

        # Convert YAML to readable text format
        convert_yaml_to_text(parsed_yaml)
      rescue YAML::SyntaxError => e
        raise ExtractionError, "Invalid YAML: #{e.message}"
      rescue Psych::DisallowedClass => e
        raise ExtractionError, "YAML contains disallowed class: #{e.message}"
      rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        begin
          content = File.read(@file_path, encoding: "ISO-8859-1")
                        .encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
          parsed_yaml = YAML.safe_load(content, permitted_classes: [Time, Date])
          convert_yaml_to_text(parsed_yaml)
        rescue StandardError => e
          raise ExtractionError, "Failed to parse YAML with alternative encoding: #{e.message}"
        end
      rescue StandardError => e
        raise ExtractionError, "Failed to read YAML file: #{e.message}"
      end
    end

    def convert_json_to_text(obj, indent = 0)
      prefix = "  " * indent

      case obj
      when Hash
        if obj.empty?
          "Empty object"
        else
          lines = obj.map do |key, value|
            "#{prefix}#{key}: #{convert_json_to_text(value, indent + 1)}"
          end
          lines.join("\n")
        end
      when Array
        if obj.empty?
          "Empty array"
        else
          lines = obj.each_with_index.map do |item, index|
            "#{prefix}- #{convert_json_to_text(item, indent + 1)}"
          end
          lines.join("\n")
        end
      when String
        obj.length > 100 ? "#{obj[0..97]}..." : obj
      when Numeric, TrueClass, FalseClass, NilClass
        obj.to_s
      else
        obj.to_s
      end
    end

    def convert_yaml_to_text(obj, indent = 0)
      # YAML and JSON have similar structures, so we can reuse the conversion logic
      convert_json_to_text(obj, indent)
    end
  end
end