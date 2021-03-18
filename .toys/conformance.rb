# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

desc "Run conformance tests locally"

static :github_url, "https://github.com/GoogleCloudPlatform/functions-framework-conformance.git"

flag :keep_output

include :fileutils
include :exec, e: true

def run
  mkdir_p "tmp"
  cd "tmp" do
    unless File.directory? "functions-framework-conformance"
      exec ["git", "clone", github_url]
    end
    cd "functions-framework-conformance" do
      exec ["git", "pull"]
      exec ["go", "build"], chdir: "client"
    end
  end
  begin
    exec ["tmp/functions-framework-conformance/client/client",
          "-cmd", "bundle exec functions-framework-ruby --source test/conformance/app.rb --target http_func --signature-type http",
          "-type=http",
          "-builder-source=testdata",
          "-buildpacks=false"]
    exec ["tmp/functions-framework-conformance/client/client",
          "-cmd", "bundle exec functions-framework-ruby --source test/conformance/app.rb --target cloudevent_func --signature-type cloudevent",
          "-type=cloudevent",
          "-validate-mapping=true",
          "-buildpacks=false"]
  ensure
    unless keep_output
      rm_f "function_output.json"
      rm_f "serverlog_stderr.txt"
      rm_f "serverlog_stdout.txt"
    end
  end
end
