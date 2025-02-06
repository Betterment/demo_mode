# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoMode do
  def render_value(callable)
    ApplicationController.helpers.instance_eval(&callable)
  end

  describe '.enabled?' do
    it 'returns false' do
      expect(described_class.enabled?).to be(false)
    end

    context 'when DEMO_MODE is enabled', :demo_mode_enabled do
      it 'returns true' do
        expect(described_class.enabled?).to be(true)
      end
    end

    context 'When WebValve is loaded' do
      let(:fake_webvalve) do
        Class.new do
          def self.enabled?
            false
          end
        end
      end

      before do
        stub_const('WebValve', fake_webvalve)
      end

      it 'returns false' do
        expect(described_class.enabled?).to be(false)
      end

      context 'and when DEMO_MODE is enabled', :demo_mode_enabled do
        it 'raises an error' do
          expect { described_class.enabled? }
            .to raise_error('Demo Mode cannot be enabled unless WebValve is enabled.')
        end
      end

      context 'and enabled' do
        before do
          allow(fake_webvalve).to receive(:enabled?).and_return(true)
        end

        it 'returns false' do
          expect(described_class.enabled?).to be(false)
        end

        context 'and when DEMO_MODE is enabled', :demo_mode_enabled do
          it 'returns true' do
            expect(described_class.enabled?).to be(true)
          end
        end
      end
    end
  end

  describe '.configure' do
    it 'accepts a mostly empty configuration' do
      generated_persona = false

      described_class.configure do
        persona :ya_basic do
          features << 'test'
          sign_in_as do
            generated_persona = true
            'something_important'
          end
        end
      end

      expect(render_value(described_class.logo)).to eq '<strong>Combustion</strong>' # default
      expect(render_value(described_class.loader)).to match %r{img src="/assets/demo_mode/loader\.png\?v=#{DemoMode::VERSION}"}o
      expect(described_class.personas.count).to eq 1
      described_class.personas.first.tap do |persona|
        expect(render_value(persona.icon)).to match %r{img src="/assets/demo_mode/icon--user\.png\?v=#{DemoMode::VERSION}"}o # default
        expect(persona.features).to eq ['test']
        expect(generated_persona).to be false
        expect(persona.generate!).to eq 'something_important'
        expect(generated_persona).to be true
      end
    end

    it 'accepts a fully-formed persona configuration' do
      generated_persona_1 = false
      generated_password_1 = nil
      generated_persona_2 = false
      generated_password_2 = nil

      described_class.configure do
        logo { '<marquee>The Logo</marquee>' }
        icon { ':-)' }
        loader { image_tag('loading-for-real.gif', skip_pipeline: true) }
        head { content_tag(:style, nil, id: 'custom-styles') }

        persona :my_persona do
          icon :tophat
          features << 'foo'
          sign_in_as do
            generated_persona_1 = true
            generated_password_1 = DemoMode.current_password # rubocop:disable RSpec/DescribedClass
            'banana'
          end
        end

        persona :other_persona do
          icon 'path/to/test-icon.png'
          features << 'bar'
          features << 'baz'
          sign_in_as do
            generated_persona_2 = true
            generated_password_2 = DemoMode.current_password # rubocop:disable RSpec/DescribedClass
            Math::PI
          end
        end

        persona :default_persona do
          features << ''
        end
      end

      expect(render_value(described_class.head)).to eq '<style id="custom-styles"></style>'
      expect(render_value(described_class.logo)).to eq '<marquee>The Logo</marquee>'
      expect(render_value(described_class.loader)).to match %r{img src="/images/loading-for-real.gif"}
      expect(described_class.personas.count).to eq 3
      described_class.personas.first.tap do |persona|
        expect(render_value(persona.icon)).to match %r{img src="/assets/demo_mode/icon--tophat\.png\?v=#{DemoMode::VERSION}"}o
        expect(persona.features).to eq(['foo'])
        expect(generated_persona_1).to be false
        expect(persona.generate!(password: 'cool_password')).to eq 'banana'
        expect(generated_persona_1).to be true
        expect(generated_password_1).to eq 'cool_password'
      end
      described_class.personas[1].tap do |persona|
        expect(render_value(persona.icon)).to match %r{img src="/assets/path/to/test-icon-.+\.png"}
        expect(persona.features).to eq %w(bar baz)
        expect(generated_persona_2).to be false
        expect(persona.generate!(password: 'secure_password')).to eq Math::PI
        expect(generated_persona_2).to be true
        expect(generated_password_2).to eq 'secure_password'
      end
      described_class.personas[2].tap do |persona|
        expect(render_value(persona.icon)).to eq ':-)'
      end
    end

    context 'when .around_persona_generation is specified' do
      before do
        described_class.configure do
          password { 'the homestar runner' }
          persona :homestar do
            features << 'test'
            sign_in_as { DemoMode.current_password } # rubocop:disable RSpec/DescribedClass
          end
          around_persona_generation do |callable|
            raise "testing '#{callable.call}' 123"
          end
        end
      end

      it 'runs the callback around the persona generation' do
        expect { described_class.personas.first.generate! }
          .to raise_error("testing 'the homestar runner' 123")
      end
    end
  end

  describe '.add_persona' do
    it 'adds a persona to the global list' do
      described_class.add_persona('my_great_persona') do
        icon :users
        features << 'foo'
        sign_in_as { 'banana' }
      end

      described_class.personas.tap do |personas|
        expect(personas.count).to eq 1
        personas.first.tap do |persona|
          expect(render_value(persona.icon)).to match %r{img src="/assets/demo_mode/icon--users\.png\?v=#{DemoMode::VERSION}"}o
          expect(persona.features).to eq ['foo']
          expect(persona.generate!).to eq 'banana'
        end
      end
    end

    it 'does not allow a persona without features' do
      expect {
        described_class.add_persona('my_great_persona') do
          sign_in_as { 'banana' }
        end
      }.to raise_error <<~ERR
        Validation failed: Persona must have at least one feature.

          For example:

          DemoMode.add_persona do
            features << 'has a cool hat'

            ...
          end
      ERR
    end
  end

  describe '.session_url' do
    let(:session) { DemoMode::Session.new(id: 2) }
    let(:demo_mode_options) { {} }
    let(:action_mailer_options) { {} }

    before do
      allow(DemoMode::Engine.routes).to receive(:default_url_options).and_return(demo_mode_options)
      allow(ActionMailer::Base).to receive(:default_url_options).and_return(action_mailer_options)
    end

    context 'when URL configuration is not provided' do
      it 'generates a path' do
        expect(described_class.session_url('1')).to eq('/ohno/sessions/1')
        expect(described_class.session_url(session)).to eq('/ohno/sessions/2')
      end
    end

    context 'when DemoMode has url configuration' do
      let(:demo_mode_options) { { host: 'demo_mode.local', port: 4242 } }

      it 'generates a URL' do
        expect(described_class.session_url('1')).to eq('http://demo_mode.local:4242/ohno/sessions/1')
        expect(described_class.session_url(session)).to eq('http://demo_mode.local:4242/ohno/sessions/2')
      end
    end

    context 'when ActionMailer has url configuration' do
      let(:action_mailer_options) { { host: 'mailer.local', port: 4242 } }

      it 'generates a URL' do
        expect(described_class.session_url('1')).to eq('http://mailer.local:4242/ohno/sessions/1')
        expect(described_class.session_url(session)).to eq('http://mailer.local:4242/ohno/sessions/2')
      end
    end
  end
end
