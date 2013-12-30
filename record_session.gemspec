# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'record_session/version'

Gem::Specification.new do |spec|
  spec.name          = "record_session"
  spec.version       = RecordSession::VERSION
  spec.authors       = ["Dave Thomas (@pragdave)"]
  spec.email         = ["dave@pragprog.com"]
  spec.description   = File.read "README.md"
  spec.summary       = "Record a terminal session (with timestamps) to a JSON structure"
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'ruby-termios'
  spec.add_development_dependency "rake"
end
