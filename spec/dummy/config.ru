# frozen_string_literal: true

ENV['DEMO_MODE'] ||= '1'

require_relative 'config/environment'

run Dummy::Application
system 'open http://localhost:3000'
