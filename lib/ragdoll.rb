# This file is the main entry point for the Ragdoll gem, requiring all necessary components.

# frozen_string_literal: true

# frozen_string_literal: true

require "ragdoll/version"
require "ragdoll/engine"
require "ragdoll/import_job"
require "tasks/ragdoll"

module Ragdoll
  class Error < StandardError; end
end
