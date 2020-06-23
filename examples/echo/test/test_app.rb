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

describe "http_sample function" do
  include FunctionsFramework::Testing

  it "generates the correct response body" do
    load_temporary "app.rb" do
      request = make_get_request "http://example.com:8080/"
      response = nil
      _out, err = capture_subprocess_io do
        response = call_http "http_sample", request
      end
      assert_equal 200, response.status
      assert_equal "I received a request: GET http://example.com:8080/", response.body.join
      assert_match %r{I received a request: GET http:\/\/example\.com:8080}, err
    end
  end
end

describe "event_sample function" do
  include FunctionsFramework::Testing

  it "outputs the expected log" do
    load_temporary "app.rb" do
      event = make_cloud_event "Hello, world!"
      _out, err = capture_subprocess_io do
        call_event "event_sample", event
      end
      assert_match %r{I received "Hello, world!" in an event of type com\.example\.test}, err
    end
  end
end
