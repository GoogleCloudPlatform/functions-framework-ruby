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
    # A content handler for the JSON structure and JSON batch format.
    # See https://github.com/cloudevents/spec/blob/master/json-format.md
    #
    module JsonStructure
      class << self
        ##
        # Decode an event from the given input string
        #
        # @param input [IO] An IO-like object providing a JSON-formatted string
        # @param content_type [FunctionsFramework::CloudEvents::ContentType]
        #     the content type
        # @return [FunctionsFramework::CloudEvents::Event]
        #
        def decode_structured_content input, content_type
          input = input.read if input.respond_to? :read
          charset = content_type.charset
          input = input.encode charset if charset
          structure = ::JSON.parse input
          decode_hash_structure structure
        end

        ##
        # Decode a batch of events from the given input string
        #
        # @param input [IO] An IO-like object providing a JSON-formatted string
        # @param content_type [FunctionsFramework::CloudEvents::ContentType]
        #     the content type
        # @return [Array<FunctionsFramework::CloudEvents::Event>]
        #
        def decode_batched_content input, content_type
          input = input.read if input.respond_to? :read
          charset = content_type.charset
          input = input.encode charset if charset
          structure_array = Array(::JSON.parse(input))
          structure_array.map { |structure| decode_hash_structure structure }
        end

        ##
        # Decode a single event from a hash data structure with keys and types
        # conforming to the JSON event format
        #
        # @param structure [Hash] Input hash
        # @return [FunctionsFramework::CloudEvents::Event]
        #
        def decode_hash_structure structure
          data =
            if structure.key? "data_base64"
              ::Base64.decode64 structure["data_base64"]
            else
              structure["data"]
            end
          spec_version = structure["specversion"]
          raise "Unrecognized specversion: #{spec_version}" unless spec_version == "1.0"
          Event.new \
            id:                structure["id"],
            source:            structure["source"],
            type:              structure["type"],
            spec_version:      spec_version,
            data:              data,
            data_content_type: structure["datacontenttype"],
            data_schema:       structure["dataschema"],
            subject:           structure["subject"],
            time:              structure["time"]
        end
      end
    end
  end
end
