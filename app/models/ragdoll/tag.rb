# frozen_string_literal: true

require "active_record"

module Ragdoll
  # Tag - Hierarchical tag for document and embedding classification
  #
  # Tags use a colon-separated hierarchical format:
  #   "database:postgresql:extension"
  #   "ai:llm:embedding"
  #
  # The parent_name stores the immediate parent for tree traversal.
  #
  class Tag < ActiveRecord::Base
    self.table_name = "ragdoll_tags"

    # Associations
    has_many :document_tags, class_name: "Ragdoll::DocumentTag", dependent: :destroy
    has_many :documents, through: :document_tags

    has_many :embedding_tags, class_name: "Ragdoll::EmbeddingTag", dependent: :destroy
    has_many :embeddings, through: :embedding_tags

    # Validations
    validates :name, presence: true, uniqueness: true
    validates :name, format: {
      with: /\A[a-z0-9\-]+(:[a-z0-9\-]+)*\z/,
      message: "must be lowercase alphanumeric with hyphens, separated by colons"
    }

    # Callbacks
    before_validation :normalize_name
    before_save :set_hierarchy_attributes

    # Scopes
    scope :root_tags, -> { where(depth: 0) }
    scope :by_depth, ->(d) { where(depth: d) }
    scope :children_of, ->(parent) { where(parent_name: parent) }
    scope :by_usage, -> { order(usage_count: :desc) }
    scope :starting_with, ->(prefix) { where("name LIKE ?", "#{prefix}%") }

    # Find or create a tag, automatically creating parent tags
    #
    # @param name [String] Full hierarchical tag name (e.g., "ai:llm:embedding")
    # @return [Tag] The found or created tag
    #
    def self.find_or_create_with_hierarchy!(name)
      normalized = name.to_s.strip.downcase

      # Find existing
      existing = find_by(name: normalized)
      return existing if existing

      # Create with parents
      transaction do
        levels = normalized.split(':')
        current_path = []

        levels.each do |level|
          current_path << level
          full_name = current_path.join(':')

          find_or_create_by!(name: full_name)
        end

        find_by!(name: normalized)
      end
    end

    # Parse the hierarchical structure
    #
    # @return [Hash] Hierarchy info
    #
    def hierarchy
      levels = name.split(':')

      {
        full: name,
        root: levels.first,
        parent: parent_name,
        levels: levels,
        depth: levels.size
      }
    end

    # Get all ancestor tags
    #
    # @return [Array<Tag>] Ancestor tags from root to immediate parent
    #
    def ancestors
      return [] if root?

      levels = name.split(':')
      ancestor_names = (1...levels.size).map { |i| levels[0, i].join(':') }

      Tag.where(name: ancestor_names).order(:depth)
    end

    # Get direct children
    #
    # @return [ActiveRecord::Relation<Tag>]
    #
    def children
      Tag.where(parent_name: name)
    end

    # Get all descendants
    #
    # @return [ActiveRecord::Relation<Tag>]
    #
    def descendants
      Tag.where("name LIKE ?", "#{name}:%")
    end

    # Check if this is a root tag (no parent)
    #
    # @return [Boolean]
    #
    def root?
      parent_name.nil?
    end

    # Increment usage count
    #
    # @return [void]
    #
    def increment_usage!
      increment!(:usage_count)
    end

    private

    def normalize_name
      self.name = name.to_s.strip.downcase if name.present?
    end

    def set_hierarchy_attributes
      return unless name.present?

      levels = name.split(':')
      self.depth = levels.size - 1
      self.parent_name = levels.size > 1 ? levels[0..-2].join(':') : nil
    end
  end
end
