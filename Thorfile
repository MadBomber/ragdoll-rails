# Thorfile for Ragdoll engine
# This file provides basic Thor tasks for Rails applications using the Ragdoll engine

require 'thor'
require 'json'

# Add lib directory to load path
lib_path = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

# Only require ragdoll if in Rails context, otherwise provide graceful fallback
begin
  require 'ragdoll'
rescue LoadError
  puts "Warning: Ragdoll library not available. Some commands may not work."
end

# Load all Thor task files
thor_tasks_dir = File.expand_path('lib/tasks/ragdoll', __dir__)
Dir.glob("#{thor_tasks_dir}/*.thor").each { |file| load file }

class RagdollCLI < Thor
  desc 'import PATH', 'Add documents (file or directory) to Ragdoll'
  method_option :recursive, aliases: '-r', type: :boolean, default: false, desc: 'Recurse into directories'
  def import(path)
    return unless check_ragdoll_available
    
    client = Ragdoll::Client.new
    result = if File.directory?(path)
      client.add_directory(path, recursive: options[:recursive])
    else
      client.add_file(path)
    end
    puts JSON.pretty_generate(result)
  end

  desc 'search QUERY', 'Perform semantic search for QUERY'
  method_option :limit, aliases: '-l', type: :numeric, default: 10, desc: 'Max number of results'
  method_option :threshold, aliases: '-t', type: :numeric, default: nil, desc: 'Similarity threshold'
  def search(query)
    return unless check_ragdoll_available
    
    client = Ragdoll::Client.new
    opts = { limit: options[:limit] }
    opts[:threshold] = options[:threshold] if options[:threshold]
    result = client.search(query, **opts)
    puts JSON.pretty_generate(result)
  end

  desc 'generate NAME', 'Generate a simple template'
  def generate(name)
    return unless check_ragdoll_available
    
    puts Ragdoll::Generator.create_template(name)
  end

  # Register subcommands from Thor task modules if available
  begin
    register(Ragdoll::Document, 'document', 'document COMMAND', 'Document management commands') if defined?(Ragdoll::Document)
    register(Ragdoll::Import, 'import_tasks', 'import_tasks COMMAND', 'Import task commands') if defined?(Ragdoll::Import)
    register(Ragdoll::SearchCLI, 'search_tasks', 'search_tasks COMMAND', 'Search task commands') if defined?(Ragdoll::SearchCLI)
    register(Ragdoll::Jobs, 'jobs', 'jobs COMMAND', 'Job management commands') if defined?(Ragdoll::Jobs)
    register(Ragdoll::Ragdoll, 'ragdoll_tasks', 'ragdoll_tasks COMMAND', 'Core ragdoll task commands') if defined?(Ragdoll::Ragdoll)
  rescue NameError => e
    puts "Note: Some subcommands may not be available: #{e.message}"
  end

  private

  def check_ragdoll_available
    unless defined?(Ragdoll)
      puts "Error: Ragdoll is not available. Make sure you're in a Rails application with Ragdoll installed."
      return false
    end
    true
  end
end

# Only start CLI if this file is being run directly
RagdollCLI.start(ARGV) if __FILE__ == $0
