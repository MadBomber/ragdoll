# frozen_string_literal: true

require "debug_me"
include DebugMe
$DEBUG_ME = true

require "delegate"
require_relative "ragdoll/core"

module Ragdoll
  class << self

    #################
    # Configuration #
    #################

    # Retrieve the current configuration.
    # @example
    #   config = Ragdoll.config
    #   puts config.database_config[:adapter]
    # @example
    #   current_config = Ragdoll.configuration
    #   puts current_config.models[:default]
    # @return [Ragdoll::Core::Configuration] the current configuration instance.
    def config
      Core.config
    end

    # Configure the Ragdoll module.
    # @yieldparam config [Ragdoll::Core::Configuration] the configuration instance to modify.
    # @example
    #   Ragdoll.configure do |config|
    #     config.database_config[:adapter] = "postgres"
    #   end
    # @yield [Ragdoll::Core::Configuration] yields the configuration instance for modification.
    def configure(*args, **kwargs, &block)
      Ragdoll::Core.configure(*args, **kwargs, &block)
    end

    # Access the current configuration.
    # @param args [Array] additional arguments for configuration.
    # @param kwargs [Hash] keyword arguments for configuration.
    # @return [Ragdoll::Core::Configuration] the current configuration instance.
    def configuration(*args, **kwargs)
      Ragdoll::Core.configuration(*args, **kwargs)
    end

    # @example
    #   Ragdoll.reset_configuration!
    #   puts Ragdoll.config.models[:default]
    def reset_configuration!(*args, **kwargs)
      Ragdoll::Core.reset_configuration!(*args, **kwargs)
    end


    #######################
    # Document Management #
    #######################

    # Add a directory of documents to the system.
    # @param path [String] the path to the directory containing documents.
    # @example
    #   Ragdoll.add_directory(path: "/path/to/documents", recursive: true)
    # @param recursive [Boolean] whether to add documents from subdirectories.
    def add_directory(*args, **kwargs)
      Ragdoll::Core.add_directory(*args, **kwargs)
    end

    # Add a single document to the system.
    # @example
    #   Ragdoll.add_document(path: "/path/to/document.txt")
    # @param path [String] the file path of the document to add.
    def add_document(*args, **kwargs)
      Ragdoll::Core.add_document(*args, **kwargs)
    end
    alias_method :add, :add_document

    # Retrieve a document by its identifier.
    # @param id [String] the identifier of the document to retrieve.
    # @example
    #   document = Ragdoll.get_document(id: "123")
    #   puts document[:title] if document
    # @return [Hash, nil] the document data or nil if not found.
    def get_document(*args, **kwargs)
      Ragdoll::Core.get_document(*args, **kwargs)
    end
    alias_method :get, :get_document

    # List all documents in the system.
    # @param options [Hash] options for listing documents, such as limit and offset.
    # @example
    #   documents = Ragdoll.list_documents(limit: 10)
    #   documents.each { |doc| puts doc[:title] }
    # @return [Array<Hash>] an array of document data.
    def list_documents(*args, **kwargs)
      Ragdoll::Core.list_documents(*args, **kwargs)
    end
    alias_method :list, :list_documents

    # Delete a document by its identifier.
    # @param id [String] the identifier of the document to delete.
    # @example
    #   success = Ragdoll.delete_document(id: "123")
    #   puts "Deleted" if success
    # @return [Boolean] true if the document was successfully deleted.
    def delete_document(*args, **kwargs)
      Ragdoll::Core.delete_document(*args, **kwargs)
    end
    alias_method :delete, :delete_document

    # Get the status of a document.
    # @param id [String] the identifier of the document to check status.
    # @example
    #   status = Ragdoll.document_status(id: "123")
    #   puts status[:status]
    # @return [Hash] the status information of the document.
    def document_status(*args, **kwargs)
      Ragdoll::Core.document_status(*args, **kwargs)
    end
    alias_method :status, :document_status

    # Update a document's information.
    # @param id [String] the identifier of the document to update.
    # @param updates [Hash] the fields to update in the document.
    # @example
    #   updated_doc = Ragdoll.update_document(id: "123", title: "New Title")
    #   puts updated_doc[:title]
    # @return [Hash] the updated document data.
    def update_document(*args, **kwargs)
      Ragdoll::Core.update_document(*args, **kwargs)
    end
    alias_method :update, :update_document

    # Retrieve all documents.
    # @example
    #   all_docs = Ragdoll.documents
    #   all_docs.each { |doc| puts doc.title }
    # @return [ActiveRecord::Relation] a relation of all documents.
    def documents
      Ragdoll::Document.all
    end
    alias_method :docs, :documents

    #############
    # Retrieval #
    #############

    # FIXME: This high-level API method should be able to take a query that is
    #        a string or a file.  If its a file, then the downstream Process will
    #        be responsible for reading the file and passing the contents to the
    #        search method based upon whether the content is text, image or audio.

    # Perform a search for documents based on a query.
    # @param query [String] the search query string.
    # @param options [Hash] additional search options, such as filters and limits.
    # @example
    #   response = Ragdoll.search(query: "example search")
    #   response[:results].each { |result| puts result[:document_title] }
    # @return [Hash] the search results.
    def search(*args, **kwargs)
      Ragdoll::Core.search(*args, **kwargs)
    end

    # Enhance a prompt with additional context.
    # @param prompt [String] the original prompt to enhance.
    # @param context_limit [Integer] the number of context chunks to include.
    # @param options [Hash] additional options for enhancing the prompt.
    # @example
    #   enhanced = Ragdoll.enhance_prompt(prompt: "What is AI?", context_limit: 3)
    #   puts enhanced[:enhanced_prompt]
    # @return [Hash] the enhanced prompt data.
    def enhance_prompt(*args, **kwargs)
      Ragdoll::Core.enhance_prompt(*args, **kwargs)
    end

    # Retrieve context for a given query.
    # @param query [String] the query to retrieve context for.
    # @param limit [Integer] the number of context chunks to retrieve.
    # @param options [Hash] additional options for context retrieval.
    # @example
    #   context = Ragdoll.get_context(query: "AI", limit: 5)
    #   puts context[:combined_context]
    # @return [Hash] the context data.
    def get_context(*args, **kwargs)
      Ragdoll::Core.get_context(*args, **kwargs)
    end

    # Search for content similar to a given query.
    # @param query [String] the query to find similar content for.
    # @param options [Hash] additional options for the search, such as filters and limits.
    # @example
    #   similar_content = Ragdoll.search_similar_content(query: "AI")
    #   similar_content.each { |content| puts content[:document_title] }
    # @return [Array<Hash>] an array of similar content data.
    def search_similar_content(*args, **kwargs)
      Ragdoll::Core.search_similar_content(*args, **kwargs)
    end

    # Perform hybrid search combining semantic and full-text search.
    # @param query [String] the search query string.
    # @param semantic_weight [Float] weight for semantic search results (0.0 - 1.0).
    # @param text_weight [Float] weight for full-text search results (0.0 - 1.0).
    # @param options [Hash] additional search options, such as filters and limits.
    # @example
    #   results = Ragdoll.hybrid_search(
    #     query: "machine learning",
    #     semantic_weight: 0.7,
    #     text_weight: 0.3
    #   )
    #   results.each { |result| puts result[:document_title] }
    # @return [Array<Hash>] an array of search results combining semantic and text search.
    def hybrid_search(*args, **kwargs)
      Ragdoll::Core.hybrid_search(*args, **kwargs)
    end


    ###############
    # Misc. Stuff #
    ###############

    # Retrieve statistics about the system.
    # @example
    #   stats = Ragdoll.stats
    #   puts stats[:total_documents]
    # @return [Hash] the system statistics.
    def stats(*args, **kwargs)
      Ragdoll::Core.stats(*args, **kwargs)
    end

    # Check if the system is healthy.
    # @example
    #   puts "System is healthy" if Ragdoll.healthy?
    # @return [Boolean] true if the system is healthy.
    def healthy?(*args, **kwargs)
      Ragdoll::Core.healthy?(*args, **kwargs)
    end

    # Retrieve the client instance.
    # @example
    #   client = Ragdoll.client
    #   puts client.inspect
    # @return [Ragdoll::Core::Client] the client instance.
    def client(*args, **kwargs)
      Ragdoll::Core.client(*args, **kwargs)
    end

    # Retrieve the version information of the Ragdoll modules.
    # @example
    #   versions = Ragdoll.version
    #   versions.each { |version| puts version }
    # @return [Array<String>] an array of version strings for each module.
    def version
      versions = []

      ObjectSpace.each_object(Module) do |mod|
        if mod.name =~ /^Ragdoll::\w+$/
          if defined?(mod::VERSION) && mod::VERSION.is_a?(String)
            versions << "#{mod.name}: #{mod::VERSION}"
          end
        end
      end

      versions
    end
  end
end
