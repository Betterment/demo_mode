# frozen_string_literal: true

require 'demo_mode/cli'

namespace :persona do
  desc 'Pick a persona and generate an account'
  task create: :environment do
    DemoMode::Cli.start
  end
end
