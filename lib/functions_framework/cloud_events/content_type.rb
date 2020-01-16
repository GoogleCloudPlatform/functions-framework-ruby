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
    # A parsed content-type header.
    #
    # This object represents the information contained in a Content-Type,
    # obtained by parsing the header according to RFC 2045.
    #
    # Case-insensitive fields, such as media_type and subtype, are normalized
    # to lower case.
    #
    class ContentType
      ##
      # Parse the given header value
      #
      # @param string [String] Content-Type header value in RFC 2045 format
      #
      def initialize string
        @string = string
        # TODO: This handles simple cases but is not RFC-822 compliant.
        sections = string.to_s.split ";"
        media_type, subtype = sections.shift.split "/"
        subtype_prefix, subtype_format = subtype.split "+"
        @media_type = media_type.strip.downcase
        @subtype = subtype.strip.downcase
        @subtype_prefix = subtype_prefix.strip.downcase
        @subtype_format = subtype_format&.strip&.downcase
        @params = initialize_params sections
        @canonical_string = "#{@media_type}/#{@subtype}" +
                            @params.map { |k, v| "; #{k}=#{v}" }.join
      end

      ##
      # The original header content string
      # @return [String]
      #
      attr_reader :string
      alias to_s string

      ##
      # A "canonical" header content string with spacing and capitalization
      # normalized.
      # @return [String]
      #
      attr_reader :canonical_string

      ##
      # The media type.
      # @return [String]
      #
      attr_reader :media_type

      ##
      # The entire content subtype (which could include an extension delimited
      # by a plus sign)
      # @return [String]
      #
      attr_reader :subtype

      ##
      # The portion of the content subtype before any plus sign.
      # @return [String]
      #
      attr_reader :subtype_prefix

      ##
      # The portion of the content subtype after any plus sign, or nil if there
      # is no plus sign in the subtype.
      # @return [String,nil]
      #
      attr_reader :subtype_format

      ##
      # An array of parameters, each element as a two-element array of the
      # parameter name and value.
      # @return [Array<Array(String,String)>]
      #
      attr_reader :params

      ##
      # An array of values for the given parameter name
      # @param key [String]
      # @return [Array<String>]
      #
      def param_values key
        key = key.downcase
        @params.inject([]) { |a, (k, v)| key == k ? a << v : a }
      end

      ##
      # The first value of the "charset" parameter, or nil if there is no
      # charset.
      # @return [String,nil]
      #
      def charset
        param_values("charset").first
      end

      ## @private
      def == other
        other.is_a?(ContentType) && canonical_string == other.canonical_string
      end
      alias eql? ==

      ## @private
      def hash
        canonical_string.hash
      end

      private

      def initialize_params sections
        params = sections.map do |s|
          k, v = s.split "="
          [k.strip.downcase, v.strip]
        end
        params.sort! do |(k1, v1), (k2, v2)|
          a = k1 <=> k2
          a.zero? ? v1 <=> v2 : a
        end
        params
      end
    end
  end
end
