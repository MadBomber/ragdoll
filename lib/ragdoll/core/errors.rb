# frozen_string_literal: true

module Ragdoll
  module Core
    class Error < StandardError; end
    class EmbeddingError < Error; end
    class SearchError < Error; end
    class DocumentError < Error; end
    class ConfigurationError < Error; end
  end
end
