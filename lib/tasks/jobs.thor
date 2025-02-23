# frozen_string_literal: true

require 'thor'

module Ragdoll
  class JobsTask < Thor
    desc "jobs [JOB_ID]", "Report the status of all running and queued import jobs, or a specific job if JOB_ID is provided"
    method_option :stop_all, type: :boolean, default: false, desc: "Stop all running and queued jobs"
    method_option :pause_all, type: :boolean, default: false, desc: "Pause all running jobs"
    method_option :resume_all, type: :boolean, default: false, desc: "Resume all paused jobs"
    method_option :stop, type: :boolean, default: false, desc: "Stop a specific job"
    method_option :pause, type: :boolean, default: false, desc: "Pause a specific job"
    method_option :resume, type: :boolean, default: false, desc: "Resume a specific job"
    def jobs(job_id = nil)
      if job_id
        if options[:stop]
          puts "Stopping job ID: #{job_id}..."
        elsif options[:pause]
          puts "Pausing job ID: #{job_id}..."
        elsif options[:resume]
          puts "Resuming job ID: #{job_id}..."
        else
          puts "Fetching status for job ID: #{job_id}..."
        end
      else
        if options[:stop_all]
          puts "Stopping all jobs..."
        elsif options[:pause_all]
          puts "Pausing all running jobs..."
        elsif options[:resume_all]
          puts "Resuming all paused jobs..."
        else
          puts "Fetching status of all running and queued import jobs..."
          puts "Job ID: 12345, Status: Running, File: document1.txt"
          puts "Job ID: 12346, Status: Running, File: document2.txt"
        end
      end
    end
  end
end
