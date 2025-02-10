# frozen_string_literal: true

# FIXME: This patches the 'f' option so that it is capable of multi-word searches.
#        Otherwise entering 'word1 word3' will fail to find 'word1 word2 word3'
#        LINES CHANGED: 17-20
#
# source: https://github.com/Shopify/cli-ui/blob/06ebc472fe4e04d6b58e2747c6e8a6f42d7ac2b7/lib/cli/ui/prompt/interactive_options.rb#L345
module DemoMode::Clis
  module MultiWordSearchPatch
    def self.apply!
      patched_class.prepend(self) unless applied?
    end

    def self.applied?
      patched_class < self
    end

    def self.patched_class
      CLI::UI::Prompt.const_get(:InteractiveOptions)
    end

    def presented_options(recalculate: false) # rubocop:disable Metrics/PerceivedComplexity
      return @presented_options unless recalculate

      @presented_options = @options.zip(1..Float::INFINITY)
      if has_filter?
        @presented_options.select! do |option, _|
          @filter.downcase.split.compact.all? do |word|
            option.downcase.include?(word)
          end
        end
      end

      # Used for selection purposes
      @filtered_options = @presented_options.dup

      @presented_options.unshift([DONE, 0]) if @multiple

      ensure_visible_is_active if has_filter?

      while num_lines > max_lines
        # try to keep the selection centered in the window:
        if distance_from_selection_to_end > distance_from_start_to_selection
          # selection is closer to top than bottom, so trim a row from the bottom
          ensure_last_item_is_continuation_marker
          @presented_options.delete_at(-2)
        else
          # selection is closer to bottom than top, so trim a row from the top
          ensure_first_item_is_continuation_marker
          @presented_options.delete_at(1)
        end
      end

      @presented_options
    end
  end
end
