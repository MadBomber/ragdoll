#!/usr/bin/env ruby
# frozen_string_literal: true

# Example demonstrating Shrine integration with ragdoll-core
# This example shows how to work with file uploads and attachments using Shrine

require "bundler/setup"
require_relative "../lib/ragdoll"
require "tempfile"

# Configure ragdoll-core
Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: "postgresql",
    database: "ragdoll_example",
    username: "ragdoll",
    password: ENV["DATABASE_PASSWORD"],
    host: "localhost",
    port: 5432,
    auto_migrate: true
  }
end

# Initialize the database
Ragdoll::Core::Database.setup

puts "=== Shrine File Upload Integration Example ==="

# Example 1: Create document with file upload
puts "\n1. Creating document with file upload..."

# Create a temporary file to simulate file upload
temp_file = Tempfile.new(["example", ".txt"])
temp_file.write("This is example content for a text file.\nIt demonstrates how Shrine handles file uploads in ragdoll-core.\nThe content will be extracted and processed for embeddings.")
temp_file.rewind

begin
  # Create document with file attachment using Shrine
  document = Ragdoll::Core::Models::Document.create!(
    location: "example_uploaded.txt",
    title: "Example Uploaded Document",
    document_type: "text",
    status: "pending"
  )

  # Attach file using Shrine
  document.file = temp_file
  document.save!

  puts "Document ID: #{document.id}"
  puts "Has file attached: #{document.file_attached?}"
  puts "File attached successfully!"
rescue StandardError => e
  puts "Error creating document with file: #{e.message}"
ensure
  temp_file.close
  temp_file.unlink
end

# Example 2: Working with Shrine file attachments
puts "\n2. Working with Shrine file attachments..."
if document&.file_attached?
  puts "File size: #{document.file_size} bytes"
  puts "File content type: #{document.file_content_type}"
  puts "File filename: #{document.file_filename}"
  puts "Shrine file ID: #{document.file.id}"
  puts "Shrine storage: #{document.file.storage_key}"
else
  puts "No file attached to document"
end

# Example 3: Document processing with Shrine files
puts "\n3. Document processing with Shrine files..."
if document&.file_attached?
  begin
    # Process the document content (this would extract text from the attached file)
    document.process_content!

    puts "Document processing status: #{document.status}"
    puts "Extracted content length: #{document.content&.length || 0} characters"
    puts "Content preview: #{document.content&.first(100)}..." if document.content
  rescue StandardError => e
    puts "Error processing document: #{e.message}"
  end
end

# Example 4: Creating a PDF document simulation
puts "\n4. Creating PDF document with Shrine..."

# Simulate PDF file upload
pdf_tempfile = Tempfile.new(["sample", ".pdf"])
pdf_tempfile.write("%PDF-1.4\nSimulated PDF content for demonstration")
pdf_tempfile.rewind

begin
  pdf_document = Ragdoll::Core::Models::Document.create!(
    location: "sample.pdf",
    title: "Sample PDF Document",
    document_type: "pdf",
    status: "pending"
  )

  # Attach PDF file
  pdf_document.file = pdf_tempfile
  pdf_document.save!

  puts "PDF Document ID: #{pdf_document.id}"
  puts "PDF file attached: #{pdf_document.file_attached?}"
  puts "PDF file size: #{pdf_document.file_size} bytes"
  puts "PDF MIME type: #{pdf_document.file_content_type}"
rescue StandardError => e
  puts "Error with PDF document: #{e.message}"
ensure
  pdf_tempfile.close
  pdf_tempfile.unlink
end

# Example 5: File upload validation and metadata
puts "\n5. File upload validation and metadata..."
if document&.file_attached?
  # Shrine provides rich metadata about uploaded files
  file_metadata = document.file.metadata

  puts "File metadata:"
  file_metadata.each do |key, value|
    puts "  #{key}: #{value}"
  end

  # Check file validation
  puts "\nFile validation:"
  puts "Valid file type: #{%w[text/plain application/pdf].include?(document.file_content_type)}"
  puts "Reasonable file size: #{document.file_size < 10.megabytes}"
end

# Example 6: Multiple file types and content extraction
puts "\n6. Document types and content extraction..."

document_types = [
  { type: "text", extension: ".txt", content: "Plain text content" },
  { type: "html", extension: ".html", content: "<html><body><h1>HTML Content</h1></body></html>" },
  { type: "markdown", extension: ".md", content: '# Markdown Content\n\nThis is **markdown** text.' }
]

document_types.each do |doc_type|
  temp = Tempfile.new(["test", doc_type[:extension]])
  temp.write(doc_type[:content])
  temp.rewind

  begin
    doc = Ragdoll::Core::Models::Document.create!(
      location: "test#{doc_type[:extension]}",
      title: "Test #{doc_type[:type].upcase} Document",
      document_type: doc_type[:type],
      status: "pending"
    )

    doc.file = temp
    doc.save!

    puts "Created #{doc_type[:type]} document (ID: #{doc.id}) with Shrine attachment"
  rescue StandardError => e
    puts "Error with #{doc_type[:type]} document: #{e.message}"
  ensure
    temp.close
    temp.unlink
  end
end

# Example 7: File removal and cleanup
puts "\n7. File removal and cleanup..."
if document&.file_attached?
  begin
    # Remove file attachment
    document.file = nil
    document.save!

    puts "File attachment removed successfully"
    puts "File still attached: #{document.file_attached?}"
  rescue StandardError => e
    puts "Error removing file: #{e.message}"
  end
end

# Example 8: Shrine storage configuration
puts "\n8. Shrine storage configuration..."
puts "Default Shrine storage: #{Shrine.storages.keys}"
puts "File storage backend: filesystem (configurable for S3, GCS, etc.)"
puts "Upload directory: tmp/uploads/"

# Example 9: Document statistics with file info
puts "\n9. Document statistics with file information..."
all_documents = Ragdoll::Core::Models::Document.all

puts "Total documents created: #{all_documents.count}"
puts "Documents with files: #{all_documents.count(&:file_attached?)}"
puts "Documents without files: #{all_documents.count { |d| !d.file_attached? }}"

file_sizes = all_documents.filter_map { |d| d.file_size if d.file_attached? }
if file_sizes.any?
  puts "Total file storage used: #{file_sizes.sum} bytes"
  puts "Average file size: #{file_sizes.sum / file_sizes.length} bytes"
end

puts "\n=== Shrine Integration Complete ==="
puts "Shrine provides robust file upload handling with:"
puts "- Multiple storage backends (filesystem, S3, GCS, etc.)"
puts "- File validation and processing"
puts "- Rich metadata extraction"
puts "- Secure file handling and cleanup"
puts "- Integration with ragdoll-core document processing pipeline"
