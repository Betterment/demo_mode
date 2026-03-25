# frozen_string_literal: true

class CleverSequence
  class LowerBoundFinder
    attr_reader :klass, :column_name, :block

    def initialize(klass, column_name, block)
      @klass = klass
      @column_name = column_name
      @block = block
    end

    def lower_bound(hint: nil)
      start = hint && hint >= 1 ? hint : 1
      # If the hint overshoots the actual data, return it directly.
      # The hint is a previously-known high-water mark, so it's a valid
      # lower bound. Callers pass the result through GREATEST against the
      # PG sequence, so a higher value is always safe and avoids a costly
      # binary search back down to data that won't be used anyway.
      return hint if start > 1 && !exists?(start)

      _lower_bound(start, 0, Float::INFINITY)
    end

    private

    def _lower_bound(current, lower, upper)
      if exists?(current)
        # When upper is at most current + 1, we know current is the highest
        # existing value (upper is always a known-false or Infinity bound).
        # next_between would return current due to integer division, causing
        # infinite recursion, so return early.
        return current if upper <= current + 1

        _lower_bound(next_between(current, upper), [current, lower].max, upper)
      elsif current - lower > 1
        _lower_bound(next_between(lower, current), lower, [current, upper].min)
      else # current should == lower + 1
        lower
      end
    end

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
