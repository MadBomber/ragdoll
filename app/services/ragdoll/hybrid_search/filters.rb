# frozen_string_literal: true

module Ragdoll
  module HybridSearch
    # Filter and timeframe helpers for hybrid search
    #
    # Provides methods to apply document type, keyword, and timeframe
    # filters to ActiveRecord scopes and raw SQL queries.
    #
    module Filters
      # Apply filters to an ActiveRecord scope
      #
      # @param scope [ActiveRecord::Relation] Base scope
      # @param filters [Hash] Filters (:document_type, :keywords)
      # @return [ActiveRecord::Relation] Filtered scope
      #
      def apply_filters(scope, filters)
        return scope if filters.blank?

        if filters[:document_type]
          scope = scope
            .joins("JOIN ragdoll_contents ON ragdoll_contents.id = ragdoll_embeddings.embeddable_id")
            .joins("JOIN ragdoll_documents ON ragdoll_documents.id = ragdoll_contents.document_id")
            .where("ragdoll_documents.document_type = ?", filters[:document_type])
        end

        if filters[:keywords]&.any?
          scope = scope
            .joins("JOIN ragdoll_contents ON ragdoll_contents.id = ragdoll_embeddings.embeddable_id")
            .joins("JOIN ragdoll_documents ON ragdoll_documents.id = ragdoll_contents.document_id")
            .where("ragdoll_documents.keywords && ARRAY[?]::varchar[]", filters[:keywords])
        end

        scope
      end

      # Apply timeframe filter to an ActiveRecord scope
      #
      # @param scope [ActiveRecord::Relation] Base scope
      # @param timeframe [Range, nil] Time range filter
      # @return [ActiveRecord::Relation] Filtered scope
      #
      def apply_timeframe(scope, timeframe)
        return scope unless timeframe.is_a?(Range)

        scope.where(created_at: timeframe)
      end

      # Build SQL condition string for timeframe
      #
      # @param timeframe [Range, nil] Time range filter
      # @return [String, nil] SQL condition or nil
      #
      def timeframe_sql(timeframe)
        return nil unless timeframe.is_a?(Range)

        "ragdoll_embeddings.created_at BETWEEN '#{timeframe.begin.to_fs(:db)}' AND '#{timeframe.end.to_fs(:db)}'"
      end

      # Build filter conditions for raw SQL queries
      #
      # @param filters [Hash] Filters to convert
      # @return [Array<String>] SQL condition strings
      #
      def filter_conditions(filters)
        conditions = []
        # Add additional filter conditions as needed
        conditions
      end

      # Normalize timeframe, extracting from query if :auto
      #
      # @param timeframe [Range, Symbol, nil] Timeframe or :auto
      # @param query [String] Search query (for :auto extraction)
      # @return [Hash] Normalized query and timeframe
      #
      def normalize_timeframe(timeframe, query)
        if timeframe == :auto
          result = Ragdoll::Timeframe.normalize(:auto, query: query)
          { query: result.query, timeframe: result.timeframe }
        elsif timeframe
          { query: query, timeframe: Ragdoll::Timeframe.normalize(timeframe) }
        else
          { query: query, timeframe: nil }
        end
      end
    end
  end
end
