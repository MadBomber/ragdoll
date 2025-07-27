# frozen_string_literal: true

require "shrine"
require "shrine/storage/file_system"

# Configure Shrine with filesystem storage
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("tmp/uploads", prefix: "cache"),
  store: Shrine::Storage::FileSystem.new("uploads")
}

Shrine.plugin :activerecord
Shrine.plugin :cached_attachment_data
Shrine.plugin :restore_cached_data
Shrine.plugin :rack_file
Shrine.plugin :validation_helpers
Shrine.plugin :determine_mime_type

# File uploader for documents
class FileUploader < Shrine
  plugin :validation_helpers
  plugin :determine_mime_type

  Attacher.validate do
    validate_max_size 50.megabytes
    validate_mime_type %w[
      application/pdf
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      text/plain
      text/html
      text/markdown
      application/json
    ]
  end
end

# Image uploader for image content
class ImageUploader < Shrine
  plugin :validation_helpers
  plugin :determine_mime_type

  Attacher.validate do
    validate_max_size 10.megabytes
    validate_mime_type %w[
      image/jpeg
      image/png
      image/gif
      image/webp
      image/bmp
      image/tiff
    ]
  end
end

# Audio uploader for audio content
class AudioUploader < Shrine
  plugin :validation_helpers
  plugin :determine_mime_type

  Attacher.validate do
    validate_max_size 100.megabytes
    validate_mime_type %w[
      audio/mpeg
      audio/wav
      audio/mp4
      audio/webm
      audio/ogg
      audio/flac
    ]
  end
end
