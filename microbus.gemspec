# frozen_string_literal: true

require_relative 'lib/microbus/version'

Gem::Specification.new do |s|
  s.name          = 'microbus'
  s.version       = Microbus::VERSION
  s.authors       = ['Glenn Pratt', 'Peter Drake']
  s.email         = ['glenn.pratt@acquia.com', 'peter.drake@acquia.com']

  s.summary       = 'Simple app deployment builder using docker.'
  s.homepage      = 'https://dev.acquia.com/'
  s.license       = 'Apache-2.0'

  s.files         = Dir['*.gemspec', '*.md', '*.txt', '{bin,lib}/**/*']
  s.bindir        = 'bin'
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.require_paths = ['lib']
  s.required_ruby_version = '>= 3.1.2'

  s.add_dependency 'bundler'
  s.add_dependency 'fpm', '> 1.4'

  s.add_development_dependency 'aruba', '> 0.13'
  s.add_development_dependency 'cucumber'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rubocop', '~> 1.22.3'
end
