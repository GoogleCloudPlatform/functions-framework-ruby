# Functions Framework

An open source framework for writing lightweight, portable Ruby functions that
run in a serverless environment. Functions written to this Framework will run
in many different environments, including:

 *  [Google Cloud Functions](https://cloud.google.com/functions) *(coming soon)*
 *  [Cloud Run or Cloud Run for Anthos](https://cloud.google.com/run)
 *  Any other [Knative](https://github.com/knative)-based environment
 *  Your local development machine

The framework allows you to go from:

```ruby
FunctionsFrameowork.http do |request|
  "Hello, world!\n"
end
```

To:

```
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
 *  Spin up a local development server for quick testing.
 *  Integrate with standard Ruby libraries such as Rack and Minitest.
 *  Portable between serverless platforms.

## Installation

Install the Functions Framework via Rubygems:

```
$ gem install functions_framework
```

Or add it to your Gemfile for installation using Bundler:

```
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

Create a file called `app.rb` and include the following code:

```ruby
# app.rb
require "functions_framework"

FunctionsFrameowork.http do |request|
  "Hello, world!\n"
end
```

Install the bundle, and start the framework. This spins up a local web server
with your function:

```
$ bundle install
    # ...installs the functions_framework gem and other dependencies
$ bundle exec functions-framework
    # ...starts the web server in the foreground
```

In a separate shell, you can send requests to this function using curl:

```
$ curl localhost:8080
    # Output: Hello, world!
```

Stop the web server with `CTRL+C`.

### Deploying a function to Google Cloud Functions

(Google Cloud Functions does not yet support the Ruby Function Framework)

### Deploying a function to Cloud Run

Create a `Dockerfile` for your function:

```
# Dockerfile
FROM ruby:2.6

WORKDIR /app
COPY . .
RUN gem install --no-document bundler \
    && bundle config --local frozen true \
    && bundle install

ENTRYPOINT ["bundle", "exec", "functions-framework"]
```

Build your function into a Docker image:

```
$ gcloud builds submit --tag=gcr.io/[YOUR-PROJECT]/hello:build-1
```

Deploy to Cloud Run:

```
$ gcloud run deploy hello --image=gcr.io/[YOUR-PROJECT]/hello:build-1 \
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

FunctionsFrameowork.event do |data, context|
  FunctionsFramework.logger.info "I received #{data.inspect}"
end
```

Start up the framework with this new function:

```
$ bundle install
$ bundle exec functions-framework
```

In a separate shell, you can send a CloudEvent to this function using curl:

```
$ curl --header "Content-Type: text/plain; charset=utf-8" \
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

```
$ functions-framework --help
```

### For more information

See the examples directory for additional examples, and consult the gem
documentation on rubydoc.info for full reference documentation.

## Contributing

Contributions to this library are welcome and encouraged. See the CONTRIBUTING
document for more information on how to get started.

## License

Copyright 2020 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

> https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
