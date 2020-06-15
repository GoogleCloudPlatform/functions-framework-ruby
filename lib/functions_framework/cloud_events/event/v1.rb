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
    module Event
      ##
      # A CloudEvents V1 data type.
      #
      # This object a complete CloudEvent, including the event data and its
      # context attributes. It supports the standard required and optional
      # attributes defined in CloudEvents V1, and arbitrary extension
      # attributes. All attribute values can be obtained (in their string form)
      # via the {Event::V1#[]} method. Additionally, standard attributes have
      # their own accessor methods that may return typed objects (such as
      # `DateTime` for the `time` attribute).
      #
      # This object is immutable. The data and attribute values can be
      # retrieved but not modified. To obtain an event with modifications, use
      # the {#with} method to create a copy with the desired changes.
      #
      # See https://github.com/cloudevents/spec/blob/master/spec.md for
      # descriptions of the standard attributes.
      #
      class V1
        include Event

        ##
        # Create a new cloud event object with the given data and attributes.
        #
        # Event attributes may be presented as keyword arguments, or as a Hash
        # passed in via the `attributes` argument (but not both).
        #
        # The following standard attributes are supported and exposed as
        # attribute methods on the object.
        #
        #  *  **:spec_version** (or **:specversion**) [`String`] - _required_ -
        #     The CloudEvents spec version (i.e. the `specversion` field.)
        #  *  **:id** [`String`] - _required_ - The event `id` field.
        #  *  **:source** [`String`, `URI`] - _required_ - The event `source`
        #     field.
        #  *  **:type** [`String`] - _required_ - The event `type` field.
        #  *  **:data** [`Object`] - _optional_ - The data associated with the
        #     event (i.e. the `data` field.)
        #  *  **:data_content_type** (or **:datacontenttype**) [`String`,
        #     {ContentType}] - _optional_ - The content-type for the data, if
        #     the data is a string (i.e. the event `datacontenttype` field.)
        #  *  **:data_schema** (or **:dataschema**) [`String`, `URI`] -
        #     _optional_ - The event `dataschema` field.
        #  *  **:subject** [`String`] - _optional_ - The event `subject` field.
        #  *  **:time** [`String`, `DateTime`, `Time`] - _optional_ - The
        #     event `time` field.
        #
        # Any additional attributes are assumed to be extension attributes.
        # They are not available as separate methods, but can be accessed via
        # the {Event::V1#[]} operator.
        #
        # @param attributes [Hash] The data and attributes, as a hash.
        # @param args [keywords] The data and attributes, as keyword arguments.
        #
        def initialize attributes: nil, **args # rubocop:disable Metrics/AbcSize
          args = keys_to_strings(attributes || args)
          @attributes = {}
          @spec_version, _unused = interpret_string args, ["specversion", "spec_version"], required: true
          raise SpecVersionError, "Unrecognized specversion: #{@spec_version}" unless /^1(\.|$)/ =~ @spec_version
          @id, _unused = interpret_string args, ["id"], required: true
          @source, @source_string = interpret_uri args, ["source"], required: true
          @type, _unused = interpret_string args, ["type"], required: true
          @data, _unused = interpret_value args, ["data"], allow_nil: true
          @data_content_type, @data_content_type_string =
            interpret_content_type args, ["datacontenttype", "data_content_type"]
          @data_schema, @data_schema_string = interpret_uri args, ["dataschema", "data_schema"]
          @subject, _unused = interpret_string args, ["subject"]
          @time, @time_string = interpret_date_time args, ["time"]
          @attributes.merge! args
        end

        ##
        # Create and return a copy of this event with the given changes. See
        # the constructor for the parameters that can be passed. In general,
        # you can pass a new value for any attribute, or pass `nil` to remove
        # an optional attribute.
        #
        # @param changes [keywords] See {#initialize} for a list of arguments.
        # @return [FunctionFramework::CloudEvents::Event]
        #
        def with **changes
          attributes = @attributes.merge keys_to_strings changes
          V1.new attributes: attributes
        end

        ##
        # Return the value of the given named attribute. Both standard and
        # extension attributes are supported.
        #
        # Attribute names must be given as defined in the standard CloudEvents
        # specification. For example `specversion` rather than `spec_version`.
        #
        # Results are given in their "raw" form, generally a string. This may
        # be different from what is returned from corresponding attribute
        # methods. For example:
        #
        #     event["time"]     # => String rfc3339 representation
        #     event.time        # => DateTime object
        #     event.time_string # => String rfc3339 representation
        #
        # @param key [String,Symbol] The attribute name.
        # @return [String,nil]
        #
        def [] key
          @attributes[key.to_s]
        end

        ##
        # Return a hash representation of this event.
        #
        # @return [Hash]
        #
        def to_h
          @attributes.dup
        end

        ##
        # The `id` field. Required.
        #
        # @return [String]
        #
        attr_reader :id

        ##
        # The `source` field as a `URI` object. Required.
        #
        # @return [URI]
        #
        attr_reader :source

        ##
        # The string representation of the `source` field. Required.
        #
        # @return [String]
        #
        attr_reader :source_string

        ##
        # The `type` field. Required.
        #
        # @return [String]
        #
        attr_reader :type

        ##
        # The `specversion` field. Required.
        #
        # @return [String]
        #
        attr_reader :spec_version
        alias specversion spec_version

        ##
        # The event-specific data, or `nil` if there is no data.
        #
        # Data may be one of the following types:
        #  *  Binary data, represented by a `String` using the `ASCII-8BIT`
        #     encoding.
        #  *  A string in some other encoding such as `UTF-8` or `US-ASCII`.
        #  *  Any JSON data type, such as String, boolean, Integer, Array, or
        #     Hash
        #
        # @return [Object]
        #
        attr_reader :data

        ##
        # The optional `datacontenttype` field as a
        # {FunctionsFramework::CloudEvents::ContentType} object, or `nil` if
        # the field is absent.
        #
        # @return [FunctionsFramework::CloudEvents::ContentType,nil]
        #
        attr_reader :data_content_type
        alias datacontenttype data_content_type

        ##
        # The string representation of the optional `datacontenttype` field, or
        # `nil` if the field is absent.
        #
        # @return [String,nil]
        #
        attr_reader :data_content_type_string
        alias datacontenttype_string data_content_type_string

        ##
        # The optional `dataschema` field as a `URI` object, or `nil` if the
        # field is absent.
        #
        # @return [URI,nil]
        #
        attr_reader :data_schema
        alias dataschema data_schema

        ##
        # The string representation of the optional `dataschema` field, or
        # `nil` if the field is absent.
        #
        # @return [String,nil]
        #
        attr_reader :data_schema_string
        alias dataschema_string data_schema_string

        ##
        # The optional `subject` field, or `nil` if the field is absent.
        #
        # @return [String,nil]
        #
        attr_reader :subject

        ##
        # The optional `time` field as a `DateTime` object, or `nil` if the
        # field is absent.
        #
        # @return [DateTime,nil]
        #
        attr_reader :time

        ##
        # The rfc3339 string representation of the optional `time` field, or
        # `nil` if the field is absent.
        #
        # @return [String,nil]
        #
        attr_reader :time_string

        ## @private
        def == other
          other.is_a?(V1) && @attributes == other.instance_variable_get(:@attributes)
        end
        alias eql? ==

        ## @private
        def hash
          @hash ||= @attributes.hash
        end

        private

        def keys_to_strings hash
          result = {}
          hash.each do |key, val|
            result[key.to_s] = val
          end
          result
        end

        def interpret_string args, keys, required: false
          interpret_value args, keys, required: required do |value|
            case value
            when ::String
              raise AttributeError, "The #{keys.last} field cannot be empty" if value.empty?
              [value, value]
            else
              raise AttributeError, "Illegal type for #{keys.last}:" \
                                    " String expected but #{value.class} found"
            end
          end
        end

        def interpret_uri args, keys, required: false
          interpret_value args, keys, required: required do |value|
            case value
            when ::String
              raise AttributeError, "The #{keys.last} field cannot be empty" if value.empty?
              begin
                [::URI.parse(value), value]
              rescue ::URI::InvalidURIError => e
                raise AttributeError, "Illegal format for #{keys.last}: #{e.message}"
              end
            when ::URI::Generic
              [value, value.to_s]
            else
              raise AttributeError, "Illegal type for #{keys.last}:" \
                                    " String or URI expected but #{value.class} found"
            end
          end
        end

        def interpret_date_time args, keys, required: false
          interpret_value args, keys, required: required do |value|
            case value
            when ::String
              begin
                [::DateTime.rfc3339(value), value]
              rescue ::Date::Error => e
                raise AttributeError, "Illegal format for #{keys.last}: #{e.message}"
              end
            when ::DateTime
              [value, value.rfc3339]
            when ::Time
              value = value.to_datetime
              [value, value.rfc3339]
            else
              raise AttributeError, "Illegal type for #{keys.last}:" \
                                    " String, Time, or DateTime expected but #{value.class} found"
            end
          end
        end

        def interpret_content_type args, keys, required: false
          interpret_value args, keys, required: required do |value|
            case value
            when ::String
              raise AttributeError, "The #{keys.last} field cannot be empty" if value.empty?
              [ContentType.new(value), value]
            when ContentType
              [value, value.to_s]
            else
              raise AttributeError, "Illegal type for #{keys.last}:" \
                                    " String, or ContentType expected but #{value.class} found"
            end
          end
        end

        def interpret_value args, keys, required: false, allow_nil: false
          value = nil
          found = false
          keys.each do |key|
            key_present = args.key? key
            val = args.delete key
            if allow_nil && key_present || !allow_nil && !val.nil?
              value = val
              found = true
            end
          end
          if found
            if block_given?
              converted, raw = yield value
            else
              converted = raw = value
            end
            @attributes[keys.first] = raw
            [converted, raw]
          else
            raise AttributeError, "The #{keys.last} field is required" if required
            [nil, nil]
          end
        end
      end
    end
  end
end
