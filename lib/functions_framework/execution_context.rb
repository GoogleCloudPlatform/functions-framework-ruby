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
  ##
  # The execution context of a running function.
  #
  # An object of this class is `self` while a function block is running.
  #
  class ExecutionContext
    ##
    # Create an ExecutionContext
    # @private
    #
    def initialize function, logger: nil
      @function_name = function.name
      @function_type = function.type
      @logger = logger || FunctionsFramework.logger
    end

    ##
    # @return [::Logger] A logger for use by this function.
    #
    attr_reader :logger

    ##
    # @return [String] The name of the running function.
    #
    attr_reader :function_name

    ##
    # @return [Symbol] The type of the running function. Possible values are
    #     `:http` and `:cloud_event`.
    #
    attr_reader :function_type
  end
end
