# Sinatra Function Example

This example includes an HTTP function that uses Sinatra to handle the request.
It demonstrates how to use a web framework to assist you with writing HTTP
functions.

While the Functions Framework and Google Cloud Functions _can_ be used to serve
large applications using heavyweight web frameworks such as Ruby On Rails, they
are not designed primarily for those cases. If you are interested in serverless
hosting for your large application, we recommend considering Google Cloud Run
or Google App Engine.

## About the example

This app includes a single HTTP function called `sinatra_example`. This
function delegates to a Sinatra app to handle requests. You should normally use
the "modular" interface (i.e. creating a subclass of `Sinatra::Base`) to write
your app, so that you can call it explicitly from the function. Otherwise, you
can use any feature of the Sinatra web framework, including routes, templates,
and even custom middleware.

Both the function and the Sinatra app are in the `app.rb` source file. There
are also example unit tests for the function, which you can find in the
`test/test_app.rb` source file.

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

To perform integration tests of the functions, start the server in a shell by
running:

```sh
toys server
```

Then, in a separate shell, you can send requests to it:

```sh
toys request
# or
toys request --path /hello/Sinatra
```

Hit `CTRL`+`C` to stop a running server.

## Running the examples in Docker

To test a server running in a Docker container, you need to build the Docker
image and then run it.

To build the image:

```sh
toys image build
```

Then you can run it in Docker:

```sh
toys image server
```

Again, use `toys request` to send example requests.

## Deploying to Cloud Run

To deploy to Cloud Run, first create a project and enable billing. You will
also need to install the [Google Cloud SDK](https://cloud.google.com/sdk) if
you have not already done so.

Then run the `toys run deploy` command:

```sh
toys run deploy --project=[PROJECT NAME] 
```

It may ask you for permission to enable the Cloud Build and Cloud Run APIs for
the project, if you haven't already done so.

The `--project` argument can be omitted if you have set it as your default
project using `gcloud config`.

At the end of the deployment process, the command will display the hostname for
the Cloud Run service. Use that hostname to send requests via the command
`toys run request`. For example:

```sh
toys run request sinatra-abcdefghij-uc.a.run.app --path=/hello/Sinatra
```
