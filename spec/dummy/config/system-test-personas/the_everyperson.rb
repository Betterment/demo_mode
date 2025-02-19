# frozen_string_literal: true

DemoMode.add_persona do
  features << 'Can sing'

  sign_in_as do |_pwd|
    DummyUser.create!(name: 'Spruce Bringsteen')
  end

  variant 'alternate bruce' do
    sign_in_as do |_pwd|
      DummyUser.create!(name: 'Spruce Sringbeen')
    end
  end

  variant 'erroring' do
    sign_in_as do |_pwd|
      DummyUser.create!(name: 'Bob')
      raise 'Oops! Error error!'
    end
  end
end
