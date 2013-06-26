# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'elastic/rebound/version'

Gem::Specification.new do |spec|
  spec.name          = "elastic-rebound"
  spec.version       = Elastic::Rebound::VERSION
  spec.authors       = ["Cid Dennis"]
  spec.email         = ["cid.dennis@gmail.com"]
  spec.platform    = Gem::Platform::RUBY
  spec.description   = "Elastic Search Interface Gem"
  spec.summary       = "Elastic Search Interface Gem"
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.rubyforge_project = "elastic-rebound"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "activerecord", ">= 3.0"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "mocha",        "~> 0.13"
  spec.add_development_dependency "shoulda"

  #
  spec.add_dependency "rubberband"
  spec.add_dependency 'resque'

  unless defined?(JRUBY_VERSION)
    spec.add_development_dependency "sqlite3"
  end
end
