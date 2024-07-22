# frozen_string_literal: true

require 'spec_helper'
require 'demo_mode/cli'

RSpec.describe DemoMode::Cli do
  it 'creates a persona' do
    DemoMode.current_password = 'testing123'
    DemoMode.configure do
      personas_path 'config/system-test-personas'
    end

    # Just keep pressing enter
    allow($stdin).to receive(:tty?).and_return(false)
    allow($stdin).to receive(:getc).and_return("\r")

    # Disable the spinner because it causes the program to freeze?
    allow(CLI::UI::Spinner).to receive(:spin).and_yield(double(update_title: nil))

    expected_output = include(
      'the_everyperson',
      '👤 :: user@example.org',
      '🔑 :: testing123',
      '🌐 :: http://www.example.com/ohno/sessions/1',
    )

    expect { DemoMode::Cli.start }.to output(expected_output).to_stdout
  end
end
