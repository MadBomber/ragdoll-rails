
# lib/tasks/ragdoll.thor

require 'ragdoll/generator'

module Ragdoll
  class Ragdoll < Thor
    desc "generate NAME", "Generates a cat template"
    def generate(name)
      # Use top-level Ragdoll::Generator
      say ::Ragdoll::Generator.create_template(name)
    end
  end
end
