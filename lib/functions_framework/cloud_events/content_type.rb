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
    # If parsing fails, this class will try to get as much information as it
    # can, and fill the rest with defaults as recommended in RFC 2045 sec 5.2.
    # In case of a parsing error, the {#error_message} field will be set.
    #
    class ContentType
      ##
      # Parse the given header value.
      #
      # @param string [String] Content-Type header value in RFC 2045 format
      #
      def initialize string
        @string = string
        @media_type = "text"
        @subtype_base = @subtype = "plain"
        @subtype_format = nil
        @params = []
        @charset = "us-ascii"
        @error_message = nil
        parse consume_comments string.strip
        @canonical_string = "#{@media_type}/#{@subtype}" +
                            @params.map { |k, v| "; #{k}=#{v}" }.join
      end

      ##
      # The original header content string.
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
      # by a plus sign).
      # @return [String]
      #
      attr_reader :subtype

      ##
      # The portion of the content subtype before any plus sign.
      # @return [String]
      #
      attr_reader :subtype_base

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
      # The charset, defaulting to "us-ascii" if none is explicitly set.
      # @return [String]
      #
      attr_reader :charset

      ##
      # The error message when parsing, or `nil` if there was no error message.
      # @return [String,nil]
      #
      attr_reader :error_message

      ##
      # An array of values for the given parameter name
      # @param key [String]
      # @return [Array<String>]
      #
      def param_values key
        key = key.downcase
        @params.inject([]) { |a, (k, v)| key == k ? a << v : a }
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

      ## @private
      class ParseError < ::StandardError
      end

      private

      def parse str
        @media_type, str = consume_token str, downcase: true, error_message: "Failed to parse media type"
        str = consume_special str, "/"
        @subtype, str = consume_token str, downcase: true, error_message: "Failed to parse subtype"
        @subtype_base, @subtype_format = @subtype.split "+", 2
        until str.empty?
          str = consume_special str, ";"
          name, str = consume_token str, downcase: true, error_message: "Faled to parse attribute name"
          str = consume_special str, "=", error_message: "Failed to find value for attribute #{name}"
          val, str = consume_token_or_quoted str, error_message: "Failed to parse value for attribute #{name}"
          @params << [name, val]
          @charset = val if name == "charset"
        end
      rescue ParseError => e
        @error_message = e.message
      end

      def consume_token str, downcase: false, error_message: nil
        match = /^([\w!#\$%&'\*\+\.\^`\{\|\}-]+)(.*)$/.match str
        raise ParseError, error_message || "Expected token" unless match
        token = match[1]
        token.downcase! if downcase
        str = consume_comments match[2].strip
        [token, str]
      end

      def consume_special str, expected, error_message: nil
        raise ParseError, error_message || "Expected #{expected.inspect}" unless str.start_with? expected
        consume_comments str[1..-1].strip
      end

      def consume_token_or_quoted str, error_message: nil
        return consume_token str unless str.start_with? '"'
        arr = []
        index = 1
        loop do
          char = str[index]
          case char
          when nil
            raise ParseError, error_message || "Quoted-string never finished"
          when "\""
            break
          when "\\"
            char = str[index + 1]
            raise ParseError, error_message || "Quoted-string never finished" unless char
            arr << char
            index += 2
          else
            arr << char
            index += 1
          end
        end
        index += 1
        str = consume_comments str[index..-1].strip
        [arr.join, str]
      end

      def consume_comments str
        return str unless str.start_with? "("
        index = 1
        loop do
          char = str[index]
          case char
          when nil
            raise ParseError, "Comment never finished"
          when ")"
            break
          when "\\"
            index += 2
          when "("
            str = consume_comments str[index..-1]
            index = 0
          else
            index += 1
          end
        end
        index += 1
        consume_comments str[index..-1].strip
      end
    end
  end
end
