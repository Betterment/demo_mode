# frozen_string_literal: true

require 'cli/ui'
require 'demo_mode/clis/multi_word_search_patch'

# rubocop:disable Rails/Output, Rails/Exit
class DemoMode::Cli
  class << self
    def start
      DemoMode::Clis::MultiWordSearchPatch.apply!
      CLI::UI::StdoutRouter.enable

      if DemoMode.personas.empty?
        CLI::UI::Frame.open('{{?}} No Personas Found! {{?}}', color: :red) do
          puts 'Please define personas at config/personas'
          puts 'Read more at https://github.com/betterment/demo_mode'
        end
        exit
      end
      prompt_persona
    end

    def created_sessions
      @created_sessions ||= []
    end

    private

    def ask_next_step
      CLI::UI::Prompt.ask('What next?') do |handler|
        handler.option("I'm done") do
          puts "good bye"
        end
        handler.option('Keep going') do
          prompt_persona
        end
      end
    end

    def prompt_persona
      CLI::UI::Frame.open("{{*}} Generate an Account! {{*}}") do
        CLI::UI::Prompt.ask('Which persona should we use?') do |handler|
          DemoMode.personas.sort_by { |p| p.name.to_s }.each do |persona|
            persona_label = persona.name.to_s.titleize

            handler.option(persona_label) do
              persona.features.each do |feature|
                puts "👉 #{feature}"
              end

              named_tags = SemanticLogger.named_tags if defined?(SemanticLogger)

              variant = variant_for(persona, persona_label)

              CLI::UI::Spinner.spin("generating account...") do |spinner|
                SemanticLogger.push_named_tags(named_tags) if defined?(SemanticLogger)

                session = DemoMode::Session.new(persona_name: persona.name, variant: variant)
                session.save_and_generate_account!
                spinner.update_title('done!')
                created_sessions << session
              end
            end
          end
        end
      end
      display_personas
      ask_next_step
    end

    def variant_for(persona, persona_label)
      if persona.variants.keys == ['default']
        :default
      else
        CLI::UI::Prompt.ask(
          "Which variant should we use for #{persona_label}?",
          options: persona.variants.keys,
        )
      end
    end

    def display_personas
      created_sessions.each do |session|
        CLI::UI::Frame.open("{{*}} #{session.persona_name} {{*}}") do
          puts "👤 :: #{session.signinable.email}"
          puts "🔑 :: #{session.signinable_password}"
          puts "🌐 :: #{DemoMode.session_url(session)}"
        end
      end
    end
  end
end
# rubocop:enable Rails/Output, Rails/Exit
