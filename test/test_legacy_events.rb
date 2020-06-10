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

describe FunctionsFramework::LegacyEvents do
  let(:data_dir) { File.join __dir__, "legacy_events_data" }

  def load_legacy_event filename
    path = File.join data_dir, filename
    File.open path do |io|
      env = { "rack.input" => io, "CONTENT_TYPE" => "application/json" }
      FunctionsFramework::LegacyEvents.decode_rack_env env
    end
  end

  it "converts legacy_pubsub.json" do
    event = load_legacy_event "legacy_pubsub.json"
    assert_equal "1.0", event.spec_version
    assert_equal "//pubsub.googleapis.com/projects/sample-project/topics/gcf-test", event.source_string
    assert_equal "google.cloud.pubsub.topic.v1.publish", event.type
    assert_equal "2020-05-18T12:13:19+00:00", event.time.rfc3339
    assert_equal "value1", event.data["attributes"]["attribute1"]
  end

  it "converts legacy_storage_change.json" do
    event = load_legacy_event "legacy_storage_change.json"
    assert_equal "1.0", event.spec_version
    assert_equal "//storage.googleapis.com/projects/_/buckets/sample-bucket/objects/MyFile#1588778055917163",
                 event.source_string
    assert_equal "google.cloud.storage.object.v1.change", event.type
    assert_equal "2020-05-18T09:07:51+00:00", event.time.rfc3339
    assert_equal "sample-bucket", event.data["bucket"]
  end

  it "converts pubsub_text.json" do
    event = load_legacy_event "pubsub_text.json"
    assert_equal "1.0", event.spec_version
    assert_equal "//pubsub.googleapis.com/projects/sample-project/topics/gcf-test", event.source_string
    assert_equal "google.cloud.pubsub.topic.v1.publish", event.type
    assert_equal "2020-05-06T07:33:34+00:00", event.time.rfc3339
    assert_equal "attr1-value", event.data["attributes"]["attr1"]
  end

  it "converts pubsub_binary.json" do
    event = load_legacy_event "pubsub_binary.json"
    assert_equal "1.0", event.spec_version
    assert_equal "//pubsub.googleapis.com/projects/sample-project/topics/gcf-test", event.source_string
    assert_equal "google.cloud.pubsub.topic.v1.publish", event.type
    assert_equal "2020-05-06T07:33:34+00:00", event.time.rfc3339
    assert_equal "AQIDBA==", event.data["data"]
  end

  it "converts storage.json" do
    event = load_legacy_event "storage.json"
    assert_equal "1.0", event.spec_version
    assert_equal "//storage.googleapis.com/projects/_/buckets/some-bucket/objects/Test.cs", event.source_string
    assert_equal "google.cloud.storage.object.v1.finalize", event.type
    assert_equal "2020-04-23T07:38:57+00:00", event.time.rfc3339
    assert_equal "some-bucket", event.data["bucket"]
  end

  it "converts firestore_simple.json" do
    event = load_legacy_event "firestore_simple.json"
    assert_equal "1.0", event.spec_version
    assert_equal \
      "//firestore.googleapis.com/projects/project-id/databases/(default)/documents/gcf-test/2Vm2mI1d0wIaK2Waj5to",
      event.source_string
    assert_equal "google.cloud.firestore.document.v1.write", event.type
    assert_equal "2020-04-23T12:00:27+00:00", event.time.rfc3339
    assert_equal "bar", event.data["value"]["fields"]["foo"]["stringValue"]
  end
end
