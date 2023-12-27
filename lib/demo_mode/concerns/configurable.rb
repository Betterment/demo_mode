# frozen_string_literal: true

module Configurable
  extend ActiveSupport::Concern

  included do
    cattr_accessor(:configurations) { Set.new }
  end

  class_methods do
    def configurable_value(name, &block)
      configurable(name, block)
      configurations << name.to_sym
    end

    def configurable_boolean(name, default: false)
      configurable(name, -> { default })
      alias_method "#{name}?", name
      configurations << "#{name}?".to_sym
    end

    private

    def configurable(name, default_callable)
      ivar = "@#{name}"

      define_method(name) do |*args|
        if args.empty?
          instance_variable_set(ivar, default_callable.call) unless instance_variable_defined?(ivar)
          instance_variable_get(ivar)
        elsif args.length == 1
          instance_variable_set(ivar, args.first)
        else
          raise ArgumentError, "wrong number of arguments (given #{args.length}, expected 1)"
        end
      end
    end
  end
end
