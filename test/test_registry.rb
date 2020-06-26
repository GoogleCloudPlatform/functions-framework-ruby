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
require "ostruct"

describe FunctionsFramework::Registry do
  let(:registry) { FunctionsFramework::Registry.new }

  it "starts out empty" do
    assert_empty registry.names
    assert_nil registry["my-func"]
  end

  it "defines an http function" do
    tester = self
    registry.add_http "my-func" do |request|
      tester.assert_equal "the-request", request
      "hello"
    end
    assert_equal ["my-func"], registry.names
    function = registry["my-func"]
    assert_equal "my-func", function.name
    assert_equal :http, function.type
    response = function.call "the-request"
    assert_equal "hello", response
  end

  it "defines an event function" do
    tester = self
    registry.add_event "my-func" do |data, context|
      tester.assert_equal "the-data", data
      tester.assert_equal "the-id", context.id
      "ok"
    end
    assert_equal ["my-func"], registry.names
    function = registry["my-func"]
    assert_equal "my-func", function.name
    assert_equal :event, function.type
    event = OpenStruct.new data: "the-data", id: "the-id"
    function.call event
  end

  it "defines a cloud_event function" do
    tester = self
    registry.add_cloud_event "my-func" do |event|
      tester.assert_equal "the-event", event
      "ok"
    end
    assert_equal ["my-func"], registry.names
    function = registry["my-func"]
    assert_equal "my-func", function.name
    assert_equal :cloud_event, function.type
    function.call "the-event"
  end

  it "defines multiple functions" do
    registry.add_http "func2" do |request|
      "hello"
    end
    registry.add_event "func1" do |data, context|
      "ok"
    end
    assert_equal ["func1", "func2"], registry.names
    assert_equal :event, registry["func1"].type
    assert_equal :http, registry["func2"].type
  end
end
