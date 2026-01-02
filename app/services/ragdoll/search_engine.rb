# frozen_string_literal: true

module Ragdoll
  # Semantic search engine using vector similarity
  #
  # Performs vector similarity search on embeddings to find semantically
  # similar content. Supports filtering, threshold-based results, and
  # search analytics tracking.
  #
  # @example Basic search
  #   engine = Ragdoll::SearchEngine.new(embedding_service)
  #   results = engine.search_similar_content("machine learning")
  #
  # @example Search with options
  #   results = engine.search_similar_content(
  #     "database optimization",
  #     limit: 20,
  #     threshold: 0.8,
  #     keywords: ["postgresql", "performance"]
  #   )
  #
  class SearchEngine
    # Initialize the search engine
    #
    # @param embedding_service [Ragdoll::EmbeddingService] Service for generating query embeddings
    # @param config_service [Ragdoll::ConfigurationService, nil] Configuration service
    #
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
      
      # Extract keywords option and normalize
      keywords = options[:keywords] || []
      keywords = Array(keywords).map(&:to_s).reject(&:empty?)
      
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

      # Add keywords to filters if provided
      if keywords.any?
        filters[:keywords] = keywords
      end

      # Search using ActiveRecord models with statistics
      # Try enhanced search first, fall back to original if it fails
      begin
        search_response = Ragdoll::Embedding.search_similar_with_stats(query_embedding,
                                                                      limit: limit,
                                                                      threshold: threshold,
                                                                      filters: filters)
        results = search_response[:results]
        statistics = search_response[:statistics]
      rescue NoMethodError, PG::SyntaxError => e
        # Fall back to original search method if enhanced version fails
        puts "Warning: Enhanced search failed (#{e.message}), using fallback" if ENV["RAGDOLL_DEBUG"]
        results = Ragdoll::Embedding.search_similar(query_embedding,
                                                   limit: limit,
                                                   threshold: threshold,
                                                   filters: filters)
        statistics = nil
      end
      
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
          
          search_type = keywords.any? ? "semantic_with_keywords" : "semantic"
          
          Ragdoll::Search.record_search(
            query: query_string,
            query_embedding: query_embedding,
            results: search_results,
            search_type: search_type,
            filters: filters,
            options: { limit: limit, threshold: threshold, keywords: keywords },
            execution_time_ms: execution_time,
            session_id: session_id,
            user_id: user_id
          )
        rescue => e
          # Log error but don't fail the search
          puts "Warning: Search tracking failed: #{e.message}" if ENV["RAGDOLL_DEBUG"]
        end
      end

      # Return results with statistics for better user feedback
      {
        results: results,
        statistics: statistics,
        execution_time_ms: execution_time
      }
    end
  end
end