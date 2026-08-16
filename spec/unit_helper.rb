# frozen_string_literal: true

require "rspec"
require "solidus_nshift"

module ContractFixtureHelpers
  def fixture_json(path)
    JSON.parse(File.binread(File.expand_path("fixtures/nshift/#{path}", __dir__)))
  end

  def fixture_body(path)
    File.binread(File.expand_path("fixtures/nshift/#{path}", __dir__))
  end
end

class RecordedTransport
  Response = SolidusNshift::Http::NetHttpTransport::Response

  attr_reader :requests

  def initialize(*responses, &block)
    @responses = responses.flatten
    @block = block
    @requests = []
    @mutex = Mutex.new
  end

  def call(**request)
    response = @mutex.synchronize do
      @requests << request
      @block ? @block.call(request, @requests.length) : @responses.shift
    end
    raise "No fake response configured" unless response
    raise response if response.is_a?(Exception)

    response
  end

  def self.json(status, value, headers: {})
    Response.new(status:, body: JSON.generate(value), headers:)
  end

  def self.binary(status, body, content_type: "application/octet-stream")
    Response.new(status:, body: body.b, headers: {"content-type" => [content_type]})
  end
end

RSpec.configure do |config|
  config.include ContractFixtureHelpers
  config.order = :random
  Kernel.srand config.seed
end
