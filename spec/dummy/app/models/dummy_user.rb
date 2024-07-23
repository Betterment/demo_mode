# frozen_string_literal: true

class DummyUser < ActiveRecord::Base
  def email
    'user@example.org'
  end
end
