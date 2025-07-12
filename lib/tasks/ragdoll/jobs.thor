# frozen_string_literal: true

require 'thor'

module Ragdoll
  class Jobs < Thor
    desc "[JOB_ID]", "Report the status of all running and queued import jobs, or a specific job if JOB_ID is provided"
    method_option :stop_all, type: :boolean, default: false, desc: "Stop all running and queued jobs"
    method_option :pause_all, type: :boolean, default: false, desc: "Pause all running jobs"
    method_option :resume_all, type: :boolean, default: false, desc: "Resume all paused jobs"
    method_option :stop, type: :boolean, default: false, desc: "Stop a specific job"
    method_option :pause, type: :boolean, default: false, desc: "Pause a specific job"
    method_option :resume, type: :boolean, default: false, desc: "Resume a specific job"
    def status(job_id = nil)
      begin
        # Try to load ragdoll library
        require 'ragdoll'
        
        # Check if we're in a Rails environment with job support
        if defined?(Rails) && Rails.application
          # Rails environment - try to use ImportJobManager
          begin
            job_manager = Ragdoll::ImportJobManager.new
            
            if job_id
              if options[:stop]
                job_manager.stop_job(job_id)
                say "Stopped job ID: #{job_id}.", :green
              elsif options[:pause]
                job_manager.pause_job(job_id)
                say "Paused job ID: #{job_id}.", :green
              elsif options[:resume]
                job_manager.resume_job(job_id)
                say "Resumed job ID: #{job_id}.", :green
              else
                say "Fetching status for job ID: #{job_id}...", :blue
                # Show job status implementation would go here
              end
            else
              if options[:stop_all]
                job_manager.running_jobs.each { |job| job_manager.stop_job(job.job_id) }
                say "Stopped all jobs.", :green
              elsif options[:pause_all]
                job_manager.running_jobs.each { |job| job_manager.pause_job(job.job_id) }
                say "Paused all running jobs.", :green
              elsif options[:resume_all]
                job_manager.running_jobs.each { |job| job_manager.resume_job(job.job_id) }
                say "Resumed all paused jobs.", :green
              else
                say "Fetching status of all running and queued import jobs...", :blue
                running_count = job_manager.running_jobs.count
                waiting_count = job_manager.waiting_jobs
                puts "Running Jobs: #{running_count}"
                puts "Waiting Jobs: #{waiting_count}"
              end
            end
          rescue NameError => e
            say "Job management not available: #{e.message}", :yellow
            exit 1
          end
        else
          # Standalone mode - jobs not supported
          say "Job management is only available in Rails applications.", :yellow
          say "In standalone mode, imports are processed immediately.", :blue
          say "Use 'ragdoll import' to process files directly.", :blue
        end
        
      rescue LoadError => e
        say "Error: Could not load Ragdoll library. #{e.message}", :red
        say "Make sure you're running from a Rails application or have the ragdoll gem installed.", :yellow
        exit 1
      rescue => e
        say "Error: #{e.message}", :red
        exit 1
      end
    end
    
    default_task :status
  end
end
