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

require "functions_framework/cloud_events/content_type"
require "functions_framework/cloud_events/errors"
require "functions_framework/cloud_events/event"
require "functions_framework/cloud_events/http_binding"
require "functions_framework/cloud_events/json_format"

module FunctionsFramework
  ##
  # CloudEvents implementation.
  #
  # This is a Ruby implementation of the [CloudEvents](https://cloudevents.io)
  # specification. It supports both
  # [CloudEvents 0.3](https://github.com/cloudevents/spec/blob/v0.3/spec.md) and
  # [CloudEvents 1.0](https://github.com/cloudevents/spec/blob/v1.0/spec.md).
  #
  module CloudEvents
    # @private
    SUPPORTED_SPEC_VERSIONS = ["0.3", "1.0"].freeze

    class << self
      ##
      # The spec versions supported by this implementation.
      #
      # @return [Array<String>]
      #
      def supported_spec_versions
        SUPPORTED_SPEC_VERSIONS
      end
    end
  end
end
