# frozen_string_literal: true

module SystemSpecHelper
  SHOW_EXCEPTIONS_KEY = 'action_dispatch.show_exceptions'
  SHOW_DETAILED_EXCEPTIONS_KEY = 'action_dispatch.show_detailed_exceptions'

  def with_production_error_handling
    env_config = Rails.application.env_config
    original_show_exceptions = env_config[SHOW_EXCEPTIONS_KEY]
    original_show_detailed_exceptions = env_config[SHOW_DETAILED_EXCEPTIONS_KEY]

    env_config[SHOW_EXCEPTIONS_KEY] = if ActionPack.gem_version >= Gem::Version.new('7.1')
      :all
    else
      true
    end

    env_config[SHOW_DETAILED_EXCEPTIONS_KEY] = false
    yield
  ensure
    env_config[SHOW_EXCEPTIONS_KEY] = original_show_exceptions
    env_config[SHOW_DETAILED_EXCEPTIONS_KEY] = original_show_detailed_exceptions
  end
end
