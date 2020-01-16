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
require "stringio"

describe FunctionsFramework::CloudEvents::JsonStructure do
  let(:my_id) { "my_id" }
  let(:my_source_string) { "/my_source" }
  let(:my_source) { URI.parse my_source_string }
  let(:my_type) { "my_type" }
  let(:spec_version) { "1.0" }
  let(:my_json_data) { {"a" => 12345, "b" => "hello", "c" => [true, false, nil] } }
  let(:my_data_string) { "12345" }
  let(:my_base64_data) { Base64.encode64(my_data_string) }
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
  let(:my_base64_struct) {
    {
      "id" => my_id,
      "source" => my_source_string,
      "type" => my_type,
      "specversion" => spec_version,
      "data_base64" => my_base64_data,
      "datacontenttype" => my_content_type_string,
      "dataschema" => my_schema_string,
      "subject" => my_subject,
      "time" => my_time_string
    }
  }
  let(:my_json_struct_io) { StringIO.new(JSON.dump(my_json_struct)) }
  let(:my_batch_io) { StringIO.new(JSON.dump([my_base64_struct, my_json_struct])) }
  let(:structured_content_type_string) { "application/cloudevents+json" }
  let(:structured_content_type) { FunctionsFramework::CloudEvents::ContentType.new structured_content_type_string }
  let(:batched_content_type_string) { "application/cloudevents-batch+json" }
  let(:batched_content_type) { FunctionsFramework::CloudEvents::ContentType.new batched_content_type_string }

  it "decodes a struct with base64 data" do
    event = FunctionsFramework::CloudEvents::JsonStructure.decode_hash_structure my_base64_struct
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

  it "decodes a struct with json data" do
    event = FunctionsFramework::CloudEvents::JsonStructure.decode_hash_structure my_json_struct
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

  it "decodes json-encoded content" do
    event = FunctionsFramework::CloudEvents::JsonStructure.decode_structured_content \
      my_json_struct_io, structured_content_type
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

  it "decodes json-encoded batch" do
    events = FunctionsFramework::CloudEvents::JsonStructure.decode_batched_content \
      my_batch_io, batched_content_type
    assert_equal 2, events.size
    event = events[0]
    assert_equal my_id, event.id
    assert_equal my_source, event.source
    assert_equal my_type, event.type
    assert_equal spec_version, event.spec_version
    assert_equal my_data_string, event.data
    assert_equal my_content_type, event.data_content_type
    assert_equal my_schema, event.data_schema
    assert_equal my_subject, event.subject
    assert_equal my_time, event.time
    event = events[1]
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
end
