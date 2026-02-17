# frozen_string_literal: true

class CleverSequence
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
