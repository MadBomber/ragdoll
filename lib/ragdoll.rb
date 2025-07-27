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

    def config
      Core.config
    end

    def configure(*args, **kwargs, &block)
      Ragdoll::Core.configure(*args, **kwargs, &block)
    end

    def configuration(*args, **kwargs)
      Ragdoll::Core.configuration(*args, **kwargs)
    end

    def reset_configuration!(*args, **kwargs)
      Ragdoll::Core.reset_configuration!(*args, **kwargs)
    end


    #######################
    # Document Management #
    #######################

    def add_directory(*args, **kwargs)
      Ragdoll::Core.add_directory(*args, **kwargs)
    end

    def add_document(*args, **kwargs)
      Ragdoll::Core.add_document(*args, **kwargs)
    end
    alias_method :add, :add_document

    def get_document(*args, **kwargs)
      Ragdoll::Core.get_document(*args, **kwargs)
    end
    alias_method :get, :get_document

    def list_documents(*args, **kwargs)
      Ragdoll::Core.list_documents(*args, **kwargs)
    end
    alias_method :list, :list_documents

    def delete_document(*args, **kwargs)
      Ragdoll::Core.delete_document(*args, **kwargs)
    end
    alias_method :delete, :delete_document

    def document_status(*args, **kwargs)
      Ragdoll::Core.document_status(*args, **kwargs)
    end
    alias_method :status, :document_status

    def update_document(*args, **kwargs)
      Ragdoll::Core.update_document(*args, **kwargs)
    end
    alias_method :update, :update_document

    def documents
      Ragdoll::Core::Models::Document.all
    end
    alias_method :docs, :documents

    #############
    # Retrieval #
    #############

    # FIXME: This high-level API method should be able to take a query that is
    #        a string or a file.  If its a file, then the downstream Process will
    #        be responsible for reading the file and passing the contents to the
    #        search method based upon whether the content is text, image or audio.

    def search(*args, **kwargs)
      Ragdoll::Core.search(*args, **kwargs)
    end

    def enhance_prompt(*args, **kwargs)
      Ragdoll::Core.enhance_prompt(*args, **kwargs)
    end

    def get_context(*args, **kwargs)
      Ragdoll::Core.get_context(*args, **kwargs)
    end

    def search_similar_content(*args, **kwargs)
      Ragdoll::Core.search_similar_content(*args, **kwargs)
    end


    ###############
    # Misc. Stuff #
    ###############

    def stats(*args, **kwargs)
      Ragdoll::Core.stats(*args, **kwargs)
    end

    def healthy?(*args, **kwargs)
      Ragdoll::Core.healthy?(*args, **kwargs)
    end

    def client(*args, **kwargs)
      Ragdoll::Core.client(*args, **kwargs)
    end

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
