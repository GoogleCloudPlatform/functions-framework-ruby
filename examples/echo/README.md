# Echo function example

This example incudes simple HTTP and CloudEvents functions that echo the
request. It serves as an introductory example of function writing, and as an
acceptance test for the Function Framework itself.

Note that the examples can be run by either a released functions_framework gem
or by the current local source of the Functions Framework.

## About the examples

There are two example functions, an HTTP function called `http_sample` and a
CloudEvents function called `event_sample`.

The HTTP function generates a simple message saying it received the request.
It logs this message, and sends it as the response body.

The CloudEvents function also generates a simple message saying it received the
event. It logs the message, but does not return it because CloudEvents
functions have no response.

See the `app.rb` source file.

There are also example unit tests for these functions, which you can find in
the `test/test_app.rb` source file.

## Running the examples

Although you can build, deploy, and run the examples yourself, you might find
it easier to use the provided Toys scripts.

To run the commands here, first install Toys:

```sh
gem install toys
```

Each of the `toys` commands below supports online help; just add `--help` to
the command for more information about the options available.

You can also pass the verbose flag `-v` to any `toys` command, to show more
info about what it is doing internally.

### Running unit tests

To run unit tests, run the "test" toys script:

```sh
toys test
```

### Running the examples locally

To perform integration tests of the functions, start the server in a shell, and
pass the name of the function to run (either `http_sample` or `event_sample`).

Here is how to serve the HTTP sample function:

```sh
toys server http_sample
```

Then, in a separate shell, you can send requests to it:

```sh
toys request
```

To serve the event sample function:

```sh
toys server event_sample
```

Then, in a separate shell, you can send events to it:

```sh
toys event
```

Hit `CTRL`+`C` to stop a running server.

## Running the examples in Docker

To test a server running in a Docker container, you need to build the Docker
image and then run it.

To build the image:

```sh
toys image build
```

Then you can run it in Docker by passing the function name to
`toys image server`, as below:

```sh
toys image server http_sample
```

Again, use `toys request` or `toys event` to send example requests.

## Deploying to Cloud Run

To deploy to Cloud Run, first create a project and enable billing. Then run the
`toys run deploy` command, providing the function name, and the project. For
example:

```sh
toys run deploy http_sample --project=[PROJECT NAME] 
```

It may ask you for permission to enable the Cloud Build and Cloud Run APIs for
the project, if you haven't already done so.

The `--project` argument can be omitted if you have set it as your default
project using `gcloud config`.

At the end of the deployment process, the command will display the hostname for
the Cloud Run service. Use that hostname to send requests via the commands
`toys run request` or `toys run event`. For example:

```sh
toys run request echo-abcdefghij-uc.a.run.app
```
