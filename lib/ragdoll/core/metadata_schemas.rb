# frozen_string_literal: true

module Ragdoll
  module Core
    # Document metadata schemas for LLM structured output
    # Each document type has a specific schema that guides LLM generation
    module MetadataSchemas
      # Text document metadata schema
      TEXT_SCHEMA = {
        type: "object",
        properties: {
          summary: {
            type: "string",
            description: "Concise summary of the text content (2-3 paragraphs)"
          },
          keywords: {
            type: "array",
            items: { type: "string" },
            description: "Relevant keywords and phrases extracted from the text",
            maxItems: 10
          },
          classification: {
            type: "string",
            enum: %w[research article blog documentation technical legal financial marketing other],
            description: "Document classification category"
          },
          topics: {
            type: "array",
            items: { type: "string" },
            description: "Main topics discussed in the document",
            maxItems: 5
          },
          sentiment: {
            type: "string",
            enum: %w[positive negative neutral mixed],
            description: "Overall sentiment of the text"
          },
          reading_time_minutes: {
            type: "integer",
            description: "Estimated reading time in minutes"
          },
          language: {
            type: "string",
            description: "Primary language of the text (ISO 639-1 code)"
          },
          complexity_level: {
            type: "string",
            enum: %w[beginner intermediate advanced expert],
            description: "Complexity/difficulty level of the content"
          },
          tags: {
            type: "array",
            items: { type: "string" },
            description: "User-defined or AI-suggested tags for organization"
          }
        },
        required: %w[summary keywords classification]
      }.freeze

      # Image document metadata schema
      IMAGE_SCHEMA = {
        type: "object",
        properties: {
          description: {
            type: "string",
            description: "Detailed description of what is shown in the image"
          },
          summary: {
            type: "string",
            description: "Brief summary of the image content (1 paragraph)"
          },
          objects: {
            type: "array",
            items: { type: "string" },
            description: "List of objects, people, or items visible in the image",
            maxItems: 15
          },
          scene_type: {
            type: "string",
            enum: %w[indoor outdoor portrait landscape diagram chart screenshot artwork photo other],
            description: "Type of scene or image category"
          },
          colors: {
            type: "array",
            items: { type: "string" },
            description: "Dominant colors in the image",
            maxItems: 5
          },
          style: {
            type: "string",
            enum: %w[photograph illustration diagram chart screenshot artwork technical drawing other],
            description: "Visual style or format of the image"
          },
          mood: {
            type: "string",
            enum: %w[professional casual formal technical artistic dramatic serene energetic other],
            description: "Overall mood or tone of the image"
          },
          text_content: {
            type: "string",
            description: "Any visible text in the image (OCR extracted)"
          },
          keywords: {
            type: "array",
            items: { type: "string" },
            description: "Relevant keywords for image search and categorization",
            maxItems: 10
          },
          classification: {
            type: "string",
            enum: %w[technical diagram photo artwork chart screenshot document other],
            description: "Image classification category"
          },
          tags: {
            type: "array",
            items: { type: "string" },
            description: "User-defined or AI-suggested tags for organization"
          }
        },
        required: %w[description summary scene_type classification]
      }.freeze

      # Audio document metadata schema
      AUDIO_SCHEMA = {
        type: "object",
        properties: {
          summary: {
            type: "string",
            description: "Summary of audio content (speech transcript summary or music description)"
          },
          content_type: {
            type: "string",
            enum: %w[speech music podcast interview lecture presentation sound_effect meeting other],
            description: "Type of audio content"
          },
          keywords: {
            type: "array",
            items: { type: "string" },
            description: "Relevant keywords extracted from transcript or describing music",
            maxItems: 10
          },
          classification: {
            type: "string",
            enum: %w[educational entertainment business technical musical interview podcast other],
            description: "Audio content classification"
          },
          topics: {
            type: "array",
            items: { type: "string" },
            description: "Main topics discussed (for speech) or musical elements (for music)",
            maxItems: 5
          },
          language: {
            type: "string",
            description: "Language of speech content (ISO 639-1 code) or N/A for music"
          },
          speakers: {
            type: "array",
            items: { type: "string" },
            description: "Number or names of speakers (for speech content)",
            maxItems: 10
          },
          mood: {
            type: "string",
            enum: %w[formal casual energetic calm professional educational entertaining informative other],
            description: "Overall mood or tone of the audio"
          },
          genre: {
            type: "string",
            description: "Music genre (for musical content) or speech type (for spoken content)"
          },
          key_quotes: {
            type: "array",
            items: { type: "string" },
            description: "Important quotes or phrases from speech content",
            maxItems: 3
          },
          tags: {
            type: "array",
            items: { type: "string" },
            description: "User-defined or AI-suggested tags for organization"
          }
        },
        required: %w[summary content_type classification]
      }.freeze

      # PDF document metadata schema (combines text analysis with document structure)
      PDF_SCHEMA = {
        type: "object",
        properties: {
          summary: {
            type: "string",
            description: "Summary of the PDF document content"
          },
          document_type: {
            type: "string",
            enum: %w[research_paper report manual presentation legal financial technical academic other],
            description: "Type of PDF document"
          },
          keywords: {
            type: "array",
            items: { type: "string" },
            description: "Keywords extracted from the document text",
            maxItems: 15
          },
          classification: {
            type: "string",
            enum: %w[academic business legal technical manual report presentation other],
            description: "Document classification category"
          },
          topics: {
            type: "array",
            items: { type: "string" },
            description: "Main topics covered in the document",
            maxItems: 8
          },
          structure: {
            type: "object",
            properties: {
              has_table_of_contents: { type: "boolean" },
              has_bibliography: { type: "boolean" },
              has_figures: { type: "boolean" },
              has_tables: { type: "boolean" },
              estimated_pages: { type: "integer" }
            }
          },
          reading_time_minutes: {
            type: "integer",
            description: "Estimated reading time in minutes"
          },
          complexity_level: {
            type: "string",
            enum: %w[beginner intermediate advanced expert],
            description: "Complexity level of the content"
          },
          language: {
            type: "string",
            description: "Primary language of the document"
          },
          tags: {
            type: "array",
            items: { type: "string" },
            description: "User-defined or AI-suggested tags for organization"
          }
        },
        required: %w[summary document_type classification]
      }.freeze

      # Mixed/multi-modal document metadata schema
      MIXED_SCHEMA = {
        type: "object",
        properties: {
          summary: {
            type: "string",
            description: "Overall summary combining all content types in the document"
          },
          content_types: {
            type: "array",
            items: { type: "string", enum: %w[text image audio] },
            description: "Types of content present in this multi-modal document"
          },
          primary_content_type: {
            type: "string",
            enum: %w[text image audio],
            description: "The primary or dominant content type"
          },
          keywords: {
            type: "array",
            items: { type: "string" },
            description: "Keywords extracted from all content types",
            maxItems: 15
          },
          classification: {
            type: "string",
            enum: %w[multimedia_presentation research educational marketing technical training other],
            description: "Multi-modal document classification"
          },
          topics: {
            type: "array",
            items: { type: "string" },
            description: "Main topics across all content types",
            maxItems: 8
          },
          cohesion_analysis: {
            type: "string",
            description: "How well the different content types work together"
          },
          tags: {
            type: "array",
            items: { type: "string" },
            description: "User-defined or AI-suggested tags for organization"
          }
        },
        required: %w[summary content_types primary_content_type classification]
      }.freeze

      # Get schema for document type
      def self.schema_for(document_type)
        case document_type.to_s.downcase
        when "text", "markdown", "html"
          TEXT_SCHEMA
        when "image"
          IMAGE_SCHEMA
        when "audio"
          AUDIO_SCHEMA
        when "pdf", "docx"
          PDF_SCHEMA
        when "mixed"
          MIXED_SCHEMA
        else
          TEXT_SCHEMA # fallback
        end
      end

      # Get required fields for document type
      def self.required_fields_for(document_type)
        schema_for(document_type)[:required] || []
      end

      # Validate metadata against schema
      def self.validate_metadata(document_type, metadata)
        schema = schema_for(document_type)
        required_fields = schema[:required] || []

        errors = []
        required_fields.each do |field|
          errors << "Missing required field: #{field}" unless metadata.key?(field)
        end

        errors
      end
    end
  end
end
