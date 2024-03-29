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
  let(:simple_typed_path) { File.join __dir__, "function_definitions", "simple_typed.rb" }
  let(:return_http_path) { File.join __dir__, "function_definitions", "return_http.rb" }
  let(:startup_block_path) { File.join __dir__, "function_definitions", "startup_block.rb" }

  describe "#make_request" do
    it "creates a PUT request" do
      request = FunctionsFramework::Testing.make_request "http://example.com/", method: "PUT", body: "The Body"
      assert_instance_of Rack::Request, request
      assert request.put?
      assert_equal "http://example.com/", request.url
      assert_equal "The Body", request.body.read
    end

    it "creates a GET request by default" do
      request = FunctionsFramework::Testing.make_request "http://example.com/"
      assert_instance_of Rack::Request, request
      assert request.get?
      assert_equal "http://example.com/", request.url
    end

    it "handles string headers" do
      headers = ["X-Hello-World: Hello Ruby", "X-Another-Language: Elixir"]
      request = FunctionsFramework::Testing.make_request "http://example.com/", headers: headers
      assert_instance_of Rack::Request, request
      assert_equal "Hello Ruby", request.get_header("HTTP_X_HELLO_WORLD")
      assert_equal "Elixir", request.get_header("HTTP_X_ANOTHER_LANGUAGE")
    end

    it "handles hash headers" do
      headers = { "X-Hello-World" => "Hello Ruby", "X-Another-Language" => "Elixir" }
      request = FunctionsFramework::Testing.make_request "http://example.com/", headers: headers
      assert_instance_of Rack::Request, request
      assert_equal "Hello Ruby", request.get_header("HTTP_X_HELLO_WORLD")
      assert_equal "Elixir", request.get_header("HTTP_X_ANOTHER_LANGUAGE")
    end

    it "handles mixed array headers" do
      headers = [["X-Hello-World", "Hello Ruby"], "X-Another-Language: Elixir"]
      request = FunctionsFramework::Testing.make_request "http://example.com/", headers: headers
      assert_instance_of Rack::Request, request
      assert_equal "Hello Ruby", request.get_header("HTTP_X_HELLO_WORLD")
      assert_equal "Elixir", request.get_header("HTTP_X_ANOTHER_LANGUAGE")
    end
  end

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
      assert_kind_of ::CloudEvents::Event, event
      assert_equal "Lorem Ipsum", event.data
      assert_match(/^random-id/, event.id)
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
        id:                "id-123",
        source:            "my-source",
        type:              "my-type",
        spec_version:      "1.1",
        data_content_type: "Text/Plain",
        data_schema:       "my-schema",
        subject:           "my-subject",
        time:              cur_time
      assert_kind_of ::CloudEvents::Event, event
      assert_equal "Lorem Ipsum", event.data
      assert_equal "id-123", event.id
      assert_equal URI("my-source"), event.source
      assert_equal "my-type", event.type
      assert_equal "1.1", event.spec_version
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
        assert_equal ["simple_http"], registry.names
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
        _out, err = capture_subprocess_io do
          response = FunctionsFramework::Testing.call_http "simple_http", request
        end
        assert_match %r{I received a request: GET http://example.com/}, err
        assert_equal "I received a request: GET http://example.com/", response.body.join
      end
    end

    it "calls an http function that has a return" do
      FunctionsFramework::Testing.load_temporary return_http_path do
        request = FunctionsFramework::Testing.make_get_request "http://example.com/"
        response = nil
        capture_subprocess_io do
          response = FunctionsFramework::Testing.call_http "return_http", request
        end
        assert_equal "I received a GET request: http://example.com/", response.body.join
      end
    end

    it "overrides logging" do
      FunctionsFramework::Testing.load_temporary simple_http_path do
        request = FunctionsFramework::Testing.make_get_request "http://example.com/"
        response = nil
        _out, err = capture_subprocess_io do
          response = FunctionsFramework::Testing.call_http "simple_http", request, logger: Logger.new(nil)
        end
        assert_empty err
        assert_equal "I received a request: GET http://example.com/", response.body.join
      end
    end

    it "automatically runs startup tasks" do
      FunctionsFramework::Testing.load_temporary startup_block_path do
        request = FunctionsFramework::Testing.make_get_request "http://example.com/"
        response = nil
        _out, err = capture_subprocess_io do
          response = FunctionsFramework::Testing.call_http "simple_http", request
        end
        assert_match(/in startup block/, err)
        assert_equal "OK", response.body.join
      end
    end

    it "can disable automatic run of startup tasks" do
      FunctionsFramework::Testing.load_temporary startup_block_path do
        request = FunctionsFramework::Testing.make_get_request "http://example.com/"
        response = nil
        _out, err = capture_subprocess_io do
          response = FunctionsFramework::Testing.call_http "simple_http", request, globals: { my_name: "simple_http" }
        end
        assert_empty err
        assert_equal "OK", response.body.join
      end
    end
  end

  describe "#call_event" do
    it "calls an event function" do
      FunctionsFramework::Testing.load_temporary simple_event_path do
        event = FunctionsFramework::Testing.make_cloud_event "Hello, world!", type: "event-type"
        _out, err = capture_subprocess_io do
          FunctionsFramework::Testing.call_event "simple_event", event
        end
        assert_match(/I received "Hello, world!" in an event of type event-type/, err)
      end
    end

    it "overrides logging" do
      FunctionsFramework::Testing.load_temporary simple_event_path do
        event = FunctionsFramework::Testing.make_cloud_event "Hello, world!", type: "event-type"
        _out, err = capture_subprocess_io do
          FunctionsFramework::Testing.call_event "simple_event", event, logger: Logger.new(nil)
        end
        assert_empty err
      end
    end
  end

  describe "#call_typed" do
    it "calls a typed function" do
      FunctionsFramework::Testing.load_temporary simple_typed_path do
        request = FunctionsFramework::Testing.make_post_request "http://example.com/", "{\"value\": 1}"
        response = nil
        _out, err = capture_subprocess_io do
          response = FunctionsFramework::Testing.call_typed "simple_typed", request
        end

        assert_match %r{FunctionsFramework: Handling Typed POST request}, err
        assert_match %r{I received a request: 1}, err
        assert_equal "{\"value\":2}", response.body.join
      end
    end
  end

  describe "#run_startup_tasks" do
    it "runs startup tasks" do
      FunctionsFramework::Testing.load_temporary startup_block_path do
        _out, err = capture_subprocess_io do
          FunctionsFramework::Testing.run_startup_tasks "simple_http"
        end
        assert_match(/in startup block/, err)
        request = FunctionsFramework::Testing.make_get_request "http://example.com/"
        response = FunctionsFramework::Testing.call_http "simple_http", request
        assert_equal "OK", response.body.join
      end
    end

    it "runs automatically" do
      FunctionsFramework::Testing.load_temporary startup_block_path do
        request = FunctionsFramework::Testing.make_get_request "http://example.com/"
        response = nil
        _out, err = capture_subprocess_io do
          response = FunctionsFramework::Testing.call_http "simple_http", request
        end
        assert_match(/in startup block/, err)
        assert_equal "OK", response.body.join
      end
    end

    it "refuses to run repeatedly" do
      FunctionsFramework::Testing.load_temporary startup_block_path do
        request = FunctionsFramework::Testing.make_get_request "http://example.com/"
        capture_subprocess_io do
          FunctionsFramework::Testing.call_http "simple_http", request
        end
        assert_raises "Function simple_http has already started up" do
          FunctionsFramework::Testing.run_startup_tasks "simple_http"
        end
      end
    end

    it "overrides logging" do
      FunctionsFramework::Testing.load_temporary startup_block_path do
        _out, err = capture_subprocess_io do
          FunctionsFramework::Testing.run_startup_tasks "simple_http", logger: Logger.new(nil)
        end
        assert_empty err
      end
    end
  end
end
