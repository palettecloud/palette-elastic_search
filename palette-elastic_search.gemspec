# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "palette/elastic_search/version"

Gem::Specification.new do |spec|
  spec.name          = "palette-elastic_search"
  spec.version       = Palette::ElasticSearch::VERSION
  spec.authors       = ["nkdn"]
  spec.email         = ["hiroyuki.nikaido@gmail.com"]

  spec.summary       = %q{elastic-model based search library}
  spec.description   = %q{elastic-model based search library}
  spec.homepage      = "https://github.com/palettecloud/palette-elastic_search"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'activesupport'
  spec.add_dependency 'actionview', '~> 5.2.4.2'
  spec.add_dependency 'elasticsearch-rails', '~> 5.0'
  spec.add_dependency 'elasticsearch-model', '~> 5.0'
  spec.add_dependency 'newrelic_rpm'

  spec.add_development_dependency 'bundler', '~> 2.1.4'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'pry-rails'
  spec.add_development_dependency 'activerecord'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'webmock'
end
