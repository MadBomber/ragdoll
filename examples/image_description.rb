#!/usr/bin/env ruby
# frozen_string_literal: true

require "debug_me"
include DebugMe

$DEBUG_ME = true

# Standalone example for generating image descriptions via RubyLLM
require_relative "../lib/ragdoll"

# Configure Ragdoll which will handle RubyLLM configuration internally
Ragdoll::Core.configure do |config|
  # Database configuration (optional for image description only)
  config.database_config = {
    adapter: "postgresql",
    database: "ragdoll_example",
    username: "ragdoll",
    password: ENV["RAGDOLL_DATABASE_PASSWORD"],
    host: "localhost",
    port: 5432,
    auto_migrate: false  # Don't auto-migrate for simple image description
  }

  # Configure Ruby LLM providers for image description
  config.ruby_llm_config[:openai][:api_key] = ENV["OPENAI_API_KEY"]
  config.ruby_llm_config[:openai][:organization] = ENV["OPENAI_ORGANIZATION_ID"]
  config.ruby_llm_config[:openai][:project] = ENV["OPENAI_PROJECT_ID"]
  config.ruby_llm_config[:anthropic][:api_key] = ENV["ANTHROPIC_API_KEY"]
  config.ruby_llm_config[:google][:api_key] = ENV["GEMINI_API_KEY"]
  config.ruby_llm_config[:ollama][:endpoint] = ENV.fetch("OLLAMA_ENDPOINT", "http://localhost:11434/v1")
  config.ruby_llm_config[:openrouter][:api_key] = ENV["OPENROUTER_API_KEY"]

  # Logging
  config.logging_config[:log_level] = :error
end

if ARGV.empty?
  puts "Usage: #{$PROGRAM_NAME} IMAGE_PATH [PROMPT]"
  puts ""
  puts "Examples:"
  puts "  #{$PROGRAM_NAME} /path/to/image.jpg"
  puts "  #{$PROGRAM_NAME} /path/to/image.png 'Describe this image in detail'"
  puts ""
  puts "Supported image formats: JPG, PNG, GIF, BMP, WEBP, SVG, ICO, TIFF"
  exit 1
end

image_path = ARGV.shift
custom_prompt = ARGV.shift

unless File.exist?(image_path)
  warn "Error: File not found - #{image_path}"
  warn "Please provide a valid path to an image file."
  exit 1
end

puts "🖼️  Analyzing image: #{File.basename(image_path)}"
puts "📁 Full path: #{image_path}"

begin
  # Create service with custom prompt if provided
  service_options = {}
  if custom_prompt
    service_options[:primary] = {
      model: "gemma3",
      provider: :ollama,
      assume_model_exists: true,
      temperature: 0.4,
      prompt: custom_prompt
    }
    puts "🎯 Using custom prompt: #{custom_prompt}"
  end

  service = if service_options.empty?
              Ragdoll::ImageDescriptionService.new
            else
              Ragdoll::ImageDescriptionService.new(**service_options)
            end

  puts "🤖 Generating description..."
  description = service.generate_description(image_path)

  puts "\n" + "="*50
  puts "📝 DESCRIPTION:"
  puts "="*50
  puts description
  puts "="*50

rescue => e
  warn "❌ Error processing image: #{e.message}"
  warn "🔍 Please check that:"
  warn "  - The image file exists and is readable"
  warn "  - You have the required dependencies installed (rmagick)"
  warn "  - Your LLM provider (Ollama) is running and accessible"
  exit 1
end
