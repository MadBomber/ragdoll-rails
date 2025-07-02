# frozen_string_literal: true

require "ragdoll/version"
require "ragdoll/configuration"
require "ragdoll/engine"
require "ragdoll/document_parser"
require "ragdoll/text_chunker"
require "ragdoll/embedding_service"
require "ragdoll/document_type_detector"
require "ragdoll/api"
require "ragdoll/client"

module Ragdoll
  class Error < StandardError; end
  class EmbeddingError < Error; end
  class SearchError < Error; end
  class DocumentError < Error; end
end
