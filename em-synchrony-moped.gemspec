# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = 'em-synchrony-moped'
  s.version = "0.9.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Adam Lebsack"]
  s.email = ["alebsack@gmail.com"]
  
  s.summary = %q{Moped driver for EM-Synchrony}
  s.description = %q{EM-Synchrony-Moped is a Moped driver patch for EM-Synchtony, allowing your asynchronous application use non-blocking connections to MongoDB.  Moped is the MongoDB driver for the Mongoid ORM.}
  s.email = %q{alebsack@gmail.com}


  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'eventmachine'
  s.add_runtime_dependency 'em-synchrony',      '~> 1.0'
  s.add_runtime_dependency 'moped',             '~> 1.4.5'
  s.add_runtime_dependency 'em-resolv-replace', '~> 1.1.3'

  s.add_development_dependency 'rspec',         '~> 2.12.0'

end
