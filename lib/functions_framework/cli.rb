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
    # The default source file path
    # @return [String]
    #
    DEFAULT_SOURCE = "./app.rb".freeze

    ##
    # Create a new CLI
    #
    def initialize
      @target = ::ENV["FUNCTION_TARGET"] || DEFAULT_TARGET
      @source = ::ENV["FUNCTION_SOURCE"] || DEFAULT_SOURCE
      @env = nil
      @port = nil
      @bind = nil
    end

    ##
    # Parse the given command line arguments
    #
    # @param argv [Array<String>]
    # @return [self]
    #
    def parse_args argv
      option_parser = ::OptionParser.new do |op|
        op.on("-t", "--target TARGET", "Name of the function to execute") { |val| @target = val }
        op.on("-s", "--source SOURCE", "Source file to load") { |val| @source = val }
        op.on("-p", "--port PORT", "The port to listen to") { |val| @port = val.to_i }
        op.on("-b", "--bind BIND", "The address to bind to") { |val| @bind = val }
        op.on("-e", "--environment ENV", "The Rack environment") { |val| @env = val }
        op.on "--help", "Display help" do
          $stdout.puts op
          exit
        end
      end
      option_parser.parse! argv
      unless argv.empty?
        warn "Unrecognized arguments: #{argv}"
        exit 1
      end
      self
    end

    ##
    # Run the CLI
    #
    def run
      puts "Functions Framework: Loading functions from #{@source.inspect}..."
      load @source
      server = ::FunctionsFramework.start @target do |config|
        config.rack_env = @env
        config.port = @port
        config.bind_addr = @bind
      end
      puts "Functions Framework: Serving function #{@target.inspect} on port #{server.config.port}..."
      server.wait_until_stopped
      puts "Functions Framework: Shut down server."
      self
    end
  end
end
