# frozen_string_literal: true

require "unit_helper"

module NetHttpTransportSpec
  FakeResponse = Struct.new(:code, :chunks, :headers) do
    def read_body
      chunks.each { |chunk| yield chunk }
    end

    def to_hash
      headers
    end
  end

  FakeConnection = Struct.new(:response, :requests) do
    def request(request)
      requests << request
      yield response
    end
  end
end

RSpec.describe SolidusNshift::Http::NetHttpTransport do
  it "streams an HTTPS response into the normalized response object" do
    response = NetHttpTransportSpec::FakeResponse.new("201", ["one", "two"], {"x-request-id" => ["request-1"]})
    connection = NetHttpTransportSpec::FakeConnection.new(response, [])
    transport = described_class.new
    allow(transport).to receive(:connection).and_return(connection)

    result = transport.call(method: :post, url: "https://api.example.test/resource?full=true", body: "payload")

    expect(result).to have_attributes(status: 201, body: "onetwo")
    expect(connection.requests.first).to be_a(Net::HTTP::Post)
    expect(connection.requests.first.path).to eq("/resource?full=true")
    expect(connection.requests.first.body).to eq("payload")
  end

  it "aborts streaming as soon as the response limit is exceeded" do
    response = NetHttpTransportSpec::FakeResponse.new("200", ["123", "456", "789"], {})
    connection = NetHttpTransportSpec::FakeConnection.new(response, [])
    transport = described_class.new(max_response_bytes: 5)
    allow(transport).to receive(:connection).and_return(connection)

    expect { transport.call(method: :get, url: "https://api.example.test/resource") }
      .to raise_error(SolidusNshift::MalformedResponseError, /exceeded 5 bytes/)
  end

  it "rejects unsafe endpoints, invalid limits, and unsupported methods before connecting" do
    transport = described_class.new

    expect { transport.call(method: :get, url: "http://api.example.test/resource") }
      .to raise_error(SolidusNshift::ConfigurationError)
    expect { transport.call(method: :patch, url: "https://api.example.test/resource") }
      .to raise_error(ArgumentError, /unsupported HTTP method/)
    expect { transport.call(method: :get, url: "https://user:secret@api.example.test/resource") }
      .to raise_error(SolidusNshift::ConfigurationError)
    expect { described_class.new(max_response_bytes: 0) }
      .to raise_error(SolidusNshift::ConfigurationError, /positive/)
  end
end
