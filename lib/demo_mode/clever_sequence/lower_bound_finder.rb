# frozen_string_literal: true

class CleverSequence
  LowerBoundFinder = Struct.new(:klass, :column_name, :block) do
    def lower_bound(hint: nil)
      start = hint && hint >= 1 ? hint : 1
      # If the hint doesn't exist, fall back to starting from 1.
      # This avoids the next_between(0, n) = 0 trap that occurs when
      # binary searching downward from a non-existent hint value.
      start = 1 if start > 1 && !exists?(start)
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
