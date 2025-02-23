# frozen_string_literal: true

require 'thor'
require_relative '../../ragdoll/import_job'

module Ragdoll
  class Import < Thor
    desc "import PATH", "Import documents from a file, glob, or directory"
    method_option :recursive, aliases: "-r", type: :boolean, default: false, desc: "Recursively import files from directories"
    method_option :jobs, aliases: ["-j", "--jobs"], type: :numeric, default: 1, desc: "Number of concurrent import jobs"
    def import(path)
      queue = SolidQueue.new(concurrency: options[:jobs])
      files = if File.directory?(path)
                if options[:recursive]
                  Dir.glob("#{path}/**/*")
                else
                  Dir.glob("#{path}/*")
                end
              else
                [path]
              end

      files.each do |file|
        next unless File.file?(file)

        queue.push(file) do |file|
          Ragdoll::ImportJob.perform_async(file)
        end
      end
    end
  end
end
