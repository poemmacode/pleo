module SafeHttp
  Response = Data.define(:url, :status, :headers, :body, :ip, :redirect_chain, :truncated, :elapsed_ms) do
    def header(name)
      headers[name.downcase]&.first
    end

    def success? = (200..299).cover?(status)
    def redirect? = (300..399).cover?(status)
  end
end
