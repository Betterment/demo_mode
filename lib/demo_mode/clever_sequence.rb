# frozen_string_literal: true

class CleverSequence
  DEFAULT_BLOCK = ->(i) { i }

  cattr_accessor(:sequences) { {} }
  cattr_accessor(:use_database_sequences) { false }
  cattr_accessor(:enforce_sequences_exist) { false }

  class << self
    alias_method :use_database_sequences?, :use_database_sequences
    alias_method :enforce_sequences_exist?, :enforce_sequences_exist

    def reset!
      sequences.each_value(&:reset!)
    end

    def next(klass, name)
      lookup(klass, name)&.next
    end

    def last(klass, name)
      lookup(klass, name)&.last
    end

    private

    def lookup(klass, name)
      sequences[[klass.name, name.to_s]] ||= new(name).with_class(klass)
    end
  end

  attr_reader :klass, :attribute, :block

  def initialize(attribute, &block)
    @attribute = attribute.to_s
    @block = block || DEFAULT_BLOCK
  end

  def with_class(klass)
    sequences[[klass.name, attribute.to_s]] = self if klass && !@klass
    @klass ||= klass
    self
  end

  def next
    @last_value = last_value + 1
    last
  end

  def last
    block.call(last_value)
  end

  def reset!
    remove_instance_variable(:@last_value) if instance_variable_defined?(:@last_value)
  end

  private

  def last_value
    @last_value ||= starting_value
  end

  def starting_value
    if column_exists?
      LowerBoundFinder.new(klass, column_name, block).lower_bound
    else
      0
    end
  end

  def column_name
    klass.attribute_aliases[attribute] || attribute
  end

  def column_exists?
    klass && klass.column_names.include?(column_name)
  end

  LowerBoundFinder = Struct.new(:klass, :column_name, :block) do
    def lower_bound(current = 1, lower = 0, upper = Float::INFINITY)
      if exists?(current)
        lower_bound(next_between(current, upper), [current, lower].max, upper)
      elsif current - lower > 1
        lower_bound(next_between(lower, current), lower, [current, upper].min)
      else # current should == lower + 1
        lower
      end
    end

    private

    def next_between(lower, upper)
      [((lower + 1) / 2) + (upper / 2), lower * 2].min
    end

    def exists?(value)
      klass.public_send(finder_method, block.call(value))
    end

    # TODO: Move onto modern finder methods.
    def finder_method
      :"find_by_#{column_name.to_s.underscore.sub('_crypt', '')}"
    end
  end
end
