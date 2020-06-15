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

require "base64"
require "json"

module FunctionsFramework
  module CloudEvents
    ##
    # An implementation of JSON format and JSON batch format.
    #
    # See https://github.com/cloudevents/spec/blob/master/json-format.md
    #
    class JsonFormat
      ##
      # Decode an event from the given input JSON string.
      #
      # @param json [String] A JSON-formatted string
      # @return [FunctionsFramework::CloudEvents::Event]
      #
      def decode json, **_other_kwargs
        structure = ::JSON.parse json
        decode_hash_structure structure
      end

      ##
      # Encode an event to a JSON string.
      #
      # @param event [FunctionsFramework::CloudEvents::Event] An input event.
      # @param sort [boolean] Whether to sort keys of the JSON output.
      # @return [String] The JSON representation.
      #
      def encode event, sort: false, **_other_kwargs
        structure = encode_hash_structure event
        structure = sort_keys structure if sort
        ::JSON.dump structure
      end

      ##
      # Decode a batch of events from the given input string.
      #
      # @param json [String] A JSON-formatted string
      # @return [Array<FunctionsFramework::CloudEvents::Event>]
      #
      def decode_batch json, **_other_kwargs
        structure_array = Array(::JSON.parse(json))
        structure_array.map do |structure|
          decode_hash_structure structure
        end
      end

      ##
      # Encode a batch of event to a JSON string.
      #
      # @param events [Array<FunctionsFramework::CloudEvents::Event>] An array
      #     of input events.
      # @param sort [boolean] Whether to sort keys of the JSON output.
      # @return [String] The JSON representation.
      #
      def encode_batch events, sort: false, **_other_kwargs
        structure_array = Array(events).map do |event|
          structure = encode_hash_structure event
          sort ? sort_keys(structure) : structure
        end
        ::JSON.dump structure_array
      end

      ##
      # Decode a single event from a hash data structure with keys and types
      # conforming to the JSON event format.
      #
      # @param structure [Hash] An input hash.
      # @return [FunctionsFramework::CloudEvents::Event]
      #
      def decode_hash_structure structure
        if structure.key? "data_base64"
          structure = structure.dup
          structure["data"] = ::Base64.decode64 structure.delete "data_base64"
        end
        Event.create spec_version: structure["specversion"], attributes: structure
      end

      ##
      # Encode a single event to a hash data structure with keys and types
      # conforming to the JSON event format.
      #
      # @param event [FunctionsFramework::CloudEvents::Event] An input event.
      # @return [String] The hash structure.
      #
      def encode_hash_structure event
        structure = event.to_h
        data = structure["data"]
        if data.is_a?(::String) && data.encoding == ::Encoding::ASCII_8BIT
          structure.delete "data"
          structure["data_base64"] = ::Base64.encode64 data
        end
        structure
      end

      private

      def sort_keys hash
        result = {}
        hash.keys.sort.each do |key|
          result[key] = hash[key]
        end
        result
      end
    end
  end
end
