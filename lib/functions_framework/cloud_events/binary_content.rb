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

module FunctionsFramework
  module CloudEvents
    ##
    # A content handler for the binary mode.
    # See https://github.com/cloudevents/spec/blob/master/http-protocol-binding.md
    #
    module BinaryContent
      class << self
        ##
        # Decode an event from the given Rack environment
        #
        # @param env [Hash] Rack environment hash
        # @param content_type [FunctionsFramework::CloudEvents::ContentType]
        #     the content type from the Rack environment
        # @return [FunctionsFramework::CloudEvents::Event]
        #
        def decode_rack_env env, content_type
          data = env["rack.input"]&.read
          spec_version = interpret_header env, "HTTP_CE_SPECVERSION"
          raise "Unrecognized specversion: #{spec_version}" unless spec_version == "1.0"
          Event.new \
            id:                interpret_header(env, "HTTP_CE_ID"),
            source:            interpret_header(env, "HTTP_CE_SOURCE"),
            type:              interpret_header(env, "HTTP_CE_TYPE"),
            spec_version:      spec_version,
            data:              data,
            data_content_type: content_type,
            data_schema:       interpret_header(env, "HTTP_CE_DATASCHEMA"),
            subject:           interpret_header(env, "HTTP_CE_SUBJECT"),
            time:              interpret_header(env, "HTTP_CE_TIME")
        end

        private

        def interpret_header env, key
          escaped_value = env[key]
          return nil if escaped_value.nil?
          escaped_value.gsub(/%([0-9a-fA-F]{2})/) do
            [$1.to_i(16)].pack "C" # rubocop:disable Style/PerlBackrefs
          end
        end
      end
    end
  end
end
