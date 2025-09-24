# frozen_string_literal: true

require "ruby_llm"

module Ragdoll
  class AudioToTextService
    class TranscriptionError < StandardError; end

    DEFAULT_OPTIONS = {
      model: "whisper-1",
      provider: :openai,
      temperature: 0.0,
      language: nil # Auto-detect
    }.freeze

    def self.transcribe(file_path, **options)
      new(**options).transcribe(file_path)
    end

    def initialize(**options)
      @options = DEFAULT_OPTIONS.merge(options)
      configure_transcription_service
    end

    def transcribe(file_path)
      return "" unless File.exist?(file_path)
      return "" unless audio_file?(file_path)

      begin
        # Use RubyLLM for transcription
        # Note: This is a placeholder implementation
        # Real implementation would depend on the transcription service available

        if transcription_available?
          perform_transcription(file_path)
        else
          generate_fallback_transcript(file_path)
        end
      rescue StandardError => e
        puts "Warning: Audio transcription failed (#{e.message}), using fallback"
        generate_fallback_transcript(file_path)
      end
    end

    def supported_formats
      %w[.mp3 .wav .m4a .flac .ogg .aac .wma .mp4 .mov .avi .webm]
    end

    private

    def configure_transcription_service
      # Configure transcription service based on provider
      case @options[:provider]
      when :openai
        configure_openai_transcription
      when :azure
        configure_azure_transcription
      when :google
        configure_google_transcription
      when :whisper_local
        configure_local_whisper
      else
        puts "Warning: Unsupported transcription provider: #{@options[:provider]}"
      end
    end

    def configure_openai_transcription
      # OpenAI Whisper API configuration
      @api_key = ENV["OPENAI_API_KEY"]
      @endpoint = "https://api.openai.com/v1/audio/transcriptions"
    end

    def configure_azure_transcription
      # Azure Speech Services configuration
      @api_key = ENV["AZURE_SPEECH_KEY"]
      @region = ENV["AZURE_SPEECH_REGION"]
    end

    def configure_google_transcription
      # Google Cloud Speech-to-Text configuration
      @api_key = ENV["GOOGLE_CLOUD_API_KEY"]
      @project_id = ENV["GOOGLE_CLOUD_PROJECT_ID"]
    end

    def configure_local_whisper
      # Local Whisper installation configuration
      @whisper_command = `which whisper`.strip
    end

    def transcription_available?
      case @options[:provider]
      when :openai
        !@api_key.nil? && !@api_key.empty?
      when :azure
        !@api_key.nil? && !@api_key.empty? && !@region.nil?
      when :google
        !@api_key.nil? && !@api_key.empty?
      when :whisper_local
        !@whisper_command.empty? && File.executable?(@whisper_command)
      else
        false
      end
    end

    def perform_transcription(file_path)
      case @options[:provider]
      when :openai
        transcribe_with_openai(file_path)
      when :azure
        transcribe_with_azure(file_path)
      when :google
        transcribe_with_google(file_path)
      when :whisper_local
        transcribe_with_local_whisper(file_path)
      else
        raise TranscriptionError, "Unsupported transcription provider"
      end
    end

    def transcribe_with_openai(file_path)
      # Placeholder for OpenAI Whisper API implementation
      # This would use HTTP requests to OpenAI's API
      # For now, return a placeholder
      generate_fallback_transcript(file_path)
    end

    def transcribe_with_azure(file_path)
      # Placeholder for Azure Speech Services implementation
      generate_fallback_transcript(file_path)
    end

    def transcribe_with_google(file_path)
      # Placeholder for Google Cloud Speech-to-Text implementation
      generate_fallback_transcript(file_path)
    end

    def transcribe_with_local_whisper(file_path)
      # Use local Whisper installation
      output_file = "#{file_path}.txt"

      begin
        # Run whisper command
        command = "#{@whisper_command} \"#{file_path}\" --output_format txt --output_dir \"#{File.dirname(file_path)}\""
        command += " --language #{@options[:language]}" if @options[:language]
        command += " --temperature #{@options[:temperature]}"

        result = `#{command} 2>&1`

        if $?.success? && File.exist?(output_file)
          transcript = File.read(output_file)
          File.delete(output_file) # Cleanup
          transcript.strip
        else
          raise TranscriptionError, "Whisper command failed: #{result}"
        end
      rescue StandardError => e
        raise TranscriptionError, "Local Whisper transcription failed: #{e.message}"
      end
    end

    def audio_file?(file_path)
      extension = File.extname(file_path).downcase
      supported_formats.include?(extension)
    end

    def generate_fallback_transcript(file_path)
      filename = File.basename(file_path)
      duration = estimate_duration(file_path)

      if duration
        "[Audio file: #{filename} (#{format_duration(duration)})]"
      else
        "[Audio file: #{filename}]"
      end
    end

    def estimate_duration(file_path)
      # Try to get duration using file size estimation
      # This is very rough and not accurate
      begin
        file_size = File.size(file_path)
        # Rough estimation: 1MB per minute for compressed audio
        estimated_minutes = file_size / (1024 * 1024)
        estimated_minutes > 0 ? estimated_minutes : nil
      rescue StandardError
        nil
      end
    end

    def format_duration(minutes)
      if minutes < 60
        "#{minutes.round}m"
      else
        hours = minutes / 60
        remaining_minutes = minutes % 60
        "#{hours.round}h #{remaining_minutes.round}m"
      end
    end
  end
end