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

require "date"
require "uri"

module FunctionsFramework
  module CloudEvents
    ##
    # A cloud event data type.
    #
    # This object represents both the event data and the context attributes.
    # It is immutable. The data and attribute values can be retrieved but not
    # mutated. To obtain an event with modifications, use the {#with} method to
    # create a copy with the desired changes.
    #
    # See https://github.com/cloudevents/spec/blob/master/spec.md for
    # descriptions of the various attributes.
    #
    class Event
      ##
      # Create a new cloud event object with the given data and attributes.
      #
      # @param id [String] The required `id` field
      # @param source [String,URI] The required `source` field
      # @param type [String] The required `type` field
      # @param spec_version [String] The required `specversion` field
      # @param data [String,Boolean,Integer,Array,Hash] The optional `data`
      #     field
      # @param data_content_type [String,FunctionsFramework::CloudEvents::ContentType]
      #     The optional `datacontenttype` field
      # @param data_schema [String,URI] The optional `dataschema` field
      # @param subject [String] The optional `subject` field
      # @param time [String,DateTime] The optional `time` field
      #
      def initialize \
          id:,
          source:,
          type:,
          spec_version:,
          data: nil,
          data_content_type: nil,
          data_schema: nil,
          subject: nil,
          time: nil
        @id = interpret_string "id", id, true
        @source, @source_string = interpret_uri "source", source, true
        @type = interpret_string "type", type, true
        @spec_version = interpret_string "spec_version", spec_version, true
        @data = data
        @data_content_type, @data_content_type_string =
          interpret_content_type "data_content_type", data_content_type
        @data_schema, @data_schema_string = interpret_uri "data_schema", data_schema
        @subject = interpret_string "subject", subject
        @time, @time_string = interpret_date_time "time", time
      end

      ##
      # Create and return a copy of this event with the given changes. See the
      # constructor for the parameters that can be passed.
      #
      # @param changes [Hash] See {#initialize}
      # @return [FunctionFramework::CloudEvents::Event]
      #
      def with **changes
        params = {
          id:                id,
          source:            source,
          type:              type,
          spec_version:      spec_version,
          data:              data,
          data_content_type: data_content_type,
          data_schema:       data_schema,
          subject:           subject,
          time:              time
        }
        params.merge! changes
        Event.new(**params)
      end

      ##
      # The `id` field
      # @return [String]
      #
      attr_reader :id

      ##
      # The `source` field as a `URI` object
      # @return [URI]
      #
      attr_reader :source

      ##
      # The string representation of the `source` field
      # @return [String]
      #
      attr_reader :source_string

      ##
      # The `type` field
      # @return [String]
      #
      attr_reader :type

      ##
      # The `specversion` field
      # @return [String]
      #
      attr_reader :spec_version
      alias specversion spec_version

      ##
      # The event-specific data, or `nil` if there is no data.
      #
      # Data may be one of the following types:
      # * Binary data, represented by a `String` using `ASCII-8BIT` encoding
      # * A string in some other encoding such as `UTF-8` or `US-ASCII`
      # * Any JSON data type, such as String, boolean, Integer, Array, or Hash
      #
      # @return [Object]
      #
      attr_reader :data

      ##
      # The optional `datacontenttype` field as a
      # {FunctionsFramework::CloudEvents::ContentType} object, or `nil` if the
      # field is absent
      #
      # @return [FunctionsFramework::CloudEvents::ContentType,nil]
      #
      attr_reader :data_content_type
      alias datacontenttype data_content_type

      ##
      # The string representation of the optional `datacontenttype` field, or
      # `nil` if the field is absent
      #
      # @return [String,nil]
      #
      attr_reader :data_content_type_string
      alias datacontenttype_string data_content_type_string

      ##
      # The optional `dataschema` field as a `URI` object, or `nil` if the
      # field is absent
      #
      # @return [URI,nil]
      #
      attr_reader :data_schema
      alias dataschema data_schema

      ##
      # The string representation of the optional `dataschema` field, or `nil`
      # if the field is absent
      #
      # @return [String,nil]
      #
      attr_reader :data_schema_string
      alias dataschema_string data_schema_string

      ##
      # The optional `subject` field, or `nil` if the field is absent
      #
      # @return [String,nil]
      #
      attr_reader :subject

      ##
      # The optional `time` field as a `DateTime` object, or `nil` if the field
      # is absent
      #
      # @return [DateTime,nil]
      #
      attr_reader :time

      ##
      # The string representation of the optional `time` field, or `nil` if the
      # field is absent
      #
      # @return [String,nil]
      #
      attr_reader :time_string

      ## @private
      def == other
        other.is_a?(ContentType) &&
          id == other.id &&
          source == other.source &&
          type == other.type &&
          spec_version == other.spec_version &&
          data_content_type == other.data_content_type &&
          data_schema == other.data_schema &&
          subject == other.subject &&
          time == other.time &&
          data == other.data
      end
      alias eql? ==

      ## @private
      def hash
        @hash ||=
          [id, source, type, spec_version, data_content_type, data_schema, subject, time, data].hash
      end

      private

      def interpret_string name, input, required = false
        case input
        when ::String
          raise ::ArgumentError, "The #{name} field cannot be empty" if input.empty?
          input
        when nil
          raise ::ArgumentError, "The #{name} field is required" if required
          nil
        else
          raise ::ArgumentError, "Illegal type for #{name} field: #{input.inspect}"
        end
      end

      def interpret_uri name, input, required = false
        case input
        when ::String
          raise ::ArgumentError, "The #{name} field cannot be empty" if input.empty?
          [::URI.parse(input), input]
        when ::URI::Generic
          [input, input.to_s]
        when nil
          raise ::ArgumentError, "The #{name} field is required" if required
          [nil, nil]
        else
          raise ::ArgumentError, "Illegal type for #{name} field: #{input.inspect}"
        end
      end

      def interpret_date_time name, input, required = false
        case input
        when ::String
          raise ::ArgumentError, "The #{name} field cannot be empty" if input.empty?
          [::DateTime.rfc3339(input), input]
        when ::DateTime
          [input, input.rfc3339]
        when nil
          raise ::ArgumentError, "The #{name} field is required" if required
          [nil, nil]
        else
          raise ::ArgumentError, "Illegal type for #{name} field: #{input.inspect}"
        end
      end

      def interpret_content_type name, input, required = false
        case input
        when ::String
          raise ::ArgumentError, "The #{name} field cannot be empty" if input.empty?
          [ContentType.new(input), input]
        when ContentType
          [input, input.to_s]
        when nil
          raise ::ArgumentError, "The #{name} field is required" if required
          [nil, nil]
        else
          raise ::ArgumentError, "Illegal type for #{name} field: #{input.inspect}"
        end
      end
    end
  end
end
