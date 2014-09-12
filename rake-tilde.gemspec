# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rake/tilde/version'

Gem::Specification.new do |spec|
  spec.name          = "rake-tilde"
  spec.version       = Rake::Tilde::VERSION
  spec.authors       = ["myobie"]
  spec.email         = ["me@nathanherald.com"]
  spec.summary       = %q{Run a rake task when files change}
  spec.description   = %q{Run your existing rake tasks by just appending ~.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"

  spec.add_dependency "rake", "~> 10.0"
  spec.add_dependency "listen", "~> 2.7"
end
