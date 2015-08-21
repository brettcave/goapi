require 'net/http'
require 'net/https'

class GoAPI
  class Http
    class Error < StandardError
      def initialize(request_class, url, response)
        super("error[#{request_class.name}][#{url}][#{response.code}]: #{response.body}")
      end
    end

    def initialize(credentials)
      @credentials = credentials || {}
    end

    def get(url)
      process(Net::HTTP::Get, url)
    end

    def post(url, params)
      process(Net::HTTP::Post, url, params)
    end

    def process(request_class, url, form_data={}, headers=nil)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)

      if uri.scheme == 'https'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      request = request_class.new(uri.request_uri, form_data)

      if headers
        headers.each do |key, value|
          request[key] = value
        end
      end

      if @credentials[:basic_auth]
        request.basic_auth *@credentials[:basic_auth]
      end

      response = http.request(request)
      raise Error.new(request_class, url, response) if response.code.to_i >= 300

      to_canonical_response(response)
    end

    def to_canonical_response(response)
      headers = {}
      response.each_header {|key, value|  headers[key] = value }
      [response.code.to_i, response.body, headers]
    end
  end
end
