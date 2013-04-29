require "bundler/gem_tasks"

begin
  require 'rspec/core'
  require 'rspec/core/rake_task'

  task :default => [:spec]
  task :test => [:spec]

  desc "Run all RSpec tests"
  RSpec::Core::RakeTask.new(:spec)


rescue LoadError
  # silent failure for when rspec is not installed (production mode)
end
