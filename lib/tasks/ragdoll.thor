
# lib/tasks/ragdoll.thor

require_relative '../ragdoll/generator'

class Ragdoll < Thor
  desc "generate NAME", "Generates a cat template"
  def generate(name)
    say Ragdoll::Generator.create_template(name)
  end
end
