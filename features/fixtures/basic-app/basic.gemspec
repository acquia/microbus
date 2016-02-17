Gem::Specification.new do |s|
  s.name         = 'basic'
  s.version      = '0.0.0'
  s.authors      = ['Basic']
  s.summary      = 'Test gemspec for microbus.'
  s.files        = Dir['Gemfile*', 'Rakefile', '*.gemspec', '*.md', '*.raml',
                       '*.ru', '*.yml',
                       '{bin,config,db,doc,lib,schema,script}/**/*']
  s.require_path = 'lib'
  s.bindir       = 'bin'
  s.executables = Dir['bin/*'].map { |f| File.basename(f) }

  s.add_dependency('sequel')

  # s.add_development_dependency('microbus')
  s.add_development_dependency('rake')
end
