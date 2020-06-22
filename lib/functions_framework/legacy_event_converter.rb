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

require "json"

module FunctionsFramework
  ##
  # Converter from legacy GCF event formats to CloudEvents.
  #
  class LegacyEventConverter
    ##
    # Decode an event from the given Rack environment hash.
    #
    # @param env [Hash] The Rack environment
    # @return [FunctionsFramework::CloudEvents::Event] if the request could
    #     be converted
    # @return [nil] if the event format was not recognized.
    #
    def decode_rack_env env
      content_type = CloudEvents::ContentType.new env["CONTENT_TYPE"]
      return nil unless content_type.media_type == "application" && content_type.subtype_prefix == "json"
      input = read_input_json env["rack.input"], content_type.charset
      return nil unless input
      raw_context = input["context"] || input
      context = normalized_context raw_context
      return nil unless context
      construct_cloud_event context, input["data"]
    end

    private

    def read_input_json input, charset
      input = input.read if input.respond_to? :read
      input = input.encode charset if charset
      content = ::JSON.parse input
      content = nil unless content.is_a? ::Hash
      content
    rescue ::JSON::ParserError
      nil
    end

    def normalized_context raw_context
      id = raw_context["eventId"]
      return nil unless id
      timestamp = raw_context["timestamp"]
      return nil unless timestamp
      type = raw_context["eventType"]
      return nil unless type
      service, resource = analyze_resource raw_context["resource"], type
      return nil unless service && resource
      { id: id, timestamp: timestamp, type: type, service: service, resource: resource }
    end

    def analyze_resource raw_resource, type
      case raw_resource
      when ::Hash
        [raw_resource["service"], raw_resource["name"]]
      when ::String
        [service_from_type(type), raw_resource]
      else
        [nil, nil]
      end
    end

    def service_from_type type
      LEGACY_TYPE_TO_SERVICE.each do |pattern, service|
        return service if pattern =~ type
      end
      nil
    end

    def construct_cloud_event context, data
      source, subject = convert_source context[:service], context[:resource]
      type = LEGACY_TYPE_TO_CE_TYPE[context[:type]]
      return nil unless type && source
      CloudEvents::Event.new id:                context[:id],
                             source:            source,
                             type:              type,
                             spec_version:      "1.0",
                             data_content_type: "application/json",
                             data:              data,
                             subject:           subject,
                             time:              context[:timestamp]
    end

    def convert_source service, resource
      if service == "storage.googleapis.com"
        match = %r{^(projects/[^/]+/buckets/[^/]+)/([^#]+)(?:#.*)?$}.match resource
        return [nil, nil] unless match
        ["//#{service}/#{match[1]}", match[2]]
      else
        ["//#{service}/#{resource}", nil]
      end
    end

    LEGACY_TYPE_TO_SERVICE = {
      %r{^providers/cloud\.firestore/} => "firestore.googleapis.com",
      %r{^providers/cloud\.pubsub/}    => "pubsub.googleapis.com",
      %r{^providers/cloud\.storage/}   => "storage.googleapis.com",
      %r{^providers/firebase\.auth/}   => "firebase.googleapis.com",
      %r{^providers/google\.firebase}  => "firebase.googleapis.com"
    }.freeze

    LEGACY_TYPE_TO_CE_TYPE = {
      "google.pubsub.topic.publish"                              => "google.cloud.pubsub.topic.v1.messagePublished",
      "providers/cloud.pubsub/eventTypes/topic.publish"          => "google.cloud.pubsub.topic.v1.messagePublished",
      "google.storage.object.finalize"                           => "google.cloud.storage.object.v1.finalized",
      "google.storage.object.delete"                             => "google.cloud.storage.object.v1.deleted",
      "google.storage.object.archive"                            => "google.cloud.storage.object.v1.archived",
      "google.storage.object.metadataUpdate"                     => "google.cloud.storage.object.v1.metadataUpdated",
      "providers/cloud.firestore/eventTypes/document.write"      => "google.cloud.firestore.document.v1.written",
      "providers/cloud.firestore/eventTypes/document.create"     => "google.cloud.firestore.document.v1.created",
      "providers/cloud.firestore/eventTypes/document.update"     => "google.cloud.firestore.document.v1.updated",
      "providers/cloud.firestore/eventTypes/document.delete"     => "google.cloud.firestore.document.v1.deleted",
      "providers/firebase.auth/eventTypes/user.create"           => "google.firebase.auth.user.v1.created",
      "providers/firebase.auth/eventTypes/user.delete"           => "google.firebase.auth.user.v1.deleted",
      "providers/google.firebase.analytics/eventTypes/event.log" => "google.firebase.analytics.log.v1.written",
      "providers/google.firebase.database/eventTypes/ref.create" => "google.firebase.database.document.v1.created",
      "providers/google.firebase.database/eventTypes/ref.write"  => "google.firebase.database.document.v1.written",
      "providers/google.firebase.database/eventTypes/ref.update" => "google.firebase.database.document.v1.updated",
      "providers/google.firebase.database/eventTypes/ref.delete" => "google.firebase.database.document.v1.deleted",
      "providers/cloud.storage/eventTypes/object.change"         => "google.cloud.storage.object.v1.finalized"
    }.freeze
  end
end
