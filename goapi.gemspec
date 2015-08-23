# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'goapi/version'

Gem::Specification.new do |spec|
  spec.name          = "goapi"
  spec.version       = Goapi::VERSION
  spec.authors       = ["Xiao Li"]
  spec.email         = ["swing1979@gmail.com"]

  spec.summary       = %q{Go API ruby client.}
  spec.homepage      = "https://github.com/ThoughtWorksStudios/goapi"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "json", "~> 1.8"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
end
