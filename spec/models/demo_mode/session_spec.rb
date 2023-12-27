# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoMode::Session do
  include ActiveJob::TestHelper

  it 'is valid at rest' do
    subject.persona_name = :the_everyperson
    subject.variant = 'XIV'
    expect(subject).to be_valid
  end

  it 'validates persona name' do
    subject.persona_name = nil
    expect(subject).not_to be_valid
    expect(subject.errors.full_messages).to match_array("Persona name can't be blank")
  end

  it 'validates persona variant' do
    subject.variant = nil
    expect(subject).not_to be_valid
    expect(subject.errors[:variant]).to match_array("can't be blank")
  end

  describe '#begin_demo' do
    it 'returns nil' do
      expect(subject.begin_demo).to be_nil
    end

    context 'when the persona provides a custom sign in behavior' do
      before do
        DemoMode.add_persona :hal_9000 do
          features << ""
          sign_in_as { DummyUser.create!(name: 'HAL') }

          begin_demo do
            raise "I'm afraid I can't do that, Dave."
          end
        end
      end

      it 'returns a proc that raises the expected message' do
        subject.persona_name = :hal_9000
        expect(subject.begin_demo).to be_present
        expect { subject.begin_demo.call }
          .to raise_error "I'm afraid I can't do that, Dave."
      end
    end
  end

  describe '#save' do
    subject { described_class.new(persona_name: :the_everyperson) }

    it 'raises an error when the persona is not recognized' do
      expect(subject.persona_name).to eq 'the_everyperson'
      perform_enqueued_jobs do
        expect { subject.save! }.to raise_error(RuntimeError, 'Unknown persona: the_everyperson')
      end
    end

    context 'when the persona is known' do
      let(:random_name) { SecureRandom.hex }

      before do
        name = random_name
        DemoMode.configure do
          persona :the_everyperson do
            features << 'test'

            sign_in_as { DummyUser.create!(name: name) }
          end
        end
      end

      after do
        DemoMode.send(:remove_instance_variable, '@configuration')
        load Rails.root.join('config/initializers/demo_mode.rb')
      end

      it 'generates a new account and assigns it to the session' do
        perform_enqueued_jobs do
          expect { subject.save! }.to change { described_class.first&.signinable&.name }.from(nil).to(random_name)
          expect(described_class.count).to eq 1
          expect(DummyUser.count).to eq 1
        end
      end
    end
  end
end
