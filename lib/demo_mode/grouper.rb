# frozen_string_literal: true

module DemoMode
  class Grouper
    def initialize(personas, groups:)
      @personas = personas
      @groups = groups
    end

    def named
      buckets.except(nil).sort_by { |group, _| sort_key(group) }
    end

    def named_groups
      named.map { |group, personas| [name_for(group), personas] }
    end

    def ungrouped
      buckets.fetch(nil, [])
    end

    def name_for(group)
      return group unless groups.is_a?(Hash)

      groups.stringify_keys[group.to_s] || group
    end

    private

    attr_reader :personas, :groups

    def buckets
      personas.group_by(&:group)
    end

    def sort_key(group)
      rank = group_keys.index(group.to_s)
      [rank || Float::INFINITY, group.to_s]
    end

    def group_keys
      (groups.is_a?(Hash) ? groups.keys : groups).map(&:to_s)
    end
  end
end
