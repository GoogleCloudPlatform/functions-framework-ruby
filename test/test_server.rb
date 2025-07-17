# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "helper"

require "net/http"
require "uri"

require "functions_framework/server"

describe FunctionsFramework::Server do
  let(:http_function) {
    FunctionsFramework::Function.new "my-func", :http do |request|
      "Received: #{request.body&.read.inspect}"
    end
  }
  let(:typed_function) {
    FunctionsFramework::Function.new "my-func", :typed do |event|
      return {
        value: event["value"] + 1
      }
    end
  }
  let(:event_function) {
    FunctionsFramework::Function.new "my-func", :cloud_event do |event|
      FunctionsFramework.logger.unknown "Received: #{event.data.inspect}"
    end
  }
  let(:port) { 8077 }
  let(:pidfile) { "server.pid" }
  let(:server_url) { "http://127.0.0.1:#{port}" }
  let(:quiet_logger) {
    logger = ::Logger.new $stderr
    logger.level = ::Logger::FATAL
    logger
  }
  let(:http_server) { make_basic_server http_function }
  let(:typed_server) { make_basic_server typed_function }
  let(:event_server) { make_basic_server event_function }
  let(:retry_count) { 10 }
  let(:retry_interval) { 0.5 }
  let(:app_context) { {} }

  def make_basic_server function, show_error_details: true
    FunctionsFramework::Server.new function, app_context do |config|
      config.min_threads = 1
      config.max_threads = 1
      config.port = port
      config.pidfile = pidfile
      config.bind_addr = "127.0.0.1"
      config.rack_env = "development"
      config.logger = quiet_logger
      config.show_error_details = show_error_details
    end
  end

  def query_server_with_retry server
    server.start
    last_error = nil
    retry_count.times do
      return yield
    rescue ::SystemCallError => e
      last_error = e
      sleep retry_interval
    end
    raise last_error
  ensure
    server.stop.wait_until_stopped timeout: 10
  end

  it "supports configuration in a constructor block" do
    server = FunctionsFramework::Server.new http_function, app_context do |config|
      config.rack_env = "my-env"
    end
    assert_equal "my-env", server.config.rack_env
  end

  it "starts and stops" do
    refute http_server.running?
    http_server.start
    assert http_server.running?
    http_server.stop.wait_until_stopped timeout: 10
    refute http_server.running?
  ensure
    http_server.stop.wait_until_stopped timeout: 10
  end

  it "uses a pidfile" do
    refute http_server.pidfile?
    refute http_server.pidfile
    http_server.start
    assert http_server.pidfile?
    assert http_server.pidfile
    http_server.stop.wait_until_stopped timeout: 10
    refute http_server.running?
    refute http_server.pidfile?
  ensure
    http_server.stop.wait_until_stopped timeout: 10
  end

  it "handles post requests" do
    response = query_server_with_retry http_server do
      ::Net::HTTP.post URI("#{server_url}/"), "Hello, world!", "Content-Type" => "text/plain"
    end
    assert_equal "200", response.code
    assert_equal "Received: \"Hello, world!\"", response.body
    assert_equal "text/plain; charset=utf-8", response["Content-Type"]
  end

  it "handles get requests" do
    response = query_server_with_retry http_server do
      ::Net::HTTP.get_response URI("#{server_url}/")
    end
    assert_equal "200", response.code
    assert_equal "Received: \"\"", response.body
    assert_equal "text/plain; charset=utf-8", response["Content-Type"]
  end

  it "interprets binary string" do
    function = FunctionsFramework::Function.new "my-func", :http do |_request|
      "\xff".force_encoding Encoding::ASCII_8BIT
    end
    server = make_basic_server function
    response = query_server_with_retry server do
      ::Net::HTTP.get_response URI("#{server_url}/")
    end
    assert_equal "200", response.code
    assert_equal "\xff".force_encoding(Encoding::ASCII_8BIT), response.body
    assert_equal "application/octet-stream", response["Content-Type"]
  end

  it "interprets invalid encoding string" do
    function = FunctionsFramework::Function.new "my-func", :http do |_request|
      "\xff"
    end
    server = make_basic_server function
    response = query_server_with_retry server do
      ::Net::HTTP.get_response URI("#{server_url}/")
    end
    assert_equal "200", response.code
    assert_equal "\xff".force_encoding(Encoding::ASCII_8BIT), response.body
    assert_equal "application/octet-stream", response["Content-Type"]
  end

  it "interprets array responses" do
    function = FunctionsFramework::Function.new "my-func", :http do |_request|
      ["200", { "Content-Type" => "text/plain" }, ["Hello, ", "Array!"]]
    end
    server = make_basic_server function
    response = query_server_with_retry server do
      ::Net::HTTP.get_response URI("#{server_url}/")
    end
    assert_equal "200", response.code
    assert_equal "Hello, Array!", response.body
    assert_equal "text/plain", response["Content-Type"]
  end

  it "interprets hash responses" do
    function = FunctionsFramework::Function.new "my-func", :http do |_request|
      { foo: "bar" }
    end
    server = make_basic_server function
    response = query_server_with_retry server do
      ::Net::HTTP.get_response URI("#{server_url}/")
    end
    assert_equal "200", response.code
    assert_equal '{"foo":"bar"}', response.body
    assert_equal "application/json; charset=utf-8", response["Content-Type"]
  end

  it "handles typed functions" do
    server = make_basic_server typed_function

    response = query_server_with_retry server do
      ::Net::HTTP.post(URI("#{server_url}/"), "{\"value\":1}", {
                         "Content-Type" => "application/json"
                       })
    end

    assert_equal "200", response.code
    assert_equal "{\"value\":2}", response.body
    assert_equal "application/json; charset=utf-8", response["Content-Type"]
  end

  it "handles typed function parse error" do
    server = make_basic_server typed_function

    response = query_server_with_retry server do
      ::Net::HTTP.post(URI("#{server_url}/"), "not json", {
                         "Content-Type" => "application/json"
                       })
    end

    assert_equal "400", response.code
    assert_match /unexpected token/, response.body
    assert_equal "text/plain; charset=utf-8", response["Content-Type"]
  end

  it "handles typed function execution error" do
    server = make_basic_server typed_function

    response = query_server_with_retry server do
      ::Net::HTTP.post(URI("#{server_url}/"), "{\"value\": \"nan\"}", {
                         "Content-Type" => "application/json"
                       })
    end

    assert_equal "500", response.code
  end

  it "handles typed function empty response" do
    func = FunctionsFramework::Function.new "my-func", :typed do |_req|
      nil
    end
    server = make_basic_server func

    response = query_server_with_retry server do
      ::Net::HTTP.post(URI("#{server_url}/"), "{}", {
                         "Content-Type" => "application/json"
                       })
    end

    assert_equal "204", response.code
    assert_nil response.body
  end

  it "handles CloudEvents" do
    response = nil
    _out, err = capture_subprocess_io do
      response = query_server_with_retry event_server do
        event_structure = {
          specversion: "1.0",
          id:          "123",
          source:      "my-source",
          type:        "my-type",
          data:        "Hello, world!"
        }
        event_json = JSON.dump event_structure
        ::Net::HTTP.post URI("#{server_url}/"), event_json, "Content-Type" => "application/cloudevents+json"
      end
    end
    refute_nil response
    assert_equal "200", response.code
    assert_equal "ok", response.body
    assert_equal "text/plain; charset=utf-8", response["Content-Type"]
    assert_match(/Received: "Hello, world!"/, err)
  end

  it "errors on batch CloudEvents" do
    response = query_server_with_retry event_server do
      event1_structure = {
        specversion: "1.0",
        id:          "123",
        source:      "my-source",
        type:        "my-type",
        data:        "Hello, world!"
      }
      event2_structure = {
        specversion: "1.0",
        id:          "456",
        source:      "my-source",
        type:        "my-type",
        data:        "Goodbye, world!"
      }
      event_json = JSON.dump [event1_structure, event2_structure]
      ::Net::HTTP.post URI("#{server_url}/"), event_json, "Content-Type" => "application/cloudevents-batch+json"
    end
    refute_nil response
    assert_equal "400", response.code
    assert_match(/Batched CloudEvents are not supported/, response.body)
    assert_equal "text/plain; charset=utf-8", response["Content-Type"]
  end

  it "handles legacy events" do
    response = nil
    _out, err = capture_subprocess_io do
      response = query_server_with_retry event_server do
        file_path = File.join __dir__, "legacy_events_data", "legacy_pubsub.json"
        event_json = File.read file_path
        ::Net::HTTP.post URI("#{server_url}/"), event_json, "Content-Type" => "application/json"
      end
    end
    refute_nil response
    assert_equal "200", response.code
    assert_equal "ok", response.body
    assert_equal "text/plain; charset=utf-8", response["Content-Type"]
    assert_match(/VGhpcyBpcyBhIHNhbXBsZSBtZXNzYWdl/, err)
  end

  it "handles events with UTF8 content" do
    response = nil
    _out, err = capture_subprocess_io do
      response = query_server_with_retry event_server do
        file_path = File.join __dir__, "legacy_events_data", "pubsub_utf8.json"
        event_json = File.read file_path
        ::Net::HTTP.post URI("#{server_url}/"), event_json, "Content-Type" => "application/json; charset=utf-8"
      end
    end
    refute_nil response
    assert_equal "200", response.code
    assert_equal "ok", response.body
    assert_equal "text/plain; charset=utf-8", response["Content-Type"]
    assert_match(/あああ/, err)
  end

  it "interprets exceptions showing error details" do
    function = FunctionsFramework::Function.new "my-func", :http do |_request|
      raise "Whoops!"
    end
    server = make_basic_server function
    response = query_server_with_retry server do
      ::Net::HTTP.get_response URI("#{server_url}/")
    end
    assert_equal "500", response.code
    assert_match(/RuntimeError: Whoops!\n\t#{__FILE__}/, response.body)
    assert_match %r{test/test_server\.rb:}, response.body
    assert_equal "text/plain; charset=utf-8", response["Content-Type"]
  end

  it "interprets exceptions hiding error details" do
    function = FunctionsFramework::Function.new "my-func", :http do |_request|
      raise "Whoops!"
    end
    server = make_basic_server function, show_error_details: false
    response = query_server_with_retry server do
      ::Net::HTTP.get_response URI("#{server_url}/")
    end
    assert_equal "500", response.code
    refute_match(/Whoops/, response.body)
    assert_equal "Unexpected internal error", response.body
    assert_equal "text/plain; charset=utf-8", response["Content-Type"]
  end

  it "refuses favicon requests" do
    response = query_server_with_retry http_server do
      ::Net::HTTP.get_response URI("#{server_url}/favicon.ico")
    end
    assert_equal "404", response.code
    assert_equal "Not found", response.body
    assert_equal "text/plain; charset=utf-8", response["Content-Type"]
  end

  it "refuses robots requests" do
    response = query_server_with_retry http_server do
      ::Net::HTTP.get_response URI("#{server_url}/robots.txt")
    end
    assert_equal "404", response.code
    assert_equal "Not found", response.body
    assert_equal "text/plain; charset=utf-8", response["Content-Type"]
  end

  it "reports badly formed CloudEvents" do
    response = query_server_with_retry event_server do
      ::Net::HTTP.post URI("#{server_url}/"), '{"specversion":"hello"}',
                       "Content-Type" => "application/cloudevents+json"
    end
    refute_nil response
    assert_equal "400", response.code
    assert_match(/Unrecognized specversion/, response.body)
    assert_equal "text/plain; charset=utf-8", response["Content-Type"]
  end

  it "reports unknown event types" do
    response = query_server_with_retry event_server do
      ::Net::HTTP.post URI("#{server_url}/"), '{"data":"Hello, world!"}',
                       "Content-Type" => "application/json"
    end
    refute_nil response
    assert_equal "400", response.code
    assert_match(/Unrecognized event format/, response.body)
    assert_equal "text/plain; charset=utf-8", response["Content-Type"]
  end

  it "returns no content when an event server receives a get" do
    response = query_server_with_retry event_server do
      ::Net::HTTP.get_response URI("#{server_url}/")
    end
    refute_nil response
    assert_equal "204", response.code
    assert_nil response.body
  end
end
