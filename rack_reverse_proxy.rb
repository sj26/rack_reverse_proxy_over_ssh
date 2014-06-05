require "net/http"
require "net/https"
require "rack/request"
require "rack/utils"
require "uri"

class RackReverseProxy
  NET_HTTP_METHOD_CLASS = {
    "GET" => Net::HTTP::Get,
    "HEAD" => Net::HTTP::Head,
    "POST" => Net::HTTP::Post,
    "PATCH" => Net::HTTP::Patch,
    "PUT" => Net::HTTP::Put,
    "PROPPATCH" => Net::HTTP::Proppatch,
    "LOCK" => Net::HTTP::Lock,
    "UNLOCK" => Net::HTTP::Unlock,
    "OPTIONS" => Net::HTTP::Options,
    "PROPFIND" => Net::HTTP::Propfind,
    "DELETE" => Net::HTTP::Delete,
    "MOVE" => Net::HTTP::Move,
    "COPY" => Net::HTTP::Copy,
    "MKCOL" => Net::HTTP::Mkcol,
    "TRACE" => Net::HTTP::Trace,
  }.freeze

  def initialize(upstream_uri, options={})
    @upstream_uri = upstream_uri
    @upstream_uri = URI.parse(@upstream_uri) if @upstream_uri.is_a? String
    raise ArgumentError, "Must be given a URI" unless @upstream_uri.is_a? URI::Generic
    @options = options
  end

  attr_reader :upstream_uri, :options

  def call(env)
    rack_request = Rack::Request.new(env)

    uri = URI.join(upstream_uri, rack_request.fullpath)

    if options[:logger]
      options[:logger].info { "Proxying connect to #{uri}" }
    end

    headers = extract_request_headers(env)

    unless options[:preserve_host]
      headers["Host"] = uri.host
    end

    http = if options[:proxy_ssh]
      Net::HTTPOverSSH.new(options[:proxy_ssh], uri.host, uri.port)
    else
      Net::HTTP.new(uri.host, uri.port)
    end

    if options[:logger]
      http.set_debug_output(options[:logger])
    end

    if uri.scheme == "https"
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end

    http_method = rack_request.request_method

    unless klass = NET_HTTP_METHOD_CLASS[http_method.upcase]
      return [405, {}, ["Unknown method: #{http_method} (known: #{NET_HTTP_METHOD_CLASS.keys.join(", ")})"]]
    end

    http.start do |http|
      request = klass.new(uri.request_uri, headers)

      if options[:username] and options[:password]
        request.basic_auth options[:username], options[:password]
      end

      if request.request_body_permitted?
        request["Transfer-Encoding"] = "chunked"
        request.body_stream = rack_request.body
      end

      # TODO: Make this a returned enumerator
      body = ""
      response = http.request(request) do |response|
        response.read_body do |segment|
          body << segment
        end
      end

      [response.code, extract_response_headers(response), [body]]
    end
  end

  private

  def extract_request_headers(env)
    Rack::Utils::HeaderHash.new.tap do |headers|
      env.each do |env_name, value|
        if /\AHTTP_(?<header_name>.*)\Z/ =~ env_name
          headers[header_name.sub("_", "-")] = value
        end
      end
    end
  end

  def extract_response_headers(http_response)
    response_headers = Rack::Utils::HeaderHash.new(http_response.to_hash)
    # handled by Rack
    response_headers.delete("Status")
    # TODO: figure out how to handle chunked responses
    response_headers.delete("Transfer-Encoding")
    # TODO: Verify Content Length, and required Rack headers
    response_headers
  end
end
