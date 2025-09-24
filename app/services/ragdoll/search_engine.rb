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
      if query_embedding.nil?
        puts "Warning: Could not generate embedding for query, falling back to text search" if ENV["RAGDOLL_DEBUG"]
        # Fallback to direct text search when embeddings fail
        text_results = Ragdoll::Document.where("summary ILIKE ? OR title ILIKE ?", "%#{query}%", "%#{query}%")
                                       .limit(limit)
                                       .map do |doc|
          {
            id: doc.id,
            content: doc.summary,
            title: doc.title,
            document_location: doc.location,
            similarity: 1.0,  # Max similarity for exact text match
            chunk_index: 0
          }
        end
        return text_results
      end

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

        # If embedding generation fails, fall back to text search
        if query_embedding.nil?
          puts "Warning: Could not generate embedding for query '#{query_string}', falling back to text search" if ENV["RAGDOLL_DEBUG"]

          # Fallback to direct text search when embeddings fail
          text_results = Ragdoll::Document.where("summary ILIKE ? OR title ILIKE ?", "%#{query_string}%", "%#{query_string}%")
                                         .limit(limit)
                                         .map do |doc|
            {
              id: doc.id,
              content: doc.summary,
              title: doc.title,
              document_location: doc.location,
              similarity: 1.0,  # Max similarity for exact text match
              chunk_index: 0
            }
          end

          execution_time = ((Time.current - start_time) * 1000).round

          # Record search if tracking enabled
          if track_search && query_string && !query_string.empty?
            begin
              # Format results for search recording
              search_results = text_results.map do |result|
                {
                  embedding_id: result[:id],
                  similarity: result[:similarity]
                }
              end

              search_type = "text_fallback"

              Ragdoll::Search.record_search(
                query: query_string,
                query_embedding: nil,
                results: search_results,
                search_type: search_type,
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

          return {
            results: text_results,
            statistics: nil,
            execution_time_ms: execution_time
          }
        end
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

      # If no semantic results found and we have a query string, try text search as additional fallback
      if results.empty? && query_string && !query_string.empty?
        puts "Warning: Semantic search returned no results for '#{query_string}', falling back to text search" if ENV["RAGDOLL_DEBUG"]

        text_results = Ragdoll::Document.where("summary ILIKE ? OR title ILIKE ?", "%#{query_string}%", "%#{query_string}%")
                                       .limit(limit)
                                       .map do |doc|
          {
            id: doc.id,
            content: doc.summary,
            title: doc.title,
            document_location: doc.location,
            similarity: 1.0,  # Max similarity for exact text match
            chunk_index: 0
          }
        end

        if text_results.any?
          puts "Text search found #{text_results.count} results" if ENV["RAGDOLL_DEBUG"]
          results = text_results
          statistics = { search_type: "text_fallback", total_matches: text_results.count }
        end
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