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

require "functions_framework/testing"

describe FunctionsFramework::Testing do
  let(:registry) { FunctionsFramework::Registry.new }
  let(:simple_http_path) { File.join __dir__, "function_definitions", "simple_http.rb" }
  let(:simple_event_path) { File.join __dir__, "function_definitions", "simple_event.rb" }

  describe "#make_get_request" do
    it "creates a basic request" do
      request = FunctionsFramework::Testing.make_get_request "http://example.com/"
      assert_instance_of Rack::Request, request
      assert request.get?
      assert_equal "http://example.com/", request.url
    end

    it "creates a request with headers" do
      headers = ["X-Hello-World: Hello Ruby"]
      request = FunctionsFramework::Testing.make_get_request "http://example.com/", headers
      assert_instance_of Rack::Request, request
      assert request.get?
      assert_equal "http://example.com/", request.url
      assert_equal "Hello Ruby", request.get_header("HTTP_X_HELLO_WORLD")
    end
  end

  describe "#make_post_request" do
    it "creates a basic request" do
      request = FunctionsFramework::Testing.make_post_request "http://example.com/", "The Body"
      assert_instance_of Rack::Request, request
      assert request.post?
      assert_equal "http://example.com/", request.url
      assert_equal "The Body", request.body.read
    end

    it "creates a request with headers" do
      headers = ["X-Hello-World: Hello Ruby"]
      request = FunctionsFramework::Testing.make_post_request "http://example.com/",
                                                              "The Body", headers
      assert_instance_of Rack::Request, request
      assert request.post?
      assert_equal "http://example.com/", request.url
      assert_equal "The Body", request.body.read
      assert_equal "Hello Ruby", request.get_header("HTTP_X_HELLO_WORLD")
    end
  end

  describe "#make_cloud_event" do
    it "creates a default event" do
      event = FunctionsFramework::Testing.make_cloud_event "Lorem Ipsum"
      assert_instance_of FunctionsFramework::CloudEvents::Event, event
      assert_equal "Lorem Ipsum", event.data
      assert_match %r{^random-id}, event.id
      assert_equal "com.example.test", event.type
      assert_equal "1.0", event.spec_version
      assert_nil event.data_content_type
      assert_nil event.data_schema
      assert_nil event.subject
      assert_nil event.time
    end

    it "creates an event with arguments" do
      cur_time = ::DateTime.now
      event = FunctionsFramework::Testing.make_cloud_event \
        "Lorem Ipsum",
        id: "id-123",
        source: "my-source",
        type: "my-type",
        spec_version: "2.0",
        data_content_type: "Text/Plain",
        data_schema: "my-schema",
        subject: "my-subject",
        time: cur_time
      assert_instance_of FunctionsFramework::CloudEvents::Event, event
      assert_equal "Lorem Ipsum", event.data
      assert_equal "id-123", event.id
      assert_equal URI("my-source"), event.source
      assert_equal "my-type", event.type
      assert_equal "2.0", event.spec_version
      assert_equal "text/plain", event.data_content_type.canonical_string
      assert_equal URI("my-schema"), event.data_schema
      assert_equal "my-subject", event.subject
      assert_equal cur_time, event.time
    end
  end

  describe "#load_temporary" do
    it "loads a definition file and caches it" do
      registry = nil
      FunctionsFramework::Testing.load_temporary simple_http_path do
        registry = FunctionsFramework.global_registry
        assert_equal ["simple-http"], registry.names
      end
      FunctionsFramework::Testing.load_temporary simple_http_path do
        assert_same registry, FunctionsFramework.global_registry
      end
    end
  end

  describe "#call_http" do
    it "calls an http function" do
      FunctionsFramework::Testing.load_temporary simple_http_path do
        request = FunctionsFramework::Testing.make_get_request "http://example.com/"
        response = nil
        capture_subprocess_io do
          response = FunctionsFramework::Testing.call_http "simple-http", request
        end
        assert_equal "I received a request: GET http://example.com/", response.body.join
      end
    end
  end

  describe "#call_event" do
    it "calls an event function" do
      FunctionsFramework::Testing.load_temporary simple_event_path do
        event = FunctionsFramework::Testing.make_cloud_event "Hello, world!", type: "event-type"
        _out, err = capture_subprocess_io do
          FunctionsFramework::Testing.call_event "simple-event", event
        end
        assert_match(/I received "Hello, world!" in an event of type event-type/, err)
      end
    end
  end
end
