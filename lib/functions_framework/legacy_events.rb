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
require "securerandom"

module FunctionsFramework
  ##
  # Converter from legacy GCF event formats to CloudEvents.
  #
  module LegacyEvents
    class << self
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
        charset = content_type.charset
        input = env["rack.input"]
        input = input.read if input.respond_to? :read
        input = input.encode charset if charset
        input = ::JSON.parse input
        decode_storage(input) ||
          decode_pubsub(input) ||
          decode_firestore(input) ||
          decode_storage_legacy(input) ||
          decode_pubsub_legacy(input)
      rescue ::JSON::ParserError
        nil
      end

      private

      def decode_storage input
        context = input["context"]
        return nil unless context
        type_match = /^google\.storage\.(\w+)\.(\w+)$/.match context["eventType"]
        return nil unless type_match
        resource = context["resource"]
        return nil unless resource && resource["service"] && resource["name"]
        return nil unless resource["type"] == "storage#object"
        CloudEvents::Event.new id:           ::SecureRandom.uuid,
                               source:       "//#{resource['service']}/#{resource['name']}",
                               type:         "google.cloud.storage.#{type_match[1]}.v1.#{type_match[2]}",
                               spec_version: "1.0",
                               data:         input["data"],
                               time:         context["timestamp"]
      end

      def decode_pubsub input
        context = input["context"]
        return nil unless context
        type_match = /^google\.pubsub\.(\w+)\.(\w+)$/.match context["eventType"]
        return nil unless type_match
        resource = context["resource"]
        return nil unless resource && resource["service"] && resource["name"]
        return nil unless resource["type"] == "type.googleapis.com/google.pubsub.v1.PubsubMessage"
        CloudEvents::Event.new id:           ::SecureRandom.uuid,
                               source:       "//#{resource['service']}/#{resource['name']}",
                               type:         "google.cloud.pubsub.#{type_match[1]}.v1.#{type_match[2]}",
                               spec_version: "1.0",
                               data:         input["data"],
                               time:         context["timestamp"]
      end

      def decode_firestore input
        return nil unless input["resource"] && input["data"] && input["timestamp"]
        type_match = %r{^providers/cloud\.firestore/eventTypes/(\w+)\.(\w+)$}.match input["eventType"]
        return nil unless type_match
        CloudEvents::Event.new id:           ::SecureRandom.uuid,
                               source:       "//firestore.googleapis.com/#{input['resource']}",
                               type:         "google.cloud.firestore.#{type_match[1]}.v1.#{type_match[2]}",
                               spec_version: "1.0",
                               data:         input["data"],
                               time:         input["timestamp"]
      end

      def decode_storage_legacy input
        return nil unless input["resource"] && input["data"] && input["timestamp"]
        type_match = %r{^providers/cloud\.storage/eventTypes/(\w+)\.(\w+)$}.match input["eventType"]
        return nil unless type_match
        CloudEvents::Event.new id:           ::SecureRandom.uuid,
                               source:       "//storage.googleapis.com/#{input['resource']}",
                               type:         "google.cloud.storage.#{type_match[1]}.v1.#{type_match[2]}",
                               spec_version: "1.0",
                               data:         input["data"],
                               time:         input["timestamp"]
      end

      def decode_pubsub_legacy input
        return nil unless input["resource"] && input["data"] && input["timestamp"]
        type_match = %r{^providers/cloud\.pubsub/eventTypes/(\w+)\.(\w+)$}.match input["eventType"]
        return nil unless type_match
        CloudEvents::Event.new id:           ::SecureRandom.uuid,
                               source:       "//pubsub.googleapis.com/#{input['resource']}",
                               type:         "google.cloud.pubsub.#{type_match[1]}.v1.#{type_match[2]}",
                               spec_version: "1.0",
                               data:         input["data"],
                               time:         input["timestamp"]
      end
    end
  end
end
