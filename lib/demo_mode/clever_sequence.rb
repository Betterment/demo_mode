# frozen_string_literal: true

require_relative 'clever_sequence/lower_bound_finder'
require_relative 'clever_sequence/in_memory_backend'
require_relative 'clever_sequence/postgres_backend'

class CleverSequence
  DEFAULT_BLOCK = ->(i) { i }

  cattr_accessor(:sequences) { {} }
  cattr_accessor(:use_database_sequences) { false }
  cattr_accessor(:enforce_sequences_exist) { false }
  cattr_accessor(:retry_on_uniqueness_violation) { true }

  class << self
    alias use_database_sequences? use_database_sequences
    alias enforce_sequences_exist? enforce_sequences_exist
    alias retry_on_uniqueness_violation? retry_on_uniqueness_violation

    def backend
      use_database_sequences? ? PostgresBackend : InMemoryBackend
    end

    def reset!
      backend.reset!
      sequences.each_value(&:reset!)
    end

    def with_sequence_adjustment(&)
      last_values = snapshot_last_values
      reset!
      backend.with_sequence_adjustment(last_values:, &)
    end

    def snapshot_last_values
      sequences.transform_values { |seq| seq.send(:last_value) }.compact
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
    @nil_klass_mutex = Mutex.new
  end

  def with_class(klass)
    sequences[[klass.name, attribute.to_s]] = self if klass && !@klass
    @klass ||= klass
    self
  end

  def next
    @last_value = if klass
      self.class.backend.nextval(klass, attribute, block)
    else
      @nil_klass_mutex.synchronize { (@last_value || 0) + 1 }
    end
    last
  end

  def last
    block.call(@last_value || (klass ? self.class.backend.starting_value(klass, attribute, block) : 0))
  end

  def reset!
    @last_value = nil
  end

  private

  attr_reader :last_value
end
