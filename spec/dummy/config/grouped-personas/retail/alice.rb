# frozen_string_literal: true

DemoMode.add_persona do
  features << 'foo'
  sign_in_as { DummyUser.create!(name: 'Alice') }
end
