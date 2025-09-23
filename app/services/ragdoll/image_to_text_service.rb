# frozen_string_literal: true

require "ruby_llm"
require "base64"
require "rmagick"

module Ragdoll
  class ImageToTextService
    class DescriptionError < StandardError; end

    DEFAULT_OPTIONS = {
      model: "gemma3",
      provider: :ollama,
      assume_model_exists: true,
      temperature: 0.2,
      detail_level: :comprehensive
    }.freeze

    DEFAULT_FALLBACK_OPTIONS = {
      model: "smollm2",
      provider: :ollama,
      assume_model_exists: true,
      temperature: 0.4
    }.freeze

    DETAIL_LEVELS = {
      minimal: "Provide a brief, one-sentence description of the image.",
      standard: "Describe the main elements, objects, and overall composition of the image.",
      comprehensive: "Provide a detailed description including objects, people, settings, colors, mood, style, and any text visible in the image.",
      analytical: "Analyze the image thoroughly, describing composition, lighting, subjects, background, context, and any symbolic or artistic elements."
    }.freeze

    def self.convert(file_path, **options)
      new(**options).convert(file_path)
    end

    def initialize(primary: DEFAULT_OPTIONS, fallback: DEFAULT_FALLBACK_OPTIONS, **options)
      @options = DEFAULT_OPTIONS.merge(options)
      @detail_level = @options[:detail_level] || :comprehensive

      configure_ruby_llm_globally

      # Setup primary model
      primary_opts = primary.dup
      primary_temp = primary_opts.delete(:temperature) || 0.2
      @primary_prompt = build_prompt(@detail_level)

      begin
        @primary = RubyLLM.chat(**primary_opts).with_temperature(primary_temp)
      rescue StandardError => e
        puts "❌ ImageToTextService: Primary model creation failed: #{e.message}"
        @primary = nil
      end

      # Setup fallback model
      fallback_opts = fallback.dup
      fallback_temp = fallback_opts.delete(:temperature) || 0.4

      begin
        @fallback = RubyLLM.chat(**fallback_opts).with_temperature(fallback_temp)
      rescue StandardError => e
        puts "❌ ImageToTextService: Fallback model creation failed: #{e.message}"
        @fallback = nil
      end

      if @primary.nil? && @fallback.nil?
        puts "⚠️  ImageToTextService: WARNING - No models available! Service will return metadata-based descriptions only."
      end
    end

    def convert(file_path)
      return "" unless File.exist?(file_path)
      return "" unless image_file?(file_path)

      start_time = Time.now
      @image_path = file_path

      # Try to read image and prepare data
      begin
        @image = Magick::Image.read(@image_path).first
        image_data = prepare_image_data
        return generate_fallback_description unless image_data
      rescue StandardError => e
        puts "❌ ImageToTextService: Failed to read image: #{e.message}"
        return generate_fallback_description
      end

      # Attempt vision model description
      if @primary
        description = attempt_vision_description(image_data)
        if description && !description.empty?
          elapsed = Time.now - start_time
          puts "✅ ImageToTextService: Vision description generated (#{elapsed.round(2)}s)"
          return description
        end
      end

      # Attempt fallback model with metadata
      if @fallback
        description = attempt_fallback_description
        if description && !description.empty?
          elapsed = Time.now - start_time
          puts "✅ ImageToTextService: Fallback description generated (#{elapsed.round(2)}s)"
          return description
        end
      end

      # Final fallback to metadata-based description
      elapsed = Time.now - start_time
      puts "🔚 ImageToTextService: Using metadata-based description (#{elapsed.round(2)}s)"
      generate_fallback_description
    end

    def supported_formats
      %w[.jpg .jpeg .png .gif .bmp .webp .svg .ico .tiff .tif]
    end

    private

    def configure_ruby_llm_globally
      # Get Ragdoll configuration or use defaults
      ragdoll_config = begin
        Ragdoll.configuration
      rescue StandardError
        nil
      end

      ollama_endpoint = ragdoll_config&.ruby_llm_config&.dig(:ollama, :endpoint) ||
                       ENV.fetch("OLLAMA_API_BASE", ENV.fetch("OLLAMA_ENDPOINT", "http://localhost:11434"))

      RubyLLM.configure do |config|
        config.openai_api_key         = ENV.fetch("OPENAI_API_KEY", nil)
        config.openai_organization_id = ENV.fetch("OPENAI_ORGANIZATION_ID", nil)
        config.openai_project_id      = ENV.fetch("OPENAI_PROJECT_ID", nil)
        config.anthropic_api_key      = ENV.fetch("ANTHROPIC_API_KEY", nil)
        config.gemini_api_key         = ENV.fetch("GEMINI_API_KEY", nil)
        config.deepseek_api_key       = ENV.fetch("DEEPSEEK_API_KEY", nil)
        config.openrouter_api_key     = ENV.fetch("OPENROUTER_API_KEY", nil)
        config.bedrock_api_key        = ENV.fetch("BEDROCK_ACCESS_KEY_ID", nil)
        config.bedrock_secret_key     = ENV.fetch("BEDROCK_SECRET_ACCESS_KEY", nil)
        config.bedrock_region         = ENV.fetch("BEDROCK_REGION", nil)
        config.bedrock_session_token  = ENV.fetch("BEDROCK_SESSION_TOKEN", nil)
        config.ollama_api_base        = ollama_endpoint
        config.openai_api_base        = ENV.fetch("OPENAI_API_BASE", nil)
        config.log_level              = :error
      end
    rescue StandardError => e
      puts "❌ ImageToTextService: Failed to configure RubyLLM: #{e.message}"
    end

    def build_prompt(detail_level)
      base_instruction = DETAIL_LEVELS[detail_level] || DETAIL_LEVELS[:comprehensive]

      case detail_level
      when :analytical
        <<~PROMPT
          #{base_instruction}

          Please organize your analysis into these sections:
          1. Visual Elements: Objects, people, animals, and their relationships
          2. Setting & Environment: Location, time of day, weather, atmosphere
          3. Technical Aspects: Lighting, composition, colors, perspective
          4. Text & Symbols: Any visible text, signs, logos, or symbolic elements
          5. Context & Meaning: Possible purpose, story, or message conveyed

          Provide a thorough but concise analysis suitable for search and retrieval.
        PROMPT
      when :comprehensive
        <<~PROMPT
          #{base_instruction}

          Include details about:
          - Main subjects and their actions or poses
          - Setting, background, and environment
          - Colors, lighting, and mood
          - Any text, signs, or readable elements
          - Style or artistic elements
          - Objects and their relationships

          Write in a natural, descriptive style that would help someone understand the image content for search purposes.
        PROMPT
      else
        base_instruction
      end
    end

    def attempt_vision_description(image_data)
      begin
        @primary.add_message(
          role: "user",
          content: [
            { type: "text", text: @primary_prompt },
            { type: "image_url", image_url: { url: "data:#{@image.mime_type};base64,#{image_data}" } }
          ]
        )

        response = @primary.complete
        description = extract_description(response)
        clean_description(description)
      rescue StandardError => e
        puts "❌ ImageToTextService: Vision model failed: #{e.message}"
        nil
      end
    end

    def attempt_fallback_description
      begin
        prompt = build_fallback_prompt
        response = @fallback.ask(prompt).content
        clean_description(response)
      rescue StandardError => e
        puts "❌ ImageToTextService: Fallback model failed: #{e.message}"
        nil
      end
    end

    def build_fallback_prompt
      <<~PROMPT
        Based on the image file information below, generate a descriptive analysis of what this image likely contains:

        **File Information:**
        - Path: #{@image_path}
        - Filename: #{File.basename(@image_path)}
        - Dimensions: #{@image.columns}x#{@image.rows} pixels
        - Format: #{@image.mime_type}
        - File Size: #{@image.filesize} bytes
        - Colors: #{@image.number_colors} unique colors

        **Analysis Request:**
        Consider the filename, aspect ratio (#{aspect_ratio_description}), file format, and size to make educated guesses about:
        1. What type of image this might be (photo, diagram, artwork, screenshot, etc.)
        2. Possible subject matter based on filename and characteristics
        3. Likely content based on image properties

        Provide a thoughtful description that could be useful for search and categorization, even without seeing the actual image content.
      PROMPT
    end

    def image_file?(file_path)
      extension = File.extname(file_path).downcase
      supported_formats.include?(extension)
    end

    def prepare_image_data
      Base64.strict_encode64(File.binread(@image_path))
    rescue StandardError
      nil
    end

    def extract_description(response)
      if response.respond_to?(:content)
        response.content
      elsif response.is_a?(Hash) && response.dig("choices", 0, "message", "content")
        response["choices"][0]["message"]["content"]
      else
        nil
      end
    end

    def clean_description(description)
      return nil unless description.is_a?(String)

      cleaned = description
                .strip
                .sub(/\ADescription:?:?\s*/i, "")
                .sub(/\AImage:?\s*/i, "")
                .gsub(/\s+/, " ")
                .gsub(@image_path, File.basename(@image_path))
                .strip

      # Ensure it ends with punctuation
      cleaned << "." unless cleaned =~ /[.!?]\z/
      cleaned
    end

    def generate_fallback_description
      filename = File.basename(@image_path, File.extname(@image_path))

      # Try to extract meaningful information from filename
      descriptive_parts = filename
                         .gsub(/[-_]+/, ' ')
                         .gsub(/([a-z])([A-Z])/, '\1 \2')
                         .split(' ')
                         .reject { |part| part.match?(/^\d+$/) }  # Remove pure numbers
                         .map(&:capitalize)

      if descriptive_parts.any?
        base_description = "Image: #{descriptive_parts.join(' ')}"
      else
        base_description = "Image file: #{File.basename(@image_path)}"
      end

      # Add technical details if available
      if @image
        details = []
        details << "#{@image.columns}x#{@image.rows}"
        details << aspect_ratio_description
        details << File.extname(@image_path).upcase.sub('.', '') + " format"

        "#{base_description} (#{details.join(', ')})"
      else
        base_description
      end
    end

    def aspect_ratio_description
      return "unknown aspect ratio" unless @image

      ratio = @image.columns.to_f / @image.rows.to_f

      case ratio
      when 0.9..1.1 then "square"
      when 1.1..1.5 then "landscape"
      when 1.5..2.0 then "wide landscape"
      when 2.0..Float::INFINITY then "panoramic"
      when 0.5..0.9 then "portrait"
      when 0.0..0.5 then "tall portrait"
      else "unusual aspect ratio"
      end
    end
  end
end