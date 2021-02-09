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

require "logger"
require "optparse"

require "functions_framework"

module FunctionsFramework
  ##
  # Implementation of the functions-framework-ruby executable.
  #
  class CLI
    ##
    # The default logging level, if not given in the environment variable.
    # @return [Integer]
    #
    DEFAULT_LOGGING_LEVEL = ::Logger::Severity::INFO

    ##
    # Create a new CLI, setting arguments to their defaults.
    #
    def initialize
      @target = ::ENV["FUNCTION_TARGET"] || ::FunctionsFramework::DEFAULT_TARGET
      @source = ::ENV["FUNCTION_SOURCE"] || ::FunctionsFramework::DEFAULT_SOURCE
      @env = nil
      @port = nil
      @bind = nil
      @min_threads = nil
      @max_threads = nil
      @detailed_errors = nil
      @signature_type = ::ENV["FUNCTION_SIGNATURE_TYPE"]
      @logging_level = init_logging_level
      @what_to_do = nil
      @error_message = nil
      @exit_code = 0
    end

    ##
    # Determine if an error has occurred
    #
    # @return [boolean]
    #
    def error?
      !@error_message.nil?
    end

    ##
    # @return [Integer] The current exit status.
    #
    attr_reader :exit_code

    ##
    # @return [String] The current error message.
    # @return [nil] if no error has occurred.
    #
    attr_reader :error_message

    ##
    # Parse the given command line arguments.
    # Exits if argument parsing failed.
    #
    # @param argv [Array<String>]
    # @return [self]
    #
    def parse_args argv # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
      @option_parser = ::OptionParser.new do |op| # rubocop:disable Metrics/BlockLength
        op.on "-t", "--target TARGET",
              "Set the name of the function to execute (defaults to #{DEFAULT_TARGET})" do |val|
          @target = val
        end
        op.on "-s", "--source SOURCE",
              "Set the source file to load (defaults to #{DEFAULT_SOURCE})" do |val|
          @source = val
        end
        op.on "--signature-type TYPE",
              "Asserts that the function has the given signature type." \
              " Supported values are 'http' and 'cloudevent'." do |val|
          @signature_type = val
        end
        op.on "-p", "--port PORT", "Set the port to listen to (defaults to 8080)" do |val|
          @port = val.to_i
        end
        op.on "-b", "--bind BIND", "Set the address to bind to (defaults to 0.0.0.0)" do |val|
          @bind = val
        end
        op.on "-e", "--environment ENV", "Set the Rack environment" do |val|
          @env = val
        end
        op.on "--min-threads NUM", "Set the minimum threead pool size" do |val|
          @min_threads = val
        end
        op.on "--max-threads NUM", "Set the maximum threead pool size" do |val|
          @max_threads = val
        end
        op.on "--[no-]detailed-errors", "Set whether to show error details" do |val|
          @detailed_errors = val
        end
        op.on "--verify", "Verify the app only, but do not run the server." do
          @what_to_do ||= :verify
        end
        op.on "-v", "--verbose", "Increase log verbosity" do
          @logging_level -= 1
        end
        op.on "-q", "--quiet", "Decrease log verbosity" do
          @logging_level += 1
        end
        op.on "--version", "Display the framework version" do
          @what_to_do ||= :version
        end
        op.on "--help", "Display help" do
          @what_to_do ||= :help
        end
      end
      begin
        @option_parser.parse! argv
        error! "Unrecognized arguments: #{argv}\n#{@option_parser}", 2 unless argv.empty?
      rescue ::OptionParser::ParseError => e
        error! "#{e.message}\n#{@option_parser}", 2
      end
      self
    end

    ##
    # Perform the requested function.
    #
    #  *  If the `--version` flag was given, display the version.
    #  *  If the `--help` flag was given, display online help.
    #  *  If the `--verify` flag was given, load and verify the function,
    #     displaying any errors, then exit without starting a server.
    #  *  Otherwise, start the configured server and block until it stops.
    #
    # @return [self]
    #
    def run
      return self if error?
      case @what_to_do
      when :version
        puts ::FunctionsFramework::VERSION
      when :help
        puts @option_parser
      when :verify
        begin
          load_function
          puts "OK"
        rescue ::StandardError => e
          error! e.message
        end
      else
        begin
          start_server.wait_until_stopped
        rescue ::StandardError => e
          error! e.message
        end
      end
      self
    end

    ##
    # Finish the CLI, displaying any error status and exiting with the current
    # exit code. Never returns.
    #
    def complete
      warn @error_message if @error_message
      exit @exit_code
    end

    ##
    # Load the source and get and verify the requested function.
    # If a validation error occurs, raise an exception.
    #
    # @return [FunctionsFramework::Function]
    #
    # @private
    #
    def load_function
      ::FunctionsFramework.logger.level = @logging_level
      ::FunctionsFramework.logger.info "FunctionsFramework v#{VERSION}"
      ::ENV["FUNCTION_TARGET"] = @target
      ::ENV["FUNCTION_SOURCE"] = @source
      ::ENV["FUNCTION_SIGNATURE_TYPE"] = @signature_type
      ::FunctionsFramework.logger.info "FunctionsFramework: Loading functions from #{@source.inspect}..."
      load @source
      ::FunctionsFramework.logger.info "FunctionsFramework: Looking for function name #{@target.inspect}..."
      function = ::FunctionsFramework.global_registry[@target]
      raise "Undefined function: #{@target.inspect}" if function.nil?
      unless @signature_type.nil? ||
             @signature_type == "http" && function.type == :http ||
             ["cloudevent", "event"].include?(@signature_type) && function.type == :cloud_event
        raise "Function #{@target.inspect} does not match type #{@signature_type}"
      end
      function
    end

    ##
    # Start the configured server and return the running server object.
    # If a validation error occurs, raise an exception.
    #
    # @return [FunctionsFramework::Server]
    #
    # @private
    #
    def start_server
      function = load_function
      ::FunctionsFramework.logger.info "FunctionsFramework: Starting server..."
      ::FunctionsFramework.start function do |config|
        config.rack_env = @env
        config.port = @port
        config.bind_addr = @bind
        config.show_error_details = @detailed_errors
        config.min_threads = @min_threads
        config.max_threads = @max_threads
      end
    end

    private

    def init_logging_level
      level_name = ::ENV["FUNCTION_LOGGING_LEVEL"].to_s.upcase.to_sym
      ::Logger::Severity.const_get level_name
    rescue ::NameError
      DEFAULT_LOGGING_LEVEL
    end

    ##
    # Set the error status.
    # @param message [String] Error message.
    # @param code [Integer] Exit code, defaults to 1.
    #
    def error! message, code = 1
      @error_message = message
      @exit_code = code
    end
  end
end
