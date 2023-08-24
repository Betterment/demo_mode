$LOAD_PATH.push File.expand_path('lib', __dir__)

require 'demo_mode/version'

Gem::Specification.new do |s|
  s.name = 'demo_mode'
  s.version = DemoMode::VERSION
  s.authors = ['Nathan Griffith']
  s.email = ['nathan@betterment.com']
  s.homepage = 'http://github.com/betterment/demo_mode'
  s.summary = 'A configurable demo mode for your Rails app.'
  s.description = 'A configurable demo mode for your Rails app. Specify your desired "personas" and DemoMode will handle the rest.'
  s.license = 'MIT'
  s.metadata['rubygems_mfa_required'] = 'true'
  s.metadata['changelog_uri'] = 'https://github.com/Betterment/demo_mode/blob/main/CHANGELOG.md'

  s.files = Dir['{app,config,lib,db}/**/*', "LICENSE", "Rakefile", "README.md"]

  s.required_ruby_version = ">= 3.0"

  s.add_dependency 'rails', '>= 6.1'
  s.add_dependency 'sprockets-rails'
  s.add_dependency 'typedjs-rails'
end
