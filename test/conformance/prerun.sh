# prerun.sh sets up the test function to use the functions framework commit
# specified. This makes the function `pack` buildable with GCF buildpacks.
#
# `pack` build example command:
# pack build myfn --verbose --builder us.gcr.io/fn-img/buildpacks/ruby30/builder:ruby30_20220620_3_0_4_RC00 --env GOOGLE_RUNTIME=ruby30 --env GOOGLE_FUNCTION_TARGET=http_func --env X_GOOGLE_TARGET_PLATFORM=gcf
FRAMEWORK_VERSION=$1

# exit when any command fails
set -e

cd $(dirname $0)

if [ -z "${FRAMEWORK_VERSION}" ]
    then
        echo "Functions Framework version required as first parameter"
        exit 1
fi

echo "source 'https://rubygems.org'
gem 'functions_framework', github: 'GoogleCloudPlatform/functions-framework-ruby', ref: '$FRAMEWORK_VERSION'" > Gemfile
cat Gemfile

sudo gem install bundler

# Generate a Gemfile.lock without installing any Gems
sudo bundle lock --update
cat Gemfile.lock
