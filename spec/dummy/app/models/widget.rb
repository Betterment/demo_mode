# frozen_string_literal: true

class Widget < ActiveRecord::Base
  alias_attribute :encrypted_column, :encrypted_column_crypt
  alias_attribute :integer_aliased, :integer_column
  alias_attribute :name_aliased, :string_column

  class << self
    def find_by_encrypted_column(value)
      find_by(encrypted_column_crypt: rot_13(value))
    end

    def _encrypted_column_config
      { 'encrypted_column_crypt' => true }
    end

    def rot_13(string)
      string.tr('A-Za-z', 'N-ZA-Mn-za-m')
    end
  end

  def encrypted_column
    encrypted_column_crypt
  end

  def encrypted_column=(encrypted_column_crypt)
    self.encrypted_column_crypt = encrypted_column_crypt
  end

  def encrypted_column_crypt
    self.class.rot_13(super)
  end

  def encrypted_column_crypt=(value)
    super(self.class.rot_13(value))
  end
end
