#!/bin/bash
set -euo pipefail

pushd testdata

cat << EOF >> Gemfile
gem "functions_framework", github: "GoogleCloudPlatform/functions-framework-ruby", ref: "${GITHUB_SHA?}"
EOF

popd
