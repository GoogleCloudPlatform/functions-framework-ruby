# Functions Framework [![Documentation](https://img.shields.io/badge/docs-FunctionsFramework-red.svg)](https://rubydoc.info/gems/functions_framework/FunctionsFramework) [![Gem Version](https://badge.fury.io/rb/functions_framework.svg)](https://badge.fury.io/rb/functions_framework)

An open source framework for writing lightweight, portable Ruby functions that
run in a serverless environment. Functions written to this Framework will run
in many different environments, including:

 *  [Google Cloud Functions](https://cloud.google.com/functions) *(coming soon)*
 *  [Cloud Run or Cloud Run for Anthos](https://cloud.google.com/run)
 *  Any other [Knative](https://github.com/knative)-based environment
 *  Your local development machine

The framework allows you to go from:

```ruby
FunctionsFramework.http do |request|
  "Hello, world!\n"
end
```

To:

```sh
curl http://my-url
# Output: Hello, world!
```

All without needing to worry about writing an HTTP server or complicated
request handling logic.

For more information about the Functions Framework, see
https://github.com/GoogleCloudPlatform/functions-framework

## Features

 *  Define named functions using normal Ruby constructs.
 *  Invoke functions in response to requests.
 *  Automatically unmarshal events conforming to the
    [CloudEvents](https://cloudevents.io) spec.
 *  Automatically convert most legacy events from Google Cloud services such
    as Cloud Pub/Sub and Cloud Storage, to CloudEvents.
 *  Spin up a local development server for quick testing.
 *  Integrate with standard Ruby libraries such as Rack and Minitest.
 *  Portable between serverless platforms.

## Installation

Install the Functions Framework via Rubygems:

```sh
gem install functions_framework
```

Or add it to your Gemfile for installation using Bundler:

```ruby
# Gemfile
gem "functions_framework", "~> 0.1"
```

### Supported Ruby versions

This library is supported on Ruby 2.4+.

Google provides official support for Ruby versions that are actively supported
by Ruby Core—that is, Ruby versions that are either in normal maintenance or
in security maintenance, and not end of life. Currently, this means Ruby 2.4
and later. Older versions of Ruby _may_ still work, but are unsupported and not
recommended. See https://www.ruby-lang.org/en/downloads/branches/ for details
about the Ruby support schedule.

## Quickstart

### Running Hello World on your local machine

Create a `Gemfile` listing the Functions Framework as a dependency:

```ruby
# Gemfile
source "https://rubygems.org"
gem "functions_framework", "~> 0.1"
```

Create a file called `app.rb` and include the following code. This defines a
simple function called "hello".

```ruby
# app.rb
require "functions_framework"

FunctionsFramework.http("hello") do |request|
  "Hello, world!\n"
end
```

Install the bundle, and start the framework. This spins up a local web server
running your "hello" function:

```sh
bundle install
# ...installs the functions_framework gem and other dependencies
bundle exec functions-framework --target hello
# ...starts the web server in the foreground
```

In a separate shell, you can send requests to this function using curl:

```sh
curl localhost:8080
# Output: Hello, world!
```

Stop the web server with `CTRL+C`.

### Deploying a function to Google Cloud Functions

(Google Cloud Functions does not yet support the Ruby Function Framework)

### Deploying a function to Cloud Run

Create a `Dockerfile` for your function:

```dockerfile
# Dockerfile
FROM ruby:2.6

WORKDIR /app
COPY . .
RUN gem install --no-document bundler \
    && bundle config --local frozen true \
    && bundle install

ENTRYPOINT ["bundle", "exec", "functions-framework"]
CMD ["--target", "hello"]
```

Build your function into a Docker image:

```sh
gcloud builds submit --tag=gcr.io/[YOUR-PROJECT]/hello:build-1
```

Deploy to Cloud Run:

```sh
gcloud run deploy hello --image=gcr.io/[YOUR-PROJECT]/hello:build-1 \
  --platform=managed --allow-unauthenticated --region=us-central1
```

You can use a similar approach to deploy to any other Knative-based serverless
environment.

### Responding to CloudEvents

You can also define a function that response to
[CloudEvents](https://cloudevents.io). The Functions Framework will handle
unmarshalling of the event data.

Change `app.rb` to read:

```ruby
# app.rb
require "functions_framework"

FunctionsFramework.event("my-handler") do |data, context|
  FunctionsFramework.logger.info "I received #{data.inspect}"
end
```

Start up the framework with this new function:

```sh
bundle install
bundle exec functions-framework --target my-handler
```

In a separate shell, you can send a CloudEvent to this function using curl:

```sh
curl --header "Content-Type: text/plain; charset=utf-8" \
     --header "CE-ID: 12345" \
     --header "CE-Source: curl" \
     --header "CE-Type: com.example.test" \
     --header "CE-Specversion: 1.0" \
     --data "Hello, world!" \
     http://localhost:8080
```

CloudEvents functions do not return meaningful results, but you will see the
log message from the web server.

### Configuring the Functions Framework

The Ruby Functions Framework recognizes the standard command line arguments to
the `functions-framework` executable. Each argument also corresponds to an
environment variable. If you specify both, the environment variable will be
ignored.

Command-line flag | Environment variable | Description
----------------- | -------------------- | -----------
`--port`          | `PORT`               | The port on which the Functions Framework listens for requests. Default: `8080`
`--target`        | `FUNCTION_TARGET`    | The name of the exported function to be invoked in response to requests. Default: `function`
`--source`        | `FUNCTION_SOURCE`    | The path to the file containing your function. Default: `app.rb` (in the current working directory)

Note: the flag `--signature-type` and corresponding environment variable
`FUNCTION_SIGNATURE_TYPE` are not used by the Ruby Function Framework, because
you specify the signature type when defining the function in the source.

The Ruby `functions-framework` executable also recognizes several additional
flags that can be used to control logging verbosity, binding, and other
parameters. For details, see the online help:

```sh
functions-framework --help
```

## For more information

 *  See the `examples` directory for additional examples
 *  Consult https://rubydoc.info/gems/functions_framework for full reference
    documentation.
