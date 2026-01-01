# frozen_string_literal: true

require "active_record"
require "neighbor"

module Ragdoll
  # Proposition - Atomic factual statement extracted from documents
  #
  # Propositions are simple, self-contained facts extracted from document
  # chunks for more granular retrieval. Each proposition:
  # - Expresses a single fact
  # - Is understandable without context
  # - Uses full names, not pronouns
  # - Has its own embedding vector for similarity search
  #
  # @example
  #   "Neil Armstrong walked on the Moon in 1969."
  #   "PostgreSQL supports JSON data types."
  #
  class Proposition < ActiveRecord::Base
    self.table_name = "ragdoll_propositions"

    # Use pgvector for vector similarity search
    has_neighbors :embedding_vector

    # Associations
    belongs_to :document, class_name: "Ragdoll::Document"
    belongs_to :source_embedding,
               class_name: "Ragdoll::Embedding",
               optional: true

    # Validations
    validates :content, presence: true
    validates :document_id, presence: true

    # Scopes
    scope :with_embeddings, -> { where.not(embedding_vector: nil) }
    scope :without_embeddings, -> { where(embedding_vector: nil) }
    scope :by_document, ->(doc_id) { where(document_id: doc_id) }
    scope :recent, -> { order(created_at: :desc) }

    # Search for similar propositions using vector similarity
    #
    # @param query_embedding [Array<Float>] Query vector
    # @param limit [Integer] Maximum results
    # @param threshold [Float] Minimum similarity score
    # @return [Array<Proposition>] Similar propositions with similarity scores
    #
    def self.search_similar(query_embedding, limit: 20, threshold: 0.7)
      nearest_neighbors(:embedding_vector, query_embedding, distance: "cosine")
        .limit(limit * 2)
        .to_a
        .select { |prop| (1.0 - prop.neighbor_distance) >= threshold }
        .take(limit)
        .each { |prop| prop.define_singleton_method(:similarity) { 1.0 - neighbor_distance } }
    end

    # Get the chunk/embedding this proposition was extracted from
    #
    # @return [String, nil] Source chunk content
    #
    def source_chunk
      source_embedding&.content
    end

    # Check if proposition has an embedding
    #
    # @return [Boolean]
    #
    def embedded?
      embedding_vector.present?
    end
  end
end
