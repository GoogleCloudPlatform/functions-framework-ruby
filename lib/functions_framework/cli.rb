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

require "optparse"

require "functions_framework"

module FunctionsFramework
  ##
  # Implementation of the functions-framework executable.
  #
  class CLI
    ##
    # The default source file path.
    #
    # @return [String]
    #
    DEFAULT_SOURCE = "./app.rb".freeze

    ##
    # Create a new CLI, setting arguments to their defaults.
    #
    def initialize
      @target = ::ENV["FUNCTION_TARGET"] || DEFAULT_TARGET
      @source = ::ENV["FUNCTION_SOURCE"] || DEFAULT_SOURCE
      @env = nil
      @port = nil
      @bind = nil
      @min_threads = nil
      @max_threads = nil
      @detailed_errors = nil
    end

    ##
    # Parse the given command line arguments.
    # Exits if argument parsing failed.
    #
    # @param argv [Array<String>]
    # @return [self]
    #
    def parse_args argv # rubocop:disable Metrics/MethodLength
      option_parser = ::OptionParser.new do |op| # rubocop:disable Metrics/BlockLength
        op.on "-t", "--target TARGET",
              "Set the name of the function to execute (defaults to #{DEFAULT_TARGET})" do |val|
          @target = val
        end
        op.on "-s", "--source SOURCE",
              "Set the source file to load (defaults to #{DEFAULT_SOURCE})" do |val|
          @source = val
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
        op.on "-v", "--verbose", "Increase log verbosity" do
          ::FunctionsFramework.logger.level -= 1
        end
        op.on "-q", "--quiet", "Decrease log verbosity" do
          ::FunctionsFramework.logger.level += 1
        end
        op.on "--help", "Display help" do
          puts op
          exit
        end
      end
      option_parser.parse! argv
      unless argv.empty?
        warn "Unrecognized arguments: #{argv}"
        puts op
        exit 1
      end
      self
    end

    ##
    # Run the configured server, and block until it stops.
    # @return [self]
    #
    def run
      FunctionsFramework.logger.info \
        "FunctionsFramework: Loading functions from #{@source.inspect}..."
      load @source
      server = ::FunctionsFramework.start @target do |config|
        config.rack_env = @env
        config.port = @port
        config.bind_addr = @bind
        config.show_error_details = @detailed_errors
        config.min_threads = @min_threads
        config.max_threads = @max_threads
      end
      server.wait_until_stopped
      self
    end
  end
end
