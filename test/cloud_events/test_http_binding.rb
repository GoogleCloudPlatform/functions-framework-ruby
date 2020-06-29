# encoding: UTF-8

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

describe FunctionsFramework::CloudEvents::HttpBinding do
  let(:http_binding) { FunctionsFramework::CloudEvents::HttpBinding.default }
  let(:my_id) { "my_id" }
  let(:my_source_string) { "/my_source" }
  let(:my_source) { URI.parse my_source_string }
  let(:my_type) { "my_type" }
  let(:weird_type) { "¡Hola!\n100% 😀 " }
  let(:encoded_weird_type) { "%C2%A1Hola!%0A100%25%20%F0%9F%98%80%20" }
  let(:spec_version) { "1.0" }
  let(:my_simple_data) { "12345" }
  let(:my_content_type_string) { "text/plain; charset=us-ascii" }
  let(:my_content_type) { FunctionsFramework::CloudEvents::ContentType.new my_content_type_string }
  let(:my_schema_string) { "/my_schema" }
  let(:my_schema) { URI.parse my_schema_string }
  let(:my_subject) { "my_subject" }
  let(:my_time_string) { "2020-01-12T20:52:05-08:00" }
  let(:my_time) { DateTime.rfc3339 my_time_string }
  let(:my_trace_context) { "1234567890;9876543210" }
  let(:my_json_struct) {
    {
      "data" => my_simple_data,
      "datacontenttype" => my_content_type_string,
      "dataschema" => my_schema_string,
      "id" => my_id,
      "source" => my_source_string,
      "specversion" => spec_version,
      "subject" => my_subject,
      "time" => my_time_string,
      "type" => my_type
    }
  }
  let(:my_json_struct_encoded) { JSON.dump my_json_struct }
  let(:my_json_batch_encoded) { JSON.dump [my_json_struct] }

  it "percent-encodes an ascii string" do
    str = http_binding.percent_encode my_simple_data
    assert_equal my_simple_data, str
  end

  it "percent-decodes an ascii string" do
    str = http_binding.percent_decode my_simple_data
    assert_equal my_simple_data, str
  end

  it "percent-encodes a string with special characters" do
    str = http_binding.percent_encode weird_type
    assert_equal encoded_weird_type, str
  end

  it "percent-decodes a string with special characters" do
    str = http_binding.percent_decode encoded_weird_type
    assert_equal weird_type, str
  end

  it "decodes a structured rack env and re-encodes as batch" do
    env = {
      "rack.input" => StringIO.new(my_json_struct_encoded),
      "CONTENT_TYPE" => "application/cloudevents+json"
    }
    event = http_binding.decode_rack_env env
    assert_equal my_id, event.id
    assert_equal my_source, event.source
    assert_equal my_type, event.type
    assert_equal spec_version, event.spec_version
    assert_equal my_simple_data, event.data
    assert_equal my_content_type, event.data_content_type
    assert_equal my_schema, event.data_schema
    assert_equal my_subject, event.subject
    assert_equal my_time, event.time
    headers, body = http_binding.encode_batched_content [event], "json", sort: true
    assert_equal({ "Content-Type" => "application/cloudevents-batch+json" }, headers)
    assert_equal my_json_batch_encoded, body
  end

  it "decodes a batch rack env and re-encodes as binary" do
    env = {
      "rack.input" => StringIO.new(my_json_batch_encoded),
      "CONTENT_TYPE" => "application/cloudevents-batch+json"
    }
    events = http_binding.decode_rack_env env
    assert_equal 1, events.size
    event = events.first
    assert_equal my_id, event.id
    assert_equal my_source, event.source
    assert_equal my_type, event.type
    assert_equal spec_version, event.spec_version
    assert_equal my_simple_data, event.data
    assert_equal my_content_type, event.data_content_type
    assert_equal my_schema, event.data_schema
    assert_equal my_subject, event.subject
    assert_equal my_time, event.time
    headers, body = http_binding.encode_binary_content event
    expected_headers = {
      "CE-id" => my_id,
      "CE-source" => my_source_string,
      "CE-type" => my_type,
      "CE-specversion" => spec_version,
      "Content-Type" => my_content_type_string,
      "CE-dataschema" => my_schema_string,
      "CE-subject" => my_subject,
      "CE-time" => my_time_string
    }
    assert_equal expected_headers, headers
    assert_equal my_simple_data, body
  end

  it "decodes a binary rack env and re-encodes as structured" do
    env = {
      "rack.input" => StringIO.new(my_simple_data),
      "HTTP_CE_ID" => my_id,
      "HTTP_CE_SOURCE" => my_source_string,
      "HTTP_CE_TYPE" => my_type,
      "HTTP_CE_SPECVERSION" => spec_version,
      "CONTENT_TYPE" => my_content_type_string,
      "HTTP_CE_DATASCHEMA" => my_schema_string,
      "HTTP_CE_SUBJECT" => my_subject,
      "HTTP_CE_TIME" => my_time_string
    }
    event = http_binding.decode_rack_env env
    assert_equal my_id, event.id
    assert_equal my_source, event.source
    assert_equal my_type, event.type
    assert_equal spec_version, event.spec_version
    assert_equal my_simple_data, event.data
    assert_equal my_content_type, event.data_content_type
    assert_equal my_schema, event.data_schema
    assert_equal my_subject, event.subject
    assert_equal my_time, event.time
    headers, body = http_binding.encode_structured_content event, "json", sort: true
    assert_equal({ "Content-Type" => "application/cloudevents+json" }, headers)
    assert_equal my_json_struct_encoded, body
  end

  it "decodes and re-encodes binary, honoring optional headers" do
    env = {
      "HTTP_CE_ID" => my_id,
      "HTTP_CE_SOURCE" => my_source_string,
      "HTTP_CE_TYPE" => my_type,
      "HTTP_CE_SPECVERSION" => spec_version
    }
    event = http_binding.decode_rack_env env
    assert_equal my_id, event.id
    assert_equal my_source, event.source
    assert_equal my_type, event.type
    assert_equal spec_version, event.spec_version
    assert_nil event.data
    assert_nil event.data_content_type
    assert_nil event.data_schema
    assert_nil event.subject
    assert_nil event.time
    headers, body = http_binding.encode_binary_content event
    expected_headers = {
      "CE-id" => my_id,
      "CE-source" => my_source_string,
      "CE-type" => my_type,
      "CE-specversion" => spec_version
    }
    assert_equal expected_headers, headers
    assert_nil body
  end

  it "decodes and re-encodes binary, passing through extension headers" do
    env = {
      "rack.input" => StringIO.new(my_simple_data),
      "CONTENT_TYPE" => my_content_type_string,
      "HTTP_CE_ID" => my_id,
      "HTTP_CE_SOURCE" => my_source_string,
      "HTTP_CE_TYPE" => my_type,
      "HTTP_CE_SPECVERSION" => spec_version,
      "HTTP_CE_TRACECONTEXT" => my_trace_context
    }
    event = http_binding.decode_rack_env env
    assert_equal my_trace_context, event["tracecontext"]
    headers, body = http_binding.encode_binary_content event
    expected_headers = {
      "CE-id" => my_id,
      "CE-source" => my_source_string,
      "CE-type" => my_type,
      "CE-specversion" => spec_version,
      "Content-Type" => my_content_type_string,
      "CE-tracecontext" => my_trace_context
    }
    assert_equal expected_headers, headers
    assert_equal my_simple_data, body
  end

  it "encodes and decodes binary, with non-ascii header characters" do
    event = FunctionsFramework::CloudEvents::Event.create \
      spec_version: spec_version,
      id: my_id,
      source: my_source,
      type: weird_type,
      data: my_simple_data,
      data_content_type: my_content_type_string
    headers, body = http_binding.encode_binary_content event
    expected_headers = {
      "CE-id" => my_id,
      "CE-source" => my_source_string,
      "CE-type" => encoded_weird_type,
      "CE-specversion" => spec_version,
      "Content-Type" => my_content_type_string
    }
    assert_equal expected_headers, headers
    assert_equal my_simple_data, body

    env = {
      "rack.input" => StringIO.new(body),
      "CONTENT_TYPE" => my_content_type_string,
      "HTTP_CE_ID" => my_id,
      "HTTP_CE_SOURCE" => my_source_string,
      "HTTP_CE_TYPE" => encoded_weird_type,
      "HTTP_CE_SPECVERSION" => spec_version
    }
    reconstituted_event = http_binding.decode_rack_env env
    assert_equal event, reconstituted_event
  end
end
