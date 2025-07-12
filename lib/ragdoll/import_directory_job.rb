# This file defines the ImportDirectoryJob class for handling directory import tasks in the background.

# frozen_string_literal: true

module Ragdoll
  class ImportDirectoryJob < ::ActiveJob::Base
    def perform(directory, recursive: false)
      job_manager = Ragdoll::ImportJobManager.new(batch_size: 10)

      Dir.glob("#{directory}/*").each do |entry|
        if File.directory?(entry) && recursive
          job_manager.enqueue(Ragdoll::ImportDirectoryJob, entry, recursive: true)
        elsif File.file?(entry)
          job_manager.enqueue(Ragdoll::ImportFileJob, entry)
        end
      end

      job_manager.process_jobs
      puts "Processed import jobs for all files in #{directory}."
    end
  end
end
