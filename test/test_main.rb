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

require "functions_framework"

describe FunctionsFramework do
  let(:retry_count) { 10 }
  let(:retry_interval) { 0.5 }
  let(:port) { "8066" }
  let(:timeout) { 10 }

  def run_with_retry target
    server = FunctionsFramework.start target do |config|
      config.port = port
      config.show_error_details = true
    end
    begin
      last_error = nil
      retry_count.times do
        begin
          return yield
        rescue ::SystemCallError => e
          last_error = e
          sleep retry_interval
        end
      end
      raise last_error
    ensure
      server.stop.wait_until_stopped timeout: timeout
    end
  end

  before do
    @saved_registry = FunctionsFramework.global_registry
    FunctionsFramework.global_registry = FunctionsFramework::Registry.new
  end

  after do
    FunctionsFramework.global_registry = @saved_registry
  end

  it "defines and runs an http function" do
    FunctionsFramework.http "return_http" do |request|
      "I received a #{request.request_method} request: #{request.url}"
    end
    response = nil
    capture_subprocess_io do
      response = run_with_retry "return_http" do
        Net::HTTP.get_response URI("http://127.0.0.1:#{port}/")
      end
    end
    assert_equal "200", response.code
    assert_equal "I received a GET request: http://127.0.0.1:#{port}/", response.body
  end

  it "defines and runs a startup task and a http function" do
    FunctionsFramework.on_startup do
      set_global :foo, :bar
    end
    FunctionsFramework.http "return_http" do
      "foo is #{global(:foo).inspect}"
    end
    response = nil
    capture_subprocess_io do
      response = run_with_retry "return_http" do
        Net::HTTP.get_response URI("http://127.0.0.1:#{port}/")
      end
    end
    assert_equal "200", response.code
    assert_equal "foo is :bar", response.body
  end

  it "freezes globals in a function" do
    FunctionsFramework.http "return_http" do |request|
      set_global :foo, :bar
      "I received a #{request.request_method} request: #{request.url}"
    end
    response = nil
    capture_subprocess_io do
      response = run_with_retry "return_http" do
        Net::HTTP.get_response URI("http://127.0.0.1:#{port}/")
      end
    end
    assert_equal "500", response.code
    assert_match(/FrozenError: can't modify frozen Hash/, response.body)
  end
end
