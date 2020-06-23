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

require "minitest/autorun"

require "functions_framework/testing"

describe "sinatra-based function" do
  include FunctionsFramework::Testing

  it "responds to the root path" do
    load_temporary "app.rb" do
      request = make_get_request "http://example.com:8080/"
      response = nil
      capture_subprocess_io do
        response = call_http "sinatra_example", request
      end
      assert_equal 200, response.status
      assert_equal "Sinatra received a request!", response.body.join
    end
  end

  it "responds to a hello path" do
    load_temporary "app.rb" do
      request = make_get_request "http://example.com:8080/hello/Sinatra"
      response = nil
      capture_subprocess_io do
        response = call_http "sinatra_example", request
      end
      assert_equal 200, response.status
      assert_equal "Hello, Sinatra!", response.body.join
    end
  end

  it "responds with a 400 using the ShowStatus middleware" do
    load_temporary "app.rb" do
      request = make_get_request "http://example.com:8080/four-hundred"
      response = nil
      capture_subprocess_io do
        response = call_http "sinatra_example", request
      end
      assert_equal 400, response.status
      assert_match(/Bad Request/, response.body.join)
    end
  end
end
