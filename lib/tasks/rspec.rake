# frozen_string_literal: true

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:rspec) do |task|
    task.pattern = 'spec/**/*_spec.rb'
    task.rspec_opts = '--format documentation'
  end

  desc 'Run RSpec tests'
  task :spec => :rspec
rescue LoadError
  # RSpec not available, skip task definition
  desc 'Run RSpec tests (RSpec not available)'
  task :spec do
    puts "RSpec not available. Please add rspec to your Gemfile."
  end
end