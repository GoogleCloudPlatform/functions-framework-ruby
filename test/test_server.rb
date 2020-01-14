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
  let(:server) {
    FunctionsFramework::Server.new function do |config|
      config.min_threads = 1
      config.max_threads = 1
      config.port = port
      config.bind_addr = "127.0.0.1"
      config.rack_env = "development"
    end
  }
  let(:retry_count) { 10 }
  let(:retry_interval) { 0.5 }

  it "supports configuration in a constructor block" do
    server = FunctionsFramework::Server.new function do |config|
      config.rack_env = "my-env"
    end
    assert_equal "my-env", server.config.rack_env
  end

  it "starts and stops" do
    refute server.running?
    server.start
    assert server.running?
    server.stop.wait_until_stopped timeout: 10
    refute server.running?
  ensure
    server.stop.wait_until_stopped timeout: 10
  end

  it "handles requests" do
    server.start
    success = false
    retry_count.times do
      response = ::Net::HTTP.post \
        URI("http://127.0.0.1:#{port}"), "Hello, world!", {"Content-Type" => "text/plain"}
      if response.code == "200"
        success = true
        assert_equal "Received: \"Hello, world!\"", response.body
        break
      end
      sleep retry_interval
    end
    assert success, "Failed to connect to the server"
  ensure
    server.stop.wait_until_stopped timeout: 10
  end

  describe "::Config" do

  end
end
