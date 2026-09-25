# frozen_string_literal: true

DemoMode.add_persona do
  group 'Explicit group'
  features << 'foo'
  sign_in_as { DummyUser.create!(name: 'Erin') }
end
