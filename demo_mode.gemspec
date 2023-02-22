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

  s.required_ruby_version = ">= 2.7"

  s.add_dependency 'rails', '>= 5.2'
  s.add_dependency 'sprockets-rails'
  s.add_dependency 'sqlite3'
  s.add_dependency 'typedjs-rails'

  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'betterlint'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'combustion'
  s.add_development_dependency 'factory_bot'
  s.add_development_dependency 'net-smtp' # required by combustion on newer rubies
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'selenium-webdriver'
  s.add_development_dependency 'uncruft'
  s.add_development_dependency 'webrick'
end
