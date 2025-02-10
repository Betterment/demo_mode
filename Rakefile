# frozen_string_literal: true

begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

Bundler::GemHelper.install_tasks

APP_RAKEFILE = File.expand_path('spec/dummy/Rakefile', __dir__)
load 'rails/tasks/engine.rake'

require 'rubocop/rake_task'
RuboCop::RakeTask.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

def default_task
  if ENV.fetch('APPRAISAL_INITIALIZED', nil) || ENV.fetch('CI', nil)
    %i(rubocop spec)
  else
    require 'appraisal'
    Appraisal::Task.new
    %i(appraisal)
  end
end

task(:default).clear.enhance(default_task)
