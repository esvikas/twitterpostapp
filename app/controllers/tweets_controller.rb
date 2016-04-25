require 'faraday'
require 'faraday/request/multipart'
require 'addressable/uri'
require 'simple_oauth'
class TweetsController < ApplicationController
  BASE_URL = 'https://api.twitter.com'
  def new

  end
  def create
      update_status(twitter_params[:message])
      flash[:success] = @response
    redirect_to root_path
  end
  private
  def update_status(status, options = {})
    perform_post_with_object('/1.1/statuses/update.json',:status => status)
  end
  def perform_post_with_object(path, options)
    perform_request_with_object(:post, path, options)
  end
  def perform_request_with_object(request_method, path, options)
    response = perform_request(request_method, path, options)
  end
  def perform_request(request_method, path, options={})
    twitter_rest_request_perform(request_method, path, options)
  end
  def twitter_rest_request_perform(request_method, path, options={})
    @request_method=request_method.to_sym
    @path=path
    @uri=Addressable::URI.parse(connection.url_prefix + path)
    @options = options
    @signature_options = @request_method == :post && @options.values.any? { |value| value.respond_to?(:to_io) } ? {} : @options
    request_header
  end
  def request_header
    headers = {}
    headers[:authorization] = auth_header
    headers
    response = connection.send(@request_method, @path, @options) { |request| request.headers.update(headers) }.env
    @response = response.response_headers[:status]
  end
  def auth_header
    oauth_auth_header.to_s
  end
  def oauth_auth_header
    SimpleOAuth::Header.new(@request_method, @uri, @signature_options, credentials)
  end
  def credentials
    {
        :consumer_key      => Rails.application.secrets.consumer_key,
        :consumer_secret   => Rails.application.secrets.consumer_secret,
        :token             => Rails.application.secrets.access_token,
        :token_secret      => Rails.application.secrets.access_token_secret,
        :ignore_extra_keys => true,
    }
  end
  def connection_options=(connection_options)
    @connection_options = connection_options
  end

  def connection_options
    @connection_options ||= {
        :builder => middleware,
        :headers => {
            :accept => 'application/json',
        },
        :request => {
            :open_timeout => 10,
            :timeout => 30,
        }
    }
  end

  def middleware=(middleware)
    @middleware = middleware
  end

  def middleware
    @middleware ||= Faraday::RackBuilder.new do |faraday|
      faraday.request :multipart
      faraday.request :url_encoded
      faraday.adapter :httpclient
    end
  end

  def connection
    @connection ||= Faraday.new(BASE_URL, connection_options)
  end

  def twitter_params
    params.require(:tweet).permit(:message)
  end
end