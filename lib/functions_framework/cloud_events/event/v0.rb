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
      # A CloudEvents V0 data type.
      #
      # This object represents a complete CloudEvent, including the event data
      # and context attributes. It supports the standard required and optional
      # attributes defined in CloudEvents V0.3, and arbitrary extension
      # attributes. All attribute values can be obtained (in their string form)
      # via the {Event::V0#[]} method. Additionally, standard attributes have
      # their own accessor methods that may return typed objects (such as
      # `DateTime` for the `time` attribute).
      #
      # This object is immutable. The data and attribute values can be
      # retrieved but not modified. To obtain an event with modifications, use
      # the {#with} method to create a copy with the desired changes.
      #
      # See https://github.com/cloudevents/spec/blob/v0.3/spec.md for
      # descriptions of the standard attributes.
      #
      class V0
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
        #  *  **:data_content_encoding** (or **:datacontentencoding**)
        #     [`String`] - _optional_ - The content-encoding for the data (i.e.
        #     the `datacontentencoding` field.)
        #  *  **:data_content_type** (or **:datacontenttype**) [`String`,
        #     {ContentType}] - _optional_ - The content-type for the data, if
        #     the data is a string (i.e. the event `datacontenttype` field.)
        #  *  **:schema_url** (or **:schemaurl**) [`String`, `URI`] -
        #     _optional_ - The event `schemaurl` field.
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
        def initialize attributes: nil, **args
          interpreter = FieldInterpreter.new attributes || args
          @spec_version = interpreter.spec_version ["specversion", "spec_version"], accept: /^0\.3$/
          @id = interpreter.string ["id"], required: true
          @source = interpreter.uri ["source"], required: true
          @type = interpreter.string ["type"], required: true
          @data = interpreter.object ["data"], allow_nil: true
          @data_content_encoding = interpreter.string ["datacontentencoding", "data_content_encoding"]
          @data_content_type = interpreter.content_type ["datacontenttype", "data_content_type"]
          @schema_url = interpreter.uri ["schemaurl", "schema_url"]
          @subject = interpreter.string ["subject"]
          @time = interpreter.rfc3339_date_time ["time"]
          @attributes = interpreter.finish_attributes
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
          attributes = @attributes.merge changes
          V0.new attributes: attributes
        end

        ##
        # Return the value of the given named attribute. Both standard and
        # extension attributes are supported.
        #
        # Attribute names must be given as defined in the standard CloudEvents
        # specification. For example `specversion` rather than `spec_version`.
        #
        # Results are given in their "raw" form, generally a string. This may
        # be different from the Ruby object returned from corresponding
        # attribute methods. For example:
        #
        #     event["time"]     # => String rfc3339 representation
        #     event.time        # => DateTime object
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
        #  *  Any JSON data type, such as a Boolean, Integer, Array, Hash, or
        #     `nil`.
        #
        # @return [Object]
        #
        attr_reader :data

        ##
        # The optional `datacontentencoding` field as a `String` object, or
        # `nil` if the field is absent.
        #
        # @return [String,nil]
        #
        attr_reader :data_content_encoding
        alias datacontentencoding data_content_encoding

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
        # The optional `schemaurl` field as a `URI` object, or `nil` if the
        # field is absent.
        #
        # @return [URI,nil]
        #
        attr_reader :schema_url
        alias schemaurl schema_url

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

        ## @private
        def == other
          other.is_a?(V1) && @attributes == other.instance_variable_get(:@attributes)
        end
        alias eql? ==

        ## @private
        def hash
          @hash ||= @attributes.hash
        end
      end
    end
  end
end
