<!--
# @title Running a Functions Server
-->

# Running a Functions Server

This guide covers how to use the `functions-framework-ruby` executable to launch
a functions server hosting Ruby functions written for the Functions Framework.
For more information about the Framework as a whole, see the
{file:docs/overview.md Overview Guide}.

## Running functions locally

The `functions-framework-ruby` command-line executable is used to run a
functions server. This executable is installed with the `functions_framework`
gem, and can be run with `bundle exec`. It wraps your function in a web server
request handler, and runs it in the [Puma](https://puma.io/) web server.

Pass the name of the function to run in the `--target` option. By default,
`functions-framework-ruby` will load functions from the file `app.rb` in the
current directory. If you want to load functions from a different file, use the
`--source` option.

```sh
bundle install
bundle exec functions-framework-ruby --source=foo.rb --target=hello
```

You can now send requests to your function. e.g.

```sh
curl http://localhost:8080/
```

The executable will write logs to the standard error stream while it is running.
To stop the server, hit `CTRL+C` or otherwise send it an appropriate signal.
The executable has no "background" or "daemon" mode. To run it in the background
from a shell, use the shell's background syntax (such as appending `&` to the
command).

By default, the executable will listen on the port specified by the `$PORT`
environment variable, or port 8080 if the variable is not set. You can also
override this by passing the `--port` option. A number of other options are
also available. See the section below on configuring the server, or pass
`--help` to the executable to display online help.

## Running functions in Docker

The `functions-framework-ruby` executable is designed to be run in a Docker
container. This is how it is run in some container-based hosting services such
as Google Cloud Run, but you can also run it in Docker locally.

First, write a Dockerfile for your project. Following is a simple starting
point; feel free to adjust it to the needs of your project:

```
FROM ruby:2.6
WORKDIR /app
COPY . .
RUN gem install --no-document bundler \
    && bundle config --local frozen true \
    && bundle config --local without "development test" \
    && bundle install
ENV PORT=8080
ENTRYPOINT ["bundle", "exec", "functions-framework-ruby"]
```

Build an image for your project using the Dockerfile.

```sh
docker build --tag my-image .
```

Then, you can run the Docker container locally as follows:

```sh
docker run --rm -it -p 8080:8080 my-image --source=foo.rb --target=hello
```

The arguments after the image name (e.g. `--source` and `--target` in the above
example) are passed to the `functions-framework-ruby` executable.

Because the docker container above maps port 8080 internally to port 8080
externally, you can use that port to send requests to your function. e.g.

```sh
curl http://localhost:8080/
```

You can stop the running Docker container with `CTRL+C` or by sending an
appropriate signal.

## Configuring the server

The Ruby Functions Framework recognizes the following command line arguments to
the `functions-framework-ruby` executable. Each argument also corresponds to an
environment variable. If you specify both, the flag takes precedence.

Command-line flag   | Environment variable       | Description
-----------------   | --------------------       | -----------
`--port`            | `PORT`                     | The port on which the Functions Framework listens for requests. Default: `8080`.
`--target`          | `FUNCTION_TARGET`          | The name of the exported function to be invoked in response to requests. Default: `function`.
`--source`          | `FUNCTION_SOURCE`          | The path to the file containing your function. Default: `app.rb` (in the current working directory).
`--signature-type`  | `FUNCTION_SIGNATURE_TYPE`  | Verifies that the function has the expected signature. Allowed values: `http` or `cloudevent`.
`--environment`     | `RACK_ENV`                 | Sets the Rack environment.
`--bind`            | `FUNCTION_BIND_ADDR`       | Binds to the given address. Default: `0.0.0.0`.
`--min-threads`     | `FUNCTION_MIN_THREADS`     | Sets the minimum thread pool size, overriding Puma's default.
`--max-threads`     | `FUNCTION_MAX_THREADS`     | Sets the maximum thread pool size, overriding Puma's default.
`--detailed-errors` | `FUNCTION_DETAILED_ERRORS` | No value. If present, shows exception details in exception responses. Defaults to false.
`--verbose`         | `FUNCTION_LOGGING_LEVEL`   | No value. Increases log verbosity (e.g. from INFO to DEBUG). Can be given more than once.
`--quiet`           | `FUNCTION_LOGGING_LEVEL`   | No value. Decreases log verbosity (e.g. from INFO to WARN). Can be given more than once.

Detailed errors are enabled by default if the `FUNCTION_DETAILED_ERRORS`
environment variable is set to a _non-empty_ string. The exact value does not
matter. Detailed errors are disabled if the variable is unset or empty.

The logging level defaults to the value of the `FUNCTION_LOGGING_LEVEL`
environment variable, which can be one of the following values: `DEBUG`, `INFO`,
`WARN`, `ERROR`, `FATAL`, or `UNKNOWN`, corresponding to Ruby's
[Logger::Severity](https://ruby-doc.org/stdlib/libdoc/logger/rdoc/Logger/Severity.html)
constants. If `FUNCTION_LOGGING_LEVEL` is not set to one of those values, it
defaults to `INFO`.
