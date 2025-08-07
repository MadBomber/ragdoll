# frozen_string_literal: true

# FIXME: This is crap.  It does not focus on search.

module Ragdoll
  class SearchEngine
    def initialize(embedding_service, config_service: nil)
      @embedding_service = embedding_service
      @config_service = config_service || Ragdoll::ConfigurationService.new
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
      Ragdoll::Embedding.search_similar(query_embedding,
                                       limit: limit,
                                       threshold: threshold,
                                       filters: filters)
    end

    def search_similar_content(query_or_embedding, options = {})
      start_time = Time.current
      search_config = @config_service.search_config
      limit = options[:limit] || search_config[:max_results]
      threshold = options[:threshold] || search_config[:similarity_threshold]
      filters = options[:filters] || {}
      
      # Extract tracking options
      session_id = options[:session_id]
      user_id = options[:user_id]
      track_search = options.fetch(:track_search, true)

      if query_or_embedding.is_a?(Array)
        # It's already an embedding
        query_embedding = query_or_embedding
        query_string = options[:query] # Should be provided when passing embedding directly
      else
        # It's a query string, generate embedding
        query_string = query_or_embedding
        query_embedding = @embedding_service.generate_embedding(query_string)
        return [] if query_embedding.nil?
      end

      # Search using ActiveRecord models
      results = Ragdoll::Embedding.search_similar(query_embedding,
                                                 limit: limit,
                                                 threshold: threshold,
                                                 filters: filters)
      
      execution_time = ((Time.current - start_time) * 1000).round
      
      # Record search if tracking enabled and we have a query string
      if track_search && query_string && !query_string.empty?
        begin
          # Format results for search recording
          search_results = results.map do |result|
            {
              embedding_id: result[:embedding_id] || result[:id],
              similarity: result[:similarity] || result[:similarity_score] || 0.0
            }
          end
          
          Ragdoll::Search.record_search(
            query: query_string,
            query_embedding: query_embedding,
            results: search_results,
            search_type: "semantic",
            filters: filters,
            options: { limit: limit, threshold: threshold },
            execution_time_ms: execution_time,
            session_id: session_id,
            user_id: user_id
          )
        rescue => e
          # Log error but don't fail the search
          puts "Warning: Search tracking failed: #{e.message}" if ENV["RAGDOLL_DEBUG"]
        end
      end

      results
    end
  end
end