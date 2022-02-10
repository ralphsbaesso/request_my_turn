# frozen_string_literal: true

require 'json'
require 'net/http'
require 'ostruct'
require 'timeout'
require 'uri'

require_relative 'request_my_turn/version'

class RequestMyTurn
  attr_accessor :id, :locked

  class WithoutBlock < StandardError
    def initialize
      super 'This service must be used with `block\'!'
    end
  end

  class InvalidUrl < StandardError
    def initialize(url)
      super "Invalid url: #{url}"
    end
  end

  class TimeoutError < StandardError
    def initialize(time)
      super "I didn't get the turn within #{time} seconds"
    end
  end

  class << self
    def configure
      block_given? ? yield(settings) : settings
    end

    def settings
      @settings ||= OpenStruct.new(
        url: nil,
        after: nil,
        before: nil,
        switch: true,
        timeout: nil,
        lock_seconds: nil,
        headers: nil,
        ignore_timeout_error: nil
      )
    end
  end

  %i[url after before switch timeout lock_seconds headers ignore_timeout_error method_added].each do |name|
    define_method(name) do
      value = instance_variable_get "@#{name}"
      result = value.nil? ? self.class.settings[name] : value
      result.is_a?(Proc) ? result.call(self) : result
    end
  end

  def initialize(queue_name, **options)
    @queue_name = queue_name

    @url = options[:url]
    @after = options[:after]
    @before = options[:before]
    @switch = options[:switch]
    @timeout = options[:timeout]
    @lock_seconds = options[:lock_seconds] || 60
    @headers = options[:headers]
    @ignore_timeout_error = options[:ignore_timeout_error]
  end

  def perform(&block)
    raise WithoutBlock unless block
    return yield unless switched_on?

    self.id = take_my_turn
    before.call(id) if valid_callback? before

    result = yield
    return result unless present? id

    self.locked = leave_my_turn(id)
    after.call(locked) if valid_callback? after
    result
  end

  private

  def switched_on?
    switch
  end

  def take_my_turn
    timeout = self.timeout
    response = Timeout.timeout(timeout.to_f) do
      request "#{current_url}/#{@queue_name}?seconds=#{lock_seconds}"
    rescue Timeout::Error
      return false if ignore_timeout_error

      raise TimeoutError, timeout
    end
    read_response(response, :id)
  end

  def current_url
    @current_url ||= build_url
  end

  def build_url
    current_url = url
    raise InvalidUrl, current_url unless current_url =~ URI::DEFAULT_PARSER.make_regexp

    current_url
  end

  def request(url, method: :get)
    uri = URI(url)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = url.start_with? 'https'

    request = method == :delete ? Net::HTTP::Delete.new(uri) : Net::HTTP::Get.new(uri)
    current_headers.each { |key, value| request[key] = value } if current_headers.is_a?(Hash)
    https.request(request)
  end

  def current_headers
    @current_headers ||= headers
  end

  def leave_my_turn(id)
    response = request "#{current_url}/#{@queue_name}/#{id}", method: :delete
    read_response(response, :locked)
  end

  def read_response(response, key)
    hash = JSON.parse response.body
    hash[key.to_s]
  end

  def valid_callback?(callback)
    callback.is_a?(Proc) || callback.is_a?(Method)
  end

  def present?(value)
    if value.nil?
      false
    elsif value.is_a?(Numeric) || value.length.positive?
      true
    else
      false
    end
  rescue StandardError
    false
  end
end
