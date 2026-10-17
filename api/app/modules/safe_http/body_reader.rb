require "zlib"

module SafeHttp
  # Accumulates a response body up to max_bytes of *decoded* content, inflating gzip/deflate
  # incrementally so a compression bomb is cut off after max_bytes instead of being expanded.
  # (Net::HTTP's own inflater cannot be interrupted mid-body without breaking the connection cleanup.)
  class BodyReader
    class LimitReached < StandardError; end

    attr_reader :body

    def initialize(content_encoding, max_bytes)
      @max_bytes = max_bytes
      @body = +""
      @encoding = content_encoding.to_s.downcase.strip
      @inflater = Zlib::Inflate.new(32 + Zlib::MAX_WBITS) if %w[gzip x-gzip deflate].include?(@encoding)
      @raw_deflate_tried = false
    end

    def <<(chunk)
      @inflater ? inflate(chunk) : append(chunk)
    end

    def finish
      @inflater&.finish&.then { append(_1) }
    rescue Zlib::Error
      nil
    ensure
      @inflater&.close
    end

    private
      def inflate(chunk)
        @inflater.inflate(chunk) { append(_1) }
      rescue Zlib::DataError
        # Some servers send raw DEFLATE without the zlib header.
        raise if @raw_deflate_tried || @encoding != "deflate" || @body.present?

        @raw_deflate_tried = true
        @inflater.close
        @inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
        retry
      end

      def append(data)
        room = @max_bytes - @body.bytesize
        @body << data.byteslice(0, room)
        raise LimitReached if data.bytesize > room
      end
  end
end
