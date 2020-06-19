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

describe FunctionsFramework::LegacyEventConverter do
  let(:data_dir) { File.join __dir__, "legacy_events_data" }

  def load_legacy_event filename
    path = File.join data_dir, filename
    File.open path do |io|
      env = { "rack.input" => io, "CONTENT_TYPE" => "application/json" }
      converter = FunctionsFramework::LegacyEventConverter.new
      converter.decode_rack_env env
    end
  end

  it "converts legacy_pubsub.json" do
    event = load_legacy_event "legacy_pubsub.json"
    assert_equal "1.0", event.spec_version
    assert_equal "1215011316659232", event.id
    assert_equal "//pubsub.googleapis.com/projects/sample-project/topics/gcf-test", event.source_string
    assert_equal "google.cloud.pubsub.topic.v1.messagePublished", event.type
    assert_nil event.subject
    assert_equal "2020-05-18T12:13:19+00:00", event.time.rfc3339
    assert_equal "value1", event.data["attributes"]["attribute1"]
  end

  it "converts legacy_storage_change.json" do
    event = load_legacy_event "legacy_storage_change.json"
    assert_equal "1.0", event.spec_version
    assert_equal "1200401551653202", event.id
    assert_equal "//storage.googleapis.com/projects/_/buckets/sample-bucket", event.source_string
    assert_equal "google.cloud.storage.object.v1.finalized", event.type
    assert_equal "objects/MyFile", event.subject
    assert_equal "2020-05-18T09:07:51+00:00", event.time.rfc3339
    assert_equal "sample-bucket", event.data["bucket"]
  end

  it "converts pubsub_text.json" do
    event = load_legacy_event "pubsub_text.json"
    assert_equal "1.0", event.spec_version
    assert_equal "1144231683168617", event.id
    assert_equal "//pubsub.googleapis.com/projects/sample-project/topics/gcf-test", event.source_string
    assert_equal "google.cloud.pubsub.topic.v1.messagePublished", event.type
    assert_nil event.subject
    assert_equal "2020-05-06T07:33:34+00:00", event.time.rfc3339
    assert_equal "attr1-value", event.data["attributes"]["attr1"]
  end

  it "converts pubsub_binary.json" do
    event = load_legacy_event "pubsub_binary.json"
    assert_equal "1.0", event.spec_version
    assert_equal "1144231683168617", event.id
    assert_equal "//pubsub.googleapis.com/projects/sample-project/topics/gcf-test", event.source_string
    assert_equal "google.cloud.pubsub.topic.v1.messagePublished", event.type
    assert_nil event.subject
    assert_equal "2020-05-06T07:33:34+00:00", event.time.rfc3339
    assert_equal "AQIDBA==", event.data["data"]
  end

  it "converts storage.json" do
    event = load_legacy_event "storage.json"
    assert_equal "1.0", event.spec_version
    assert_equal "1147091835525187", event.id
    assert_equal "//storage.googleapis.com/projects/_/buckets/some-bucket", event.source_string
    assert_equal "google.cloud.storage.object.v1.finalized", event.type
    assert_equal "objects/Test.cs", event.subject
    assert_equal "2020-04-23T07:38:57+00:00", event.time.rfc3339
    assert_equal "some-bucket", event.data["bucket"]
  end

  it "converts firestore_simple.json" do
    event = load_legacy_event "firestore_simple.json"
    assert_equal "1.0", event.spec_version
    assert_equal "7b8f1804-d38b-4b68-b37d-e2fb5d12d5a0-0", event.id
    assert_equal \
      "//firestore.googleapis.com/projects/project-id/databases/(default)/documents/gcf-test/2Vm2mI1d0wIaK2Waj5to",
      event.source_string
    assert_equal "google.cloud.firestore.document.v1.written", event.type
    assert_nil event.subject
    assert_equal "2020-04-23T12:00:27+00:00", event.time.rfc3339
    assert_equal "bar", event.data["value"]["fields"]["foo"]["stringValue"]
  end

  it "converts firestore_complex.json" do
    event = load_legacy_event "firestore_complex.json"
    assert_equal "1.0", event.spec_version
    assert_equal "9babded5-e5f2-41af-a46a-06ba6bd84739-0", event.id
    assert_equal \
      "//firestore.googleapis.com/projects/project-id/databases/(default)/documents/gcf-test/IH75dRdeYJKd4uuQiqch",
      event.source_string
    assert_equal "google.cloud.firestore.document.v1.written", event.type
    assert_nil event.subject
    assert_equal "2020-04-23T14:25:05+00:00", event.time.rfc3339
    assert_equal "50", event.data["value"]["fields"]["intValue"]["integerValue"]
  end

  it "converts firebase-auth1.json" do
    event = load_legacy_event "firebase-auth1.json"
    assert_equal "1.0", event.spec_version
    assert_equal "4423b4fa-c39b-4f79-b338-977a018e9b55", event.id
    assert_equal "//firebase.googleapis.com/projects/my-project-id", event.source_string
    assert_equal "google.firebase.auth.user.v1.created", event.type
    assert_nil event.subject
    assert_equal "2020-05-26T10:42:27+00:00", event.time.rfc3339
    assert_equal "test@nowhere.com", event.data["email"]
  end

  it "converts firebase-auth2.json" do
    event = load_legacy_event "firebase-auth2.json"
    assert_equal "1.0", event.spec_version
    assert_equal "5fd71bdc-4955-421f-9fc3-552ac3abead8", event.id
    assert_equal "//firebase.googleapis.com/projects/my-project-id", event.source_string
    assert_equal "google.firebase.auth.user.v1.deleted", event.type
    assert_nil event.subject
    assert_equal "2020-05-26T10:47:14+00:00", event.time.rfc3339
    assert_equal "test@nowhere.com", event.data["email"]
  end

  it "converts firebase-db1.json" do
    event = load_legacy_event "firebase-db1.json"
    assert_equal "1.0", event.spec_version
    assert_equal "/SnHth9OSlzK1Puj85kk4tDbF90=", event.id
    assert_equal "//firebase.googleapis.com/projects/_/instances/my-project-id/refs/gcf-test/xyz", event.source_string
    assert_equal "google.firebase.database.document.v1.written", event.type
    assert_nil event.subject
    assert_equal "2020-05-21T11:15:34+00:00", event.time.rfc3339
    assert_equal "other", event.data["delta"]["grandchild"]
  end
end
