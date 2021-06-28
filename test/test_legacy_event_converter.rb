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
require "json"
require "stringio"

describe FunctionsFramework::LegacyEventConverter do
  let(:data_dir) { File.join __dir__, "legacy_events_data" }

  def load_legacy_event filename_or_json, url_path: nil, encoding: "utf-8"
    converter = FunctionsFramework::LegacyEventConverter.new
    case filename_or_json
    when String
      path = File.join data_dir, filename_or_json
      File.open path, encoding: encoding do |io|
        env = { "rack.input" => io, "CONTENT_TYPE" => "application/json", "PATH_INFO" => url_path }
        converter.decode_rack_env env
      end
    when Hash
      io = StringIO.new JSON.dump filename_or_json
      env = { "rack.input" => io, "CONTENT_TYPE" => "application/json", "PATH_INFO" => url_path }
      converter.decode_rack_env env
    else
      raise ArgumentError, filename_or_json.class.name
    end
  end

  it "converts legacy_pubsub.json" do
    event = load_legacy_event "legacy_pubsub.json"
    assert_equal "1.0", event.spec_version
    assert_equal "1215011316659232", event.id
    assert_equal "//pubsub.googleapis.com/projects/sample-project/topics/gcf-test", event.source.to_s
    assert_equal "google.cloud.pubsub.topic.v1.messagePublished", event.type
    assert_nil event.subject
    assert_equal "2020-05-18T12:13:19+00:00", event.time.rfc3339
    assert_equal "value1", event.data["message"]["attributes"]["attribute1"]
    assert_equal "VGhpcyBpcyBhIHNhbXBsZSBtZXNzYWdl", event.data["message"]["data"]
    assert_equal "1215011316659232", event.data["message"]["messageId"]
    assert_equal "2020-05-18T12:13:19.209Z", event.data["message"]["publishTime"]
    assert_nil event.data["subscription"]
  end

  it "converts legacy_storage_change.json" do
    event = load_legacy_event "legacy_storage_change.json"
    assert_equal "1.0", event.spec_version
    assert_equal "1200401551653202", event.id
    assert_equal "//storage.googleapis.com/projects/_/buckets/sample-bucket", event.source.to_s
    assert_equal "google.cloud.storage.object.v1.finalized", event.type
    assert_equal "objects/MyFile", event.subject
    assert_equal "2020-05-18T09:07:51+00:00", event.time.rfc3339
    assert_equal "sample-bucket", event.data["bucket"]
  end

  it "converts pubsub_text.json" do
    event = load_legacy_event "pubsub_text.json"
    assert_equal "1.0", event.spec_version
    assert_equal "1144231683168617", event.id
    assert_equal "//pubsub.googleapis.com/projects/sample-project/topics/gcf-test", event.source.to_s
    assert_equal "google.cloud.pubsub.topic.v1.messagePublished", event.type
    assert_nil event.subject
    assert_equal "2020-05-06T07:33:34+00:00", event.time.rfc3339
    assert_equal "attr1-value", event.data["message"]["attributes"]["attr1"]
    assert_equal "dGVzdCBtZXNzYWdlIDM=", event.data["message"]["data"]
    assert_equal "1144231683168617", event.data["message"]["messageId"]
    assert_equal "2020-05-06T07:33:34.556Z", event.data["message"]["publishTime"]
  end

  it "converts pubsub_utf8.json" do
    event = load_legacy_event "pubsub_utf8.json", encoding: "ASCII-8BIT"
    assert_equal "1.0", event.spec_version
    assert_equal "1144231683168617", event.id
    assert_equal "//pubsub.googleapis.com/projects/sample-project/topics/gcf-test", event.source.to_s
    assert_equal "google.cloud.pubsub.topic.v1.messagePublished", event.type
    assert_nil event.subject
    assert_equal "2020-05-06T07:33:34+00:00", event.time.rfc3339
    assert_equal "あああ", event.data["message"]["attributes"]["attr1"]
    assert_equal "dGVzdCBtZXNzYWdlIDM=", event.data["message"]["data"]
    assert_equal "1144231683168617", event.data["message"]["messageId"]
    assert_equal "2020-05-06T07:33:34.556Z", event.data["message"]["publishTime"]
  end

  it "converts pubsub_binary.json" do
    event = load_legacy_event "pubsub_binary.json"
    assert_equal "1.0", event.spec_version
    assert_equal "1144231683168617", event.id
    assert_equal "//pubsub.googleapis.com/projects/sample-project/topics/gcf-test", event.source.to_s
    assert_equal "google.cloud.pubsub.topic.v1.messagePublished", event.type
    assert_nil event.subject
    assert_equal "2020-05-06T07:33:34+00:00", event.time.rfc3339
    assert_equal "AQIDBA==", event.data["message"]["data"]
    assert_equal "1144231683168617", event.data["message"]["messageId"]
    assert_equal "2020-05-06T07:33:34.556Z", event.data["message"]["publishTime"]
  end

  it "converts raw_pubsub.json" do
    event = load_legacy_event "raw_pubsub.json"
    assert_equal "1.0", event.spec_version
    assert_equal "1215011316659232", event.id
    assert_equal "//pubsub.googleapis.com/UNKNOWN_PUBSUB_TOPIC", event.source.to_s
    assert_equal "google.cloud.pubsub.topic.v1.messagePublished", event.type
    assert_nil event.subject
    assert_in_delta event.time.to_time.to_f, Time.now.to_f, 1.0
    assert_equal "123", event.data["message"]["attributes"]["test"]
    assert_equal "eyJmb28iOiJiYXIifQ==", event.data["message"]["data"]
    assert_equal "1215011316659232", event.data["message"]["messageId"]
    timestamp = event.time.to_time.utc.strftime "%Y-%m-%dT%H:%M:%S.%6NZ"
    assert_equal timestamp, event.data["message"]["publishTime"]
  end

  it "converts raw_pubsub.json with path" do
    event = load_legacy_event "raw_pubsub.json", url_path: "/projects/sample-project/topics/gcf-test"
    assert_equal "1.0", event.spec_version
    assert_equal "1215011316659232", event.id
    assert_equal "//pubsub.googleapis.com/projects/sample-project/topics/gcf-test", event.source.to_s
    assert_equal "google.cloud.pubsub.topic.v1.messagePublished", event.type
    assert_nil event.subject
    assert_in_delta event.time.to_time.to_f, Time.now.to_f, 1.0
    assert_equal "123", event.data["message"]["attributes"]["test"]
    assert_equal "eyJmb28iOiJiYXIifQ==", event.data["message"]["data"]
    assert_equal "1215011316659232", event.data["message"]["messageId"]
    timestamp = event.time.to_time.utc.strftime "%Y-%m-%dT%H:%M:%S.%6NZ"
    assert_equal timestamp, event.data["message"]["publishTime"]
  end

  it "converts storage.json" do
    event = load_legacy_event "storage.json"
    assert_equal "1.0", event.spec_version
    assert_equal "1147091835525187", event.id
    assert_equal "//storage.googleapis.com/projects/_/buckets/some-bucket", event.source.to_s
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
      "//firestore.googleapis.com/projects/project-id/databases/(default)",
      event.source.to_s
    assert_equal "google.cloud.firestore.document.v1.written", event.type
    assert_equal "documents/gcf-test/2Vm2mI1d0wIaK2Waj5to", event.subject
    assert_equal "2020-04-23T12:00:27+00:00", event.time.rfc3339
    assert_equal "bar", event.data["value"]["fields"]["foo"]["stringValue"]
  end

  it "converts firestore_complex.json" do
    event = load_legacy_event "firestore_complex.json"
    assert_equal "1.0", event.spec_version
    assert_equal "9babded5-e5f2-41af-a46a-06ba6bd84739-0", event.id
    assert_equal \
      "//firestore.googleapis.com/projects/project-id/databases/(default)",
      event.source.to_s
    assert_equal "google.cloud.firestore.document.v1.written", event.type
    assert_equal "documents/gcf-test/IH75dRdeYJKd4uuQiqch", event.subject
    assert_equal "2020-04-23T14:25:05+00:00", event.time.rfc3339
    assert_equal "50", event.data["value"]["fields"]["intValue"]["integerValue"]
  end

  it "converts firebase-auth1.json" do
    event = load_legacy_event "firebase-auth1.json"
    assert_equal "1.0", event.spec_version
    assert_equal "4423b4fa-c39b-4f79-b338-977a018e9b55", event.id
    assert_equal "//firebaseauth.googleapis.com/projects/my-project-id", event.source.to_s
    assert_equal "google.firebase.auth.user.v1.created", event.type
    assert_equal "users/UUpby3s4spZre6kHsgVSPetzQ8l2", event.subject
    assert_equal "2020-05-26T10:42:27+00:00", event.time.rfc3339
    assert_equal "test@nowhere.com", event.data["email"]
  end

  it "converts firebase-auth2.json" do
    event = load_legacy_event "firebase-auth2.json"
    assert_equal "1.0", event.spec_version
    assert_equal "5fd71bdc-4955-421f-9fc3-552ac3abead8", event.id
    assert_equal "//firebaseauth.googleapis.com/projects/my-project-id", event.source.to_s
    assert_equal "google.firebase.auth.user.v1.deleted", event.type
    assert_equal "users/UUpby3s4spZre6kHsgVSPetzQ8l2", event.subject
    assert_equal "2020-05-26T10:47:14+00:00", event.time.rfc3339
    assert_equal "test@nowhere.com", event.data["email"]
  end

  it "converts firebase-db1.json" do
    event = load_legacy_event "firebase-db1.json"
    assert_equal "1.0", event.spec_version
    assert_equal "/SnHth9OSlzK1Puj85kk4tDbF90=", event.id
    assert_equal \
      "//firebasedatabase.googleapis.com/projects/_/locations/us-central1/instances/my-project-id",
      event.source.to_s
    assert_equal "google.firebase.database.document.v1.written", event.type
    assert_equal "refs/gcf-test/xyz", event.subject
    assert_equal "2020-05-21T11:15:34+00:00", event.time.rfc3339
    assert_equal "other", event.data["delta"]["grandchild"]
  end

  it "converts firebase-dbdelete1.json" do
    event = load_legacy_event "firebase-dbdelete1.json"
    assert_equal "1.0", event.spec_version
    assert_equal "oIcVXHEMZfhQMNs/yD4nwpuKE0s=", event.id
    assert_equal \
      "//firebasedatabase.googleapis.com/projects/_/locations/europe-west1/instances/my-project-id",
      event.source.to_s
    assert_equal "google.firebase.database.document.v1.deleted", event.type
    assert_equal "refs/gcf-test/xyz", event.subject
    assert_equal "2020-05-21T11:53:45+00:00", event.time.rfc3339
  end

  it "converts firebase-dbdelete2.json" do
    event = load_legacy_event "firebase-dbdelete2.json"
    assert_equal "1.0", event.spec_version
    assert_equal "KVLKeFKjFP2jepddr+EPGC0ZQ20=", event.id
    assert_equal \
      "//firebasedatabase.googleapis.com/projects/_/locations/us-central1/instances/my-project-id",
      event.source.to_s
    assert_equal "google.firebase.database.document.v1.deleted", event.type
    assert_equal "refs/gcf-test/abc", event.subject
    assert_equal "2020-05-21T11:56:12+00:00", event.time.rfc3339
  end

  it "declines to convert firebasedatabase without a domain" do
    json = {
      "eventType" => "providers/google.firebase.database/eventTypes/ref.write",
      "params" => {
        "child" => "xyz"
      },
      "auth" => {
        "admin" => true
      },
      "data" => {
        "data" => nil,
        "delta" => {
          "grandchild" => "other"
        }
      },
      "resource" => "projects/_/instances/my-project-id/refs/gcf-test/xyz",
      "timestamp" => "2020-05-21T11:15:34.178Z",
      "eventId" => "/SnHth9OSlzK1Puj85kk4tDbF90="
    }
    assert_nil load_legacy_event json
  end
end
