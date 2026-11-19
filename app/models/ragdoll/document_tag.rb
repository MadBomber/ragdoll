# frozen_string_literal: true

require "active_record"

module Ragdoll
  # DocumentTag - Join table linking documents to tags
  #
  # Tracks which tags are associated with documents, including:
  # - confidence: How confident the extraction was (0.0-1.0)
  # - source: Whether tag was auto-extracted or manually added
  #
  class DocumentTag < ActiveRecord::Base
    self.table_name = "ragdoll_document_tags"

    # Associations
    belongs_to :document, class_name: "Ragdoll::Document"
    belongs_to :tag, class_name: "Ragdoll::Tag"

    # Validations
    validates :document_id, presence: true
    validates :tag_id, presence: true
    validates :document_id, uniqueness: { scope: :tag_id }
    validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
    validates :source, inclusion: { in: %w[auto manual] }

    # Scopes
    scope :auto_extracted, -> { where(source: 'auto') }
    scope :manual, -> { where(source: 'manual') }
    scope :high_confidence, -> { where("confidence >= ?", 0.8) }
    scope :by_confidence, -> { order(confidence: :desc) }

    # Callbacks
    after_create :increment_tag_usage

    private

    def increment_tag_usage
      tag.increment_usage!
    end
  end
end
