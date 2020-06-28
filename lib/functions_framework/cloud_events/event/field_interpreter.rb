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
    module Event
      ##
      # A helper that extracts and interprets event fields from an input hash.
      #
      # @private
      #
      class FieldInterpreter
        def initialize args
          @args = keys_to_strings args
          @attributes = {}
        end

        def finish_attributes
          @attributes.merge! @args
          @args = {}
          @attributes
        end

        def string keys, required: false
          object keys, required: required do |value|
            case value
            when ::String
              raise AttributeError, "The #{keys.first} field cannot be empty" if value.empty?
              [value, value]
            else
              raise AttributeError, "Illegal type for #{keys.first}:" \
                                    " String expected but #{value.class} found"
            end
          end
        end

        def uri keys, required: false
          object keys, required: required do |value|
            case value
            when ::String
              raise AttributeError, "The #{keys.first} field cannot be empty" if value.empty?
              begin
                [::URI.parse(value), value]
              rescue ::URI::InvalidURIError => e
                raise AttributeError, "Illegal format for #{keys.first}: #{e.message}"
              end
            when ::URI::Generic
              [value, value.to_s]
            else
              raise AttributeError, "Illegal type for #{keys.first}:" \
                                    " String or URI expected but #{value.class} found"
            end
          end
        end

        def rfc3339_date_time keys, required: false
          object keys, required: required do |value|
            case value
            when ::String
              begin
                [::DateTime.rfc3339(value), value]
              rescue ::Date::Error => e
                raise AttributeError, "Illegal format for #{keys.first}: #{e.message}"
              end
            when ::DateTime
              [value, value.rfc3339]
            when ::Time
              value = value.to_datetime
              [value, value.rfc3339]
            else
              raise AttributeError, "Illegal type for #{keys.first}:" \
                                    " String, Time, or DateTime expected but #{value.class} found"
            end
          end
        end

        def content_type keys, required: false
          object keys, required: required do |value|
            case value
            when ::String
              raise AttributeError, "The #{keys.first} field cannot be empty" if value.empty?
              [ContentType.new(value), value]
            when ContentType
              [value, value.to_s]
            else
              raise AttributeError, "Illegal type for #{keys.first}:" \
                                    " String, or ContentType expected but #{value.class} found"
            end
          end
        end

        def spec_version keys, accept:
          object keys, required: true do |value|
            case value
            when ::String
              raise SpecVersionError, "Unrecognized specversion: #{value}" unless accept =~ value
              [value, value]
            else
              raise AttributeError, "Illegal type for #{keys.first}:" \
                                    " String expected but #{value.class} found"
            end
          end
        end

        UNDEFINED = Object.new

        def object keys, required: false, allow_nil: false
          value = UNDEFINED
          keys.each do |key|
            key_present = @args.key? key
            val = @args.delete key
            value = val if allow_nil && key_present || !allow_nil && !val.nil?
          end
          if value == UNDEFINED
            raise AttributeError, "The #{keys.first} field is required" if required
            return nil
          end
          if block_given?
            converted, raw = yield value
          else
            converted = raw = value
          end
          @attributes[keys.first] = raw
          converted
        end

        private

        def keys_to_strings hash
          result = {}
          hash.each do |key, val|
            result[key.to_s] = val
          end
          result
        end
      end
    end
  end
end
