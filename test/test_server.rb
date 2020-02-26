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
  let(:function) {
    FunctionsFramework::Function.new "my-func", :http do |request|
      "Received: #{request.body&.read.inspect}"
    end
  }
  let(:port) { 8077 }
  let(:server_url) { "http://127.0.0.1:#{port}" }
  let(:quiet_logger) {
    logger = ::Logger.new ::STDOUT
    logger.level = ::Logger::ERROR
    logger
  }
  let(:server) {
    FunctionsFramework::Server.new function do |config|
      config.min_threads = 1
      config.max_threads = 1
      config.port = port
      config.bind_addr = "127.0.0.1"
      config.rack_env = "development"
      config.logger = quiet_logger
    end
  }
  let(:retry_count) { 10 }
  let(:retry_interval) { 0.5 }

  def query_server_with_retry
    begin
      server.start
      last_error = nil
      retry_count.times do
        begin
          return yield
        rescue ::SystemCallError => e
          last_error = e
        end
      end
      raise last_error
    ensure
      server.stop.wait_until_stopped timeout: 10
    end
  end

  it "supports configuration in a constructor block" do
    server = FunctionsFramework::Server.new function do |config|
      config.rack_env = "my-env"
    end
    assert_equal "my-env", server.config.rack_env
  end

  it "starts and stops" do
    begin
      refute server.running?
      server.start
      assert server.running?
      server.stop.wait_until_stopped timeout: 10
      refute server.running?
    ensure
      server.stop.wait_until_stopped timeout: 10
    end
  end

  it "handles post requests" do
    response = query_server_with_retry do
      ::Net::HTTP.post URI(server_url), "Hello, world!", {"Content-Type" => "text/plain"}
    end
    assert_equal "200", response.code
    assert_equal "Received: \"Hello, world!\"", response.body
  end

  it "handles get requests" do
    response = query_server_with_retry do
      ::Net::HTTP.get_response URI(server_url)
    end
    assert_equal "200", response.code
    assert_equal "Received: \"\"", response.body
  end

  it "refuses favicon requests" do
    response = query_server_with_retry do
      ::Net::HTTP.get_response URI("#{server_url}/favicon.ico")
    end
    assert_equal "404", response.code
    assert_equal "Not found", response.body
  end

  it "refuses robots requests" do
    response = query_server_with_retry do
      ::Net::HTTP.get_response URI("#{server_url}/robots.txt")
    end
    assert_equal "404", response.code
    assert_equal "Not found", response.body
  end

  describe "::Config" do

  end
end
