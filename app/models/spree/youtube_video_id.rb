module Spree
  class YoutubeVideoId
    ID = /[a-zA-Z0-9_-]{11}/.freeze

    def self.from_url(url)
      return nil if url.blank?

      str = url.to_s.strip
      return nil if str.blank?

      if (m = str.match(%r{youtu\.be/(#{ID})}))
        return m[1]
      end

      if (m = str.match(%r{youtube\.com/(?:shorts|embed)/(#{ID})}))
        return m[1]
      end

      if (m = str.match(/[?&]v=(#{ID})/))
        return m[1]
      end

      nil
    end
  end
end
