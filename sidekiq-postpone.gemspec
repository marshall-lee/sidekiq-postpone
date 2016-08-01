# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sidekiq/postpone/version'

Gem::Specification.new do |spec|
  spec.name          = "sidekiq-postpone"
  spec.version       = Sidekiq::Postpone::VERSION
  spec.authors       = ["Vladimir Kochnev"]
  spec.email         = ["hashtable@yandex.ru"]

  spec.summary       = %q{Bulk-pushes jobs to Sidekiq when you need it to.}
  spec.homepage      = "https://github.com/marshall-lee/sidekiq-postpone"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "sidekiq", ">= 3"

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "appraisal", "~> 2.1.0"
  spec.add_development_dependency "redis-namespace", "~> 1.5.2"
end
