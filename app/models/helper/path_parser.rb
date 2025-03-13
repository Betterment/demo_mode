# frozen_string_literal: true

# https://github.com/plataformatec/devise/blob/88724e10adaf9ffd1d8dbfbaadda2b9d40de756a/lib/devise/controllers/store_location.rb#L34
module Helper
  class PathParser
    class << self
      def parse(value)
        uri = parse_uri(value)
        if uri
          path = [uri.path.sub(%r{\A/+}, '/'), uri.query].compact.join('?')
          [path, uri.fragment].compact.join('#')

        end
      end

      private

      def parse_uri(location)
        location && URI.parse(location)
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
