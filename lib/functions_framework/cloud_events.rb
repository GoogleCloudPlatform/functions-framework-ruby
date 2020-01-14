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

require "functions_framework/cloud_events/binary_content"
require "functions_framework/cloud_events/content_type"
require "functions_framework/cloud_events/event"

module FunctionsFramework
  ##
  # CloudEvents tools
  #
  module CloudEvents
    @structured_formats = {}
    @batched_formats = {}

    class << self
      ##
      # Register a handler for the given structured format.
      # The handler object must respond to the method
      # `#decode_structured_content`. See
      # {FunctionsFramework::CloudEvents::JsonStructure} for an example.
      #
      # @param format [String] The subtype format that should be handled by
      #     this handler
      # @param handler [#decode_structured_content] The handler object
      # @return [self]
      #
      def register_structured_format format, handler
        handlers = @structured_formats[format.to_s.strip.downcase] ||= []
        handlers << handler unless handlers.include? handler
        self
      end

      ##
      # Register a handler for the given batched format.
      # The handler object must respond to the method
      # `#decode_batched_content`. See
      # {FunctionsFramework::CloudEvents::JsonStructure} for an example.
      #
      # @param format [String] The subtype format that should be handled by
      #     this handler
      # @param handler [#decode_batched_content] The handler object
      # @return [self]
      #
      def register_batched_format format, handler
        handlers = @batched_formats[format.to_s.strip.downcase] ||= []
        handlers << handler unless handlers.include? handler
        self
      end

      ##
      # Decode an event from the given Rack environment hash.
      #
      # @param env [Hash] The Rack environment
      # @return [FunctionsFramework::CloudEvents::Event] if the request
      #     includes a single structured or binary event
      # @return [Array<FunctionsFramework::CloudEvents::Event>] if the request
      #     includes a batch of structured events
      #
      def decode_rack_env env
        content_type_header = env["CONTENT_TYPE"]
        raise "Missing content-type header" unless content_type_header
        content_type = ContentType.new content_type_header
        if content_type.media_type == "application"
          case content_type.subtype_prefix
          when "cloudevents"
            data = env["rack.input"].read
            return decode_structured_content data, content_type
          when "cloudevents-batch"
            data = env["rack.input"].read
            return decode_batched_content data, content_type
          end
        end
        BinaryContent.decode_rack_env env, content_type
      end

      ##
      # Decode a single event from the given content data.
      #
      # @param data [String] The content
      # @param content_type [FunctionsFramework::CloudEvents::ContentType] the
      #     content type
      # @return [FunctionsFramework::CloudEvents::Event]
      #
      def decode_structured_content data, content_type
        handlers = @structured_formats[content_type.subtype_format] || []
        handlers.reverse_each do |handler|
          event = handler.decode_structured_content data, content_type
          return event if event
        end
        raise "Unknown cloudevents format: #{content_type.subtype_format.inspect}"
      end

      ##
      # Decode a batch of events from the given content data.
      #
      # @param data [String] The content
      # @param content_type [FunctionsFramework::CloudEvents::ContentType] the
      #     content type
      # @return [Array<FunctionsFramework::CloudEvents::Event>]
      #
      def decode_batched_content data, content_type
        handlers = @batched_formats[content_type.subtype_format] || []
        handlers.reverse_each do |handler|
          events = handler.decode_batched_content data, content_type
          return events if events
        end
        raise "Unknown cloudevents batch format: #{content_type.subtype_format.inspect}"
      end
    end
  end
end

require "functions_framework/cloud_events/json_structure"

FunctionsFramework::CloudEvents.register_structured_format \
  "json", FunctionsFramework::CloudEvents::JsonStructure
FunctionsFramework::CloudEvents.register_batched_format \
  "json", FunctionsFramework::CloudEvents::JsonStructure
