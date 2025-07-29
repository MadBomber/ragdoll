# frozen_string_literal: true

# FIXME: This is crap.  It does not focus on search.

module Ragdoll
  module Core
    class SearchEngine
      def initialize(embedding_service, config_service: nil)
        @embedding_service = embedding_service
        @config_service = config_service || ConfigurationService.new
      end

      def search_documents(query, options = {})
        search_config = @config_service.search_config
        limit = options[:limit] || search_config[:max_results]
        threshold = options[:threshold] || search_config[:similarity_threshold]
        filters = options[:filters] || {}

        # Generate embedding for the query
        query_embedding = @embedding_service.generate_embedding(query)
        return [] if query_embedding.nil?

        # Search using ActiveRecord models
        Models::Embedding.search_similar(query_embedding,
                                         limit: limit,
                                         threshold: threshold,
                                         filters: filters)
      end

      def search_similar_content(query_or_embedding, options = {})
        search_config = @config_service.search_config
        limit = options[:limit] || search_config[:max_results]
        threshold = options[:threshold] || search_config[:similarity_threshold]
        filters = options[:filters] || {}

        if query_or_embedding.is_a?(Array)
          # It's already an embedding
          query_embedding = query_or_embedding
        else
          # It's a query string, generate embedding
          query_embedding = @embedding_service.generate_embedding(query_or_embedding)
          return [] if query_embedding.nil?
        end

        # Search using ActiveRecord models
        Models::Embedding.search_similar(query_embedding,
                                         limit: limit,
                                         threshold: threshold,
                                         filters: filters)
      end
    end
  end
end
