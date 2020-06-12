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

describe FunctionsFramework::CloudEvents do
  let(:my_id) { "my_id" }
  let(:my_source_string) { "/my_source" }
  let(:my_source) { URI.parse my_source_string }
  let(:my_type) { "my_type" }
  let(:spec_version) { "1.0" }
  let(:my_json_data) { {"a" => 12345, "b" => "hello", "c" => [true, false, nil] } }
  let(:my_data_string) { "12345" }
  let(:my_content_type_string) { "text/plain; charset=us-ascii" }
  let(:my_content_type) { FunctionsFramework::CloudEvents::ContentType.new my_content_type_string }
  let(:my_schema_string) { "/my_schema" }
  let(:my_schema) { URI.parse my_schema_string }
  let(:my_subject) { "my_subject" }
  let(:my_time_string) { "2020-01-12T20:52:05-08:00" }
  let(:my_time) { DateTime.rfc3339 my_time_string }
  let(:my_json_struct) {
    {
      "id" => my_id,
      "source" => my_source_string,
      "type" => my_type,
      "specversion" => spec_version,
      "data" => my_json_data,
      "datacontenttype" => my_content_type_string,
      "dataschema" => my_schema_string,
      "subject" => my_subject,
      "time" => my_time_string
    }
  }
  let(:my_json_struct_encoded) { JSON.dump my_json_struct }

  it "decodes a structured rack env" do
    env = {
      "rack.input" => StringIO.new(my_json_struct_encoded),
      "CONTENT_TYPE" => "application/cloudevents+json"
    }
    events = FunctionsFramework::CloudEvents.decode_rack_env env
    event = events[0]
    assert_equal my_id, event.id
    assert_equal my_source, event.source
    assert_equal my_type, event.type
    assert_equal spec_version, event.spec_version
    assert_equal my_json_data, event.data
    assert_equal my_content_type, event.data_content_type
    assert_equal my_schema, event.data_schema
    assert_equal my_subject, event.subject
    assert_equal my_time, event.time
  end

  it "decodes a binary rack env" do
    env = {
      "rack.input" => StringIO.new(my_data_string),
      "HTTP_CE_ID" => my_id,
      "HTTP_CE_SOURCE" => my_source_string,
      "HTTP_CE_TYPE" => my_type,
      "HTTP_CE_SPECVERSION" => spec_version,
      "CONTENT_TYPE" => my_content_type_string,
      "HTTP_CE_DATASCHEMA" => my_schema_string,
      "HTTP_CE_SUBJECT" => my_subject,
      "HTTP_CE_TIME" => my_time_string
    }
    event = FunctionsFramework::CloudEvents.decode_rack_env env
    assert_equal my_id, event.id
    assert_equal my_source, event.source
    assert_equal my_type, event.type
    assert_equal spec_version, event.spec_version
    assert_equal my_data_string, event.data
    assert_equal my_content_type, event.data_content_type
    assert_equal my_schema, event.data_schema
    assert_equal my_subject, event.subject
    assert_equal my_time, event.time
  end
end
