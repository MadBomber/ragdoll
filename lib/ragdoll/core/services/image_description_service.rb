# frozen_string_literal: true

# Image description service using RubyLLM

require "ruby_llm"
require "base64"
require "rmagick"

module Ragdoll
  module Core
    module Services
      class ImageDescriptionService
        class DescriptionError < StandardError; end

        DEFAULT_OPTIONS = {
          model: "gemma3",
          provider: :ollama,
          assume_model_exists: true, # Bypass registry check
          temperature: 0.4,
          prompt: "Describe the image in detail."
        }.freeze

        DEFAULT_FALLBACK_OPTIONS = {
          model: "smollm2",
          provider: :ollama,
          assume_model_exists: true, # Bypass LLM registry check
          temperature: 0.6
        }.freeze

        def initialize(primary: DEFAULT_OPTIONS, fallback: DEFAULT_FALLBACK_OPTIONS)
          puts "🚀 ImageDescriptionService: Initializing with primary: #{primary.inspect}"
          puts "🚀 ImageDescriptionService: Initializing with fallback: #{fallback.inspect}"

          # Configure RubyLLM using the same pattern as the working example
          configure_ruby_llm_globally

          primary_temp    = primary.delete(:temperature) || DEFAULT_OPTIONS[:temperature]
          @primary_prompt = primary.delete(:prompt) || DEFAULT_OPTIONS[:prompt]
          fallback_temp   = fallback.delete(:temperature) || DEFAULT_FALLBACK_OPTIONS[:temperature]

          puts "🤖 ImageDescriptionService: Attempting to create primary model..."
          begin
            @primary = RubyLLM.chat(**primary).with_temperature(primary_temp)
            puts "✅ ImageDescriptionService: Primary model created successfully: #{@primary.class}"
          rescue StandardError => e
            puts "❌ ImageDescriptionService: Primary model creation failed: #{e.message}"
            @primary = nil
          end

          puts "🔄 ImageDescriptionService: Attempting to create fallback model..."
          begin
            @fallback = RubyLLM.chat(**fallback).with_temperature(fallback_temp)
            puts "✅ ImageDescriptionService: Fallback model created successfully: #{@fallback.class}"
          rescue StandardError => e
            puts "❌ ImageDescriptionService: Fallback model creation failed: #{e.message}"
            @fallback = nil
          end

          return unless @primary.nil? && @fallback.nil?

          puts "⚠️  ImageDescriptionService: WARNING - No models available! Service will return placeholders only."
        end

        # Generate a description for a local image file.
        # path (String) - absolute path to the image
        def generate_description(path)
          puts "🔍 ImageDescriptionService: Starting description generation for #{path}"
          start_time = Time.now

          @image_path = path
          return "" unless @image_path && File.exist?(@image_path) && image_file?

          # Attempt to read image and prepare data; on failure return placeholder
          data = nil
          begin
            puts "📸 ImageDescriptionService: Reading image with Magick..."
            @image = Magick::Image.read(@image_path).first
            data = prepare_image_data
            puts "✅ ImageDescriptionService: Image data prepared (#{data.length} chars base64)"
          rescue StandardError => e
            puts "❌ ImageDescriptionService: Failed to read image: #{e.message}"
            return "[Image file: #{File.basename(@image_path)}]"
          end
          return "" unless data

          # Attempt vision model call if client available
          if @primary
            puts "🤖 ImageDescriptionService: Attempting primary model (#{@primary.inspect})"
            begin
              @primary.add_message(
                role: "user",
                content: [
                  { type: "text", text: @primary_prompt },
                  { type: "image_url", image_url: { url: "data:#{@image.mime_type};base64,#{data}" } }
                ]
              )
              puts "📤 ImageDescriptionService: Calling primary model complete()..."
              response = @primary.complete
              puts "📥 ImageDescriptionService: Primary model response received: #{response.inspect}"
              desc = extract_description(response)
              if desc && !desc.empty?
                elapsed = Time.now - start_time
                puts "✅ ImageDescriptionService: Primary model success! Description: '#{desc[0..100]}...' (#{elapsed.round(2)}s)"
                return desc
              end
            rescue StandardError => e
              puts "❌ ImageDescriptionService: Primary model failed: #{e.message}"
            end
          else
            puts "⚠️  ImageDescriptionService: No primary model available"
          end

          # Attempt fallback if available
          if @fallback
            puts "🔄 ImageDescriptionService: Attempting fallback model (#{@fallback.inspect})"
            begin
              fallback_response = @fallback.ask(fallback_prompt).content
              elapsed = Time.now - start_time
              puts "✅ ImageDescriptionService: Fallback model success! Description: '#{fallback_response[0..100]}...' (#{elapsed.round(2)}s)"
              return fallback_response
            rescue StandardError => e
              puts "❌ ImageDescriptionService: Fallback model failed: #{e.message}"
            end
          else
            puts "⚠️  ImageDescriptionService: No fallback model available"
          end

          # Default placeholder when LLM unavailable
          elapsed = Time.now - start_time
          puts "🔚 ImageDescriptionService: Returning placeholder after #{elapsed.round(2)}s"
          "[Image file: #{File.basename(@image_path)}]"
        end

        private

        def configure_ruby_llm_globally
          puts "⚙️  ImageDescriptionService: Configuring RubyLLM globally..."

          # Get Ragdoll configuration or use defaults
          ragdoll_config = begin
            Ragdoll::Core.configuration
          rescue StandardError
            nil
          end
          # FIXME: ollama_url is not in current config structure, should use ruby_llm_config[:ollama][:endpoint]
          ollama_endpoint = ragdoll_config&.ruby_llm_config&.dig(:ollama, :endpoint) || ENV["OLLAMA_API_BASE"] || ENV["OLLAMA_ENDPOINT"] || "http://localhost:11434"

          puts "🔗 ImageDescriptionService: Using ollama endpoint: #{ollama_endpoint}"

          # Follow the exact pattern from the working example
          RubyLLM.configure do |config|
            # Set all provider configs like the working example
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

            # Key: Use the exact same method name as the working example
            config.ollama_api_base        = ollama_endpoint
            config.openai_api_base        = ENV.fetch("OPENAI_API_BASE", nil)
            config.log_level              = :error
          end

          puts "✅ ImageDescriptionService: RubyLLM configured successfully with global settings"
        rescue StandardError => e
          puts "❌ ImageDescriptionService: Failed to configure RubyLLM: #{e.message}"
        end

        def image_file?
          %w[.jpg .jpeg .png .gif .bmp .webp .svg .ico .tiff
             .tif].include?(File.extname(@image_path).downcase)
        end

        def prepare_image_data
          Base64.strict_encode64(File.binread(@image_path))
        rescue StandardError
          nil
        end

        def extract_description(response)
          text = if response.respond_to?(:content)
                   response.content
                 elsif response.is_a?(Hash) && response.dig("choices", 0, "message", "content")
                   response["choices"][0]["message"]["content"]
                 end
          clean_description(text)
        end

        def clean_description(description)
          return unless description.is_a?(String)

          cleaned = description
                    .strip
                    .sub(/\ADescription:?:?\s*/i, "")
                    .gsub(/\s+/, " ")
                    .gsub(@image_path, "")
                    .strip
          cleaned << "." unless cleaned =~ /[.!?]\z/
          cleaned
        end

        def fallback_prompt
          <<~PROMPT
            You are a text-based AI tasked with generating a descriptive guess about an image based on its physical characteristics and the absolute pathname provided.

            Please consider the following details:

            1. **Absolute Pathname:** #{@image_path}
            2. **Image Characteristics:**
               - **Width:** #{@image.columns}
               - **Height:** #{@image.rows}
               - **MIME/Type:** #{@image.mime_type}
               - **File Size:** #{@image.filesize} bytes
               - **Number of Colors:** #{@image.number_colors}

            Based on the above information, please make your best guess about what the image might depict. Consider common uses for the file format, the aspect ratio, and any hints from the pathname itself. Provide provide your best guess as a brief description that includes potential subjects, themes, or contexts of the image.

          PROMPT
        end
      end
    end
  end
end
