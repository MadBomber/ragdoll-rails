
# lib/tasks/ragdoll.thor

require_relative '../../ragdoll/generator'

module Ragdoll
  class Generate < Thor
    desc "generate NAME", "Generates a cat template"
    def generate(name)
      say Ragdoll::Generator.create_template(name)
    end
  end
end
