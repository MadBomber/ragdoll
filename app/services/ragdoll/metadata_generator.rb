# frozen_string_literal: true

module Ragdoll
  # Service for generating structured metadata using LLM providers
  # Leverages structured output capabilities to ensure consistent metadata schemas
  class MetadataGenerator
    def initialize(llm_client: nil)
      @llm_client = llm_client || default_llm_client
    end

    # Generate metadata for a document based on its content and type
    def generate_for_document(document)
      case document.document_type
      when "text", "markdown", "html"
        generate_text_metadata(document)
      when "image"
        generate_image_metadata(document)
      when "audio"
        generate_audio_metadata(document)
      when "pdf", "docx"
        generate_pdf_metadata(document)
      when "mixed"
        generate_mixed_metadata(document)
      else
        generate_text_metadata(document) # fallback
      end
    end

    # Generate metadata for text content
    def generate_text_metadata(document)
      # Combine all text content from the document
      text_content = document.text_contents.map(&:content).join("\n\n")
      return {} if text_content.blank?

      schema = Ragdoll::MetadataSchemas::TEXT_SCHEMA
      prompt = build_text_analysis_prompt(text_content)

      generate_structured_metadata(prompt, schema)
    end

    # Generate metadata for image content
    def generate_image_metadata(document)
      # For images, we need to use vision-capable models
      image_content = document.image_contents.first
      return {} unless image_content&.image_attached?

      schema = Ragdoll::MetadataSchemas::IMAGE_SCHEMA
      prompt = build_image_analysis_prompt(image_content)

      # This would use a vision model like GPT-4V, Claude 3, etc.
      generate_structured_metadata(prompt, schema, content_type: "image", image: image_content.image)
    end

    # Generate metadata for audio content
    def generate_audio_metadata(document)
      audio_content = document.audio_contents.first
      return {} unless audio_content

      schema = Ragdoll::MetadataSchemas::AUDIO_SCHEMA

      # Use transcript if available, otherwise analyze audio directly
      prompt = if audio_content.transcript.present?
                 build_audio_transcript_analysis_prompt(audio_content.transcript, audio_content.duration)
               else
                 # This would require audio-capable models or speech-to-text preprocessing
                 build_audio_analysis_prompt(audio_content)
               end

      generate_structured_metadata(prompt, schema)
    end

    # Generate metadata for PDF content
    def generate_pdf_metadata(document)
      text_content = document.text_contents.map(&:content).join("\n\n")
      return {} if text_content.blank?

      schema = Ragdoll::MetadataSchemas::PDF_SCHEMA
      prompt = build_pdf_analysis_prompt(text_content, document.file_metadata)

      generate_structured_metadata(prompt, schema)
    end

    # Generate metadata for mixed/multi-modal content
    def generate_mixed_metadata(document)
      schema = Ragdoll::MetadataSchemas::MIXED_SCHEMA

      # Combine analysis from all content types
      content_summaries = []

      document.text_contents.each do |text|
        content_summaries << { type: "text", content: text.content[0..500] }
      end

      document.image_contents.each do |image|
        content_summaries << { type: "image", description: image.description || "Image content" }
      end

      document.audio_contents.each do |audio|
        content_summaries << { type: "audio", transcript: audio.transcript || "Audio content" }
      end

      prompt = build_mixed_analysis_prompt(content_summaries)
      generate_structured_metadata(prompt, schema)
    end

    private

    # Core method for generating structured metadata using LLM
    def generate_structured_metadata(prompt, schema, content_type: "text", image: nil)
      case @llm_client&.provider
      when "openai"
        generate_with_openai(prompt, schema, content_type, image)
      when "anthropic"
        generate_with_anthropic(prompt, schema, content_type, image)
      when "ollama"
        generate_with_ollama(prompt, schema)
      else
        # Fallback to basic LLM call without structured output
        generate_with_fallback(prompt, schema)
      end
    rescue StandardError => e
      Rails.logger.error "Metadata generation failed: #{e.message}" if defined?(Rails)
      puts "Metadata generation failed: #{e.message}"
      {}
    end

    # OpenAI structured output
    def generate_with_openai(prompt, schema, content_type, image)
      messages = build_messages(prompt, content_type, image)

      response = @llm_client.chat(
        model: "gpt-4o", # Use latest model with structured output
        messages: messages,
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "document_metadata",
            schema: schema
          }
        },
        temperature: 0.1
      )

      JSON.parse(response.dig("choices", 0, "message", "content") || "{}")
    end

    # Anthropic structured output (using XML format)
    def generate_with_anthropic(prompt, schema, content_type, image)
      # Anthropic doesn't have native JSON schema support yet
      # Use XML format with clear instructions
      structured_prompt = "#{prompt}\n\nPlease respond with a JSON object that follows this exact schema:\n#{schema.to_json}\n\nRespond only with valid JSON, no explanations."

      messages = build_messages(structured_prompt, content_type, image)

      response = @llm_client.chat(
        model: "claude-3-5-sonnet-20241022",
        messages: messages,
        temperature: 0.1
      )

      # Extract JSON from response
      content = response.dig("content", 0, "text") || "{}"
      JSON.parse(content.match(/\{.*\}/m)&.to_s || "{}")
    end

    # Ollama structured output (using Llama 3.1 or similar)
    def generate_with_ollama(prompt, schema)
      structured_prompt = "#{prompt}\n\nRespond with valid JSON matching this schema:\n#{schema.to_json}"

      response = @llm_client.generate(
        model: "llama3.1:8b",
        prompt: structured_prompt,
        format: "json",
        options: { temperature: 0.1 }
      )

      JSON.parse(response["response"] || "{}")
    end

    # Fallback for any LLM provider
    def generate_with_fallback(prompt, schema)
      structured_prompt = "#{prompt}\n\nPlease respond with a JSON object that includes these fields: #{schema[:required]&.join(', ')}\n\nRespond only with valid JSON."

      response = @llm_client.generate(prompt: structured_prompt)
      JSON.parse(response || "{}")
    rescue JSON::ParserError
      {}
    end

    # Build messages array for chat-based APIs
    def build_messages(prompt, content_type, image)
      messages = [
        {
          role: "system",
          content: "You are an expert document analyzer. Generate structured metadata as valid JSON following the provided schema exactly."
        }
      ]

      messages << if content_type == "image" && image
                    {
                      role: "user",
                      content: [
                        { type: "text", text: prompt },
                        { type: "image_url", image_url: { url: image_url_for(image) } }
                      ]
                    }
                  else
                    { role: "user", content: prompt }
                  end

      messages
    end

    # Build analysis prompts for different content types
    def build_text_analysis_prompt(text_content)
      <<~PROMPT
        Analyze the following text document and extract structured metadata:

        #{text_content[0..2000]}#{text_content.length > 2000 ? '...' : ''}

        Please analyze this text and provide comprehensive metadata including:
        - A concise summary (2-3 sentences)
        - Relevant keywords and topics
        - Document classification and complexity level
        - Sentiment analysis
        - Estimated reading time
        - Language detection
      PROMPT
    end

    def build_image_analysis_prompt(image_content)
      existing_description = image_content.description || image_content.alt_text
      base_prompt = <<~PROMPT
        Analyze this image and provide comprehensive metadata including:
        - Detailed description of what's shown
        - Objects, people, or elements visible
        - Scene type and visual style
        - Dominant colors and mood
        - Any visible text content
        - Relevant keywords for search
      PROMPT

      if existing_description.present?
        "#{base_prompt}\n\nExisting description: #{existing_description}"
      else
        base_prompt
      end
    end

    def build_audio_transcript_analysis_prompt(transcript, duration)
      <<~PROMPT
        Analyze the following audio transcript and provide metadata:

        Duration: #{duration} seconds
        Transcript: #{transcript[0..1500]}#{transcript.length > 1500 ? '...' : ''}

        Please analyze this audio content and provide:
        - Summary of the spoken content
        - Content type (speech, music, podcast, etc.)
        - Topics discussed
        - Number of speakers
        - Language and mood
        - Key quotes or important phrases
      PROMPT
    end

    def build_audio_analysis_prompt(audio_content)
      <<~PROMPT
        Analyze this audio file and provide metadata:

        Duration: #{audio_content.duration} seconds
        Sample Rate: #{audio_content.sample_rate} Hz

        Please determine:
        - Type of audio content (speech, music, sound effects, etc.)
        - If music: genre, mood, instruments
        - If speech: estimated number of speakers, formality level
        - Overall audio characteristics
      PROMPT
    end

    def build_pdf_analysis_prompt(text_content, file_metadata)
      <<~PROMPT
        Analyze this PDF document and provide structured metadata:

        File info: #{file_metadata}
        Content preview: #{text_content[0..2000]}#{text_content.length > 2000 ? '...' : ''}

        Please analyze this PDF and provide:
        - Document type and classification
        - Summary of content
        - Topics and keywords
        - Document structure analysis
        - Complexity level
        - Estimated reading time
      PROMPT
    end

    def build_mixed_analysis_prompt(content_summaries)
      content_desc = content_summaries.map { |c| "#{c[:type]}: #{c.values[1]}" }.join("\n\n")

      <<~PROMPT
        Analyze this multi-modal document containing different types of content:

        #{content_desc}

        Please provide comprehensive metadata for this mixed-content document:
        - Overall summary combining all content types
        - How the different content types relate to each other
        - Primary vs secondary content types
        - Keywords spanning all content
        - Classification for the complete document
      PROMPT
    end

    # Utility methods
    def default_llm_client
      # This would integrate with your LLM client
      # Could use ruby_llm or direct API clients
      nil
    end

    def image_url_for(image)
      # Convert Shrine attachment to URL for vision APIs
      # This would need proper implementation based on your Shrine setup
      image.url if image.respond_to?(:url)
    end
  end
end