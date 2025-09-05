# frozen_string_literal: true

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

  s.files = Dir['{app,config,lib,db,public}/**/*', "LICENSE", "Rakefile", "README.md"]

  s.required_ruby_version = ">= 3.2"

  rails_constraints = ['>= 7.2', '< 8.1']

  s.add_dependency 'actionpack', rails_constraints
  s.add_dependency 'activejob', rails_constraints
  s.add_dependency 'activerecord', rails_constraints
  s.add_dependency 'activesupport', rails_constraints
  s.add_dependency 'cli-ui', '~> 2.3'
  s.add_dependency 'railties', rails_constraints

  s.add_development_dependency 'actionmailer', rails_constraints
  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'betterlint'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'cuprite'
  s.add_development_dependency 'factory_bot'
  s.add_development_dependency 'net-smtp'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'sorbet-runtime'
  s.add_development_dependency 'sprockets-rails'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'webrick'
end
