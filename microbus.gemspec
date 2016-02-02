# coding: utf-8
require_relative 'lib/microbus/version'

Gem::Specification.new do |s|
  s.name          = 'microbus'
  s.version       = Microbus::VERSION
  s.authors       = ['Glenn Pratt']
  s.email         = ['glenn.pratt@acquia.com']

  s.summary       = 'Simple app deployment builder using docker.'
  s.homepage      = 'https://dev.acquia.com/'
  s.license       = 'Apache-2.0'

  s.files         = Dir['*.gemspec', '*.md', '*.txt', '{bin,lib}/**/*']
  s.bindir        = 'bin'
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_development_dependency 'bundler', '~> 1.11'
  s.add_development_dependency 'rake', '~> 10.0'
  s.add_development_dependency 'rubocop'
end
