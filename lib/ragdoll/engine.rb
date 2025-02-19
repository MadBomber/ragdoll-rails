# This file defines the Ragdoll engine, which integrates the gem with Rails applications.

# frozen_string_literal: true

require "rails/engine"

module Ragdoll
  class Engine < ::Rails::Engine
    isolate_namespace Ragdoll
    config.generators do |g|
      g.test_framework :minitest
      g.fixture_replacement :factory_bot
      g.factory_bot dir: 'test/factories'
    end
  end
end
