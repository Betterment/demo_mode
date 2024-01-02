# frozen_string_literal: true

DemoMode.add_persona :zendaya do
  features << 'Can sing and dance and act'
  callout true

  sign_in_as do |_pwd|
    DummyUser.create!(name: 'Zendaya')
  end

  variant 'MJ' do
    sign_in_as { DummyUser.create!(name: 'MJ') }
  end
end
