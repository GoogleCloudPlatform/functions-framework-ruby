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
require "functions_framework/cloud_events/errors"
require "functions_framework/cloud_events/event"

module FunctionsFramework
  ##
  # CloudEvents implementation.
  #
  # This is a Ruby implementation of the [CloudEvents](https://cloudevents.io)
  # [1.0 specification](https://github.com/cloudevents/spec/blob/master/spec.md).
  # It provides for unmarshaling of events from Rack environment data from
  # binary (i.e. header-based) format, as well as structured (body-based) and
  # batch formats. A standard JSON structure parser is included. It is also
  # possible to register handlers for other formats.
  #
  # TODO: Unmarshaling of events is implemented, but marshaling is not.
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
      # Decode an event from the given Rack environment hash. Following the
      # CloudEvents spec, this chooses a handler based on the Content-Type of
      # the request.
      #
      # @param env [Hash] The Rack environment
      # @return [FunctionsFramework::CloudEvents::Event] if the request
      #     includes a single structured or binary event
      # @return [Array<FunctionsFramework::CloudEvents::Event>] if the request
      #     includes a batch of structured events
      # @return [nil] if the request is not a CloudEvent.
      #
      def decode_rack_env env
        content_type_header = env["CONTENT_TYPE"]
        return nil unless content_type_header
        content_type = ContentType.new content_type_header
        if content_type.media_type == "application"
          case content_type.subtype_prefix
          when "cloudevents"
            return decode_structured_content env["rack.input"], content_type
          when "cloudevents-batch"
            return decode_batched_content env["rack.input"], content_type
          end
        end
        BinaryContent.decode_rack_env env, content_type
      end

      ##
      # Decode a single event from the given content data. This should be
      # passed the request body, if the Content-Type is of the form
      # `application/cloudevents+format`.
      #
      # @param input [IO] An IO-like object providing the content
      # @param content_type [FunctionsFramework::CloudEvents::ContentType] the
      #     content type
      # @return [FunctionsFramework::CloudEvents::Event]
      #
      def decode_structured_content input, content_type
        handlers = @structured_formats[content_type.subtype_format] || []
        handlers.reverse_each do |handler|
          event = handler.decode_structured_content input, content_type
          return event if event
        end
        raise HttpContentError, "Unknown cloudevents format: #{content_type.subtype_format.inspect}"
      end

      ##
      # Decode a batch of events from the given content data. This should be
      # passed the request body, if the Content-Type is of the form
      # `application/cloudevents-batch+format`.
      #
      # @param input [IO] An IO-like object providing the content
      # @param content_type [FunctionsFramework::CloudEvents::ContentType] the
      #     content type
      # @return [Array<FunctionsFramework::CloudEvents::Event>]
      #
      def decode_batched_content input, content_type
        handlers = @batched_formats[content_type.subtype_format] || []
        handlers.reverse_each do |handler|
          events = handler.decode_batched_content input, content_type
          return events if events
        end
        raise HttpContentError, "Unknown cloudevents batch format: #{content_type.subtype_format.inspect}"
      end
    end
  end
end

require "functions_framework/cloud_events/json_structure"

FunctionsFramework::CloudEvents.register_structured_format \
  "json", FunctionsFramework::CloudEvents::JsonStructure
FunctionsFramework::CloudEvents.register_batched_format \
  "json", FunctionsFramework::CloudEvents::JsonStructure
