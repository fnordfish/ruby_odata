module OData
  class Resource
    attr_reader :url, :options

    def initialize(url, options={}, &block)
      @url = url
      @block = block

      faraday_adapter         = options.fetch(:faraday_adapter, :net_http)
      faraday_adapter_options = options.fetch(:faraday_adapter_options, {})
      user                    = options[:user]
      password                = options[:password]
      timeout                 = options[:timeout]
      open_timeout            = options[:open_timeout]

      @conn = Faraday.new(url: url, ssl: { verify: options[:verify_ssl] }) do |faraday|
        faraday.response :raise_error
        faraday.adapter  faraday_adapter, faraday_adapter_options

        faraday.options.timeout      = timeout if timeout
        faraday.options.open_timeout = open_timeout if open_timeout

        faraday.headers = (faraday.headers || {})
          .merge!(options[:headers] || {})
          .merge!(
            :accept => '*/*; q=0.5, application/xml'
          )

        faraday.basic_auth user, password if password # this adds to headers so must be behind

        yield(faraday) if block
      end

      @conn.headers[:user_agent] = options.fetch(:user_agent) { "Ruby::OData/#{OData::VERSION}" }
    end

    def get(additional_headers={})
      @conn.get do |req|
        req.url url
        req.headers = (headers || {}).merge(additional_headers)
      end
    end

    def head(additional_headers={})
      @conn.head do |req|
        req.url url
        req.headers = (headers || {}).merge(additional_headers)
      end
    end

    def post(payload, additional_headers={})
      @conn.post do |req|
        req.url url
        req.headers = (headers || {}).merge(additional_headers)
        req.body = prepare_payload payload
      end
    end

    def put(payload, additional_headers={})
      @conn.put do |req|
        req.url url
        req.headers = (headers || {}).merge(additional_headers)
        req.body = prepare_payload payload
      end
    end

    def patch(payload, additional_headers={})
      @conn.patch do |req|
        req.url url
        req.headers = (headers || {}).merge(additional_headers)
        req.body = prepare_payload payload
      end
    end

    def delete(additional_headers={})
      @conn.delete do |req|
        req.url url
        req.headers = (headers || {}).merge(additional_headers)
      end
    end

    def to_s
      url
    end

    def headers
      @conn.headers || {}
    end

    # Construct a subresource, preserving authentication.
    #
    # Example:
    #
    #   site = RestClient::Resource.new('http://example.com', user: 'adam', pasword: 'mypasswd')
    #   site['posts/1/comments'].post 'Good article.', :content_type => 'text/plain'
    #
    # This is especially useful if you wish to define your site in one place and
    # call it in multiple locations:
    #
    #   def orders
    #     RestClient::Resource.new('http://example.com/orders', user: 'admin', password: 'mypasswd')
    #   end
    #
    #   orders.get                     # GET http://example.com/orders
    #   orders['1'].get                # GET http://example.com/orders/1
    #   orders['1/items'].delete       # DELETE http://example.com/orders/1/items
    #
    # Nest resources as far as you want:
    #
    #   site = RestClient::Resource.new('http://example.com')
    #   posts = site['posts']
    #   first_post = posts['1']
    #   comments = first_post['comments']
    #   comments.post 'Hello', :content_type => 'text/plain'
    #
    def [](suburl, &new_block)
      self.class.new(concat_urls(url, suburl), options, &(@block || new_block))
    end

    def concat_urls(url, suburl) # :nodoc:
      File.join(url.to_s, suburl.to_s)
    end

    def prepare_payload payload
      JSON.generate(payload)
    rescue JSON::GeneratorError
      payload
    end
  end
end
