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

describe FunctionsFramework::CloudEvents::Event::V0 do
  let(:my_id) { "my_id" }
  let(:my_source_string) { "/my_source" }
  let(:my_source) { URI.parse my_source_string }
  let(:my_source2_string) { "/my_source2" }
  let(:my_source2) { URI.parse my_source2_string }
  let(:my_type) { "my_type" }
  let(:my_type2) { "my_type2" }
  let(:spec_version) { "0.3" }
  let(:my_simple_data) { "12345" }
  let(:my_content_encoding) { "base64" }
  let(:my_content_type_string) { "text/plain; charset=us-ascii" }
  let(:my_content_type) { FunctionsFramework::CloudEvents::ContentType.new my_content_type_string }
  let(:my_schema_string) { "/my_schema" }
  let(:my_schema) { URI.parse my_schema_string }
  let(:my_subject) { "my_subject" }
  let(:my_time_string) { "2020-01-12T20:52:05-08:00" }
  let(:my_date_time) { DateTime.rfc3339 my_time_string }
  let(:my_time) { my_date_time.to_time }

  it "handles string inputs" do
    event = FunctionsFramework::CloudEvents::Event::V0.new \
      id: my_id,
      source: my_source_string,
      type: my_type,
      spec_version: spec_version,
      data: my_simple_data,
      data_content_encoding: my_content_encoding,
      data_content_type: my_content_type_string,
      schema_url: my_schema_string,
      subject: my_subject,
      time: my_time_string
    assert_equal my_id, event.id
    assert_equal my_source, event.source
    assert_equal my_type, event.type
    assert_equal spec_version, event.spec_version
    assert_equal my_simple_data, event.data
    assert_equal my_content_encoding, event.data_content_encoding
    assert_equal my_content_type, event.data_content_type
    assert_equal my_schema, event.schema_url
    assert_equal my_subject, event.subject
    assert_equal my_date_time, event.time
    assert_equal my_id, event[:id]
    assert_equal my_source_string, event[:source]
    assert_equal my_type, event[:type]
    assert_equal spec_version, event[:specversion]
    assert_nil event[:spec_version]
    assert_equal my_simple_data, event[:data]
    assert_equal my_content_encoding, event[:datacontentencoding]
    assert_nil event[:data_content_encoding]
    assert_equal my_content_type_string, event[:datacontenttype]
    assert_nil event[:data_content_type]
    assert_equal my_schema_string, event[:schemaurl]
    assert_nil event[:schema_url]
    assert_equal my_subject, event[:subject]
    assert_equal my_time_string, event[:time]
  end

  it "handles object inputs" do
    event = FunctionsFramework::CloudEvents::Event::V0.new \
      id: my_id,
      source: my_source,
      type: my_type,
      spec_version: spec_version,
      data: my_simple_data,
      data_content_type: my_content_type,
      schema_url: my_schema,
      subject: my_subject,
      time: my_date_time
    assert_equal my_id, event.id
    assert_equal my_source, event.source
    assert_equal my_type, event.type
    assert_equal spec_version, event.spec_version
    assert_equal my_simple_data, event.data
    assert_equal my_content_type, event.data_content_type
    assert_equal my_schema, event.schema_url
    assert_equal my_subject, event.subject
    assert_equal my_date_time, event.time
    assert_equal my_id, event[:id]
    assert_equal my_source_string, event[:source]
    assert_equal my_type, event[:type]
    assert_equal spec_version, event[:specversion]
    assert_nil event[:spec_version]
    assert_equal my_simple_data, event[:data]
    assert_equal my_content_type_string, event[:datacontenttype]
    assert_nil event[:data_content_type]
    assert_equal my_schema_string, event[:schemaurl]
    assert_nil event[:schema_url]
    assert_equal my_subject, event[:subject]
    assert_equal my_time_string, event[:time]
  end

  it "handles more object inputs" do
    event = FunctionsFramework::CloudEvents::Event::V0.new \
      id: my_id,
      source: my_source,
      type: my_type,
      spec_version: spec_version,
      data: my_simple_data,
      time: my_time
    assert_equal my_id, event.id
    assert_equal my_source, event.source
    assert_equal my_type, event.type
    assert_equal spec_version, event.spec_version
    assert_equal my_simple_data, event.data
    assert_equal my_date_time, event.time
  end

  it "sets defaults when optional inputs are omitted" do
    event = FunctionsFramework::CloudEvents::Event::V0.new \
      id: my_id,
      source: my_source,
      type: my_type,
      spec_version: spec_version
    assert_equal my_id, event.id
    assert_equal my_source, event.source
    assert_equal my_type, event.type
    assert_equal spec_version, event.spec_version
    assert_nil event.data
    assert_nil event.data_content_encoding
    assert_nil event.data_content_type
    assert_nil event.schema_url
    assert_nil event.subject
    assert_nil event.time
    assert_equal my_id, event[:id]
    assert_equal my_source_string, event[:source]
    assert_equal my_type, event[:type]
    assert_equal spec_version, event[:specversion]
    assert_nil event[:spec_version]
    assert_nil event[:data]
    assert_nil event[:datacontentencoding]
    assert_nil event[:data_content_encoding]
    assert_nil event[:datacontenttype]
    assert_nil event[:data_content_type]
    assert_nil event[:schemaurl]
    assert_nil event[:schema_url]
    assert_nil event[:subject]
    assert_nil event[:time]
  end

  it "creates a modified copy" do
    event = FunctionsFramework::CloudEvents::Event::V0.new \
      id: my_id,
      source: my_source_string,
      type: my_type,
      spec_version: spec_version,
      data: my_simple_data,
      data_content_encoding: my_content_encoding,
      data_content_type: my_content_type_string,
      schema_url: my_schema_string,
      subject: my_subject,
      time: my_time_string
    event2 = event.with type: my_type2, source: my_source2
    assert_equal my_id, event2.id
    assert_equal my_source2, event2.source
    assert_equal my_type2, event2.type
    assert_equal my_schema, event2.schema_url
  end

  it "requires specversion" do
    error = assert_raises FunctionsFramework::CloudEvents::AttributeError do
      FunctionsFramework::CloudEvents::Event::V0.new \
        id: my_id,
        source: my_source,
        type: my_type
    end
    assert_equal "The specversion field is required", error.message
  end

  it "errors when the wrong specversion is given" do
    error = assert_raises FunctionsFramework::CloudEvents::SpecVersionError do
      FunctionsFramework::CloudEvents::Event::V0.new \
        id: my_id,
        source: my_source,
        type: my_type,
        spec_version: "1.0"
    end
    assert_equal "Unrecognized specversion: 1.0", error.message
  end

  it "requires id" do
    error = assert_raises FunctionsFramework::CloudEvents::AttributeError do
      FunctionsFramework::CloudEvents::Event::V0.new \
        source: my_source,
        type: my_type,
        spec_version: spec_version
      end
    assert_equal "The id field is required", error.message
  end

  it "requires source" do
    error = assert_raises FunctionsFramework::CloudEvents::AttributeError do
      FunctionsFramework::CloudEvents::Event::V0.new \
        id: my_id,
        type: my_type,
        spec_version: spec_version
      end
    assert_equal "The source field is required", error.message
  end

  it "requires type" do
    error = assert_raises FunctionsFramework::CloudEvents::AttributeError do
      FunctionsFramework::CloudEvents::Event::V0.new \
        id: my_id,
        source: my_source,
        spec_version: spec_version
      end
    assert_equal "The type field is required", error.message
  end
end
