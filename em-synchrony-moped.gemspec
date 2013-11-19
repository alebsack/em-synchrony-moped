# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = 'em-synchrony-moped'
  s.version = "1.0.0.beta.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Adam Lebsack"]
  s.email = ["alebsack@gmail.com"]
  
  s.summary = 'Moped driver for EM-Synchrony'
  s.description = 'EM-Synchrony-Moped is a Moped driver patch for ' +
                  'EM-Synchrony, allowing your asynchronous application use' +
                  'non-blocking connections to MongoDB.  Moped is the' +
                  'MongoDB driver for the Mongoid ORM.'
  s.license = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'eventmachine',      '~> 1.0'
  s.add_runtime_dependency 'em-synchrony',      '~> 1.0.3'
  s.add_runtime_dependency 'moped',             '~> 1.5.1'
  s.add_runtime_dependency 'em-resolv-replace'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'guard'
  s.add_development_dependency 'guard-rspec'
  s.add_development_dependency 'guard-bundler'
  s.add_development_dependency 'guard-rubocop'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'spork'
  s.add_development_dependency 'simplecov'
end
