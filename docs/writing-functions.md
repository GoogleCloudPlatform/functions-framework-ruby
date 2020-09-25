<!--
# @title Writing Functions
-->

# Writing Functions

This guide covers writing functions using the Functions Framework for Ruby. For
more information about the Framework, see the
{file:docs/overview.md Overview Guide}.

## About functions

Functions are Ruby blocks that are run when an input is received. Those inputs
can be HTTP requests or events in a recognized format. Functions that receive
HTTP requests return an HTTP response, but event functions have no return value.

When you define a function, you must provide an identifying name. The Functions
Framework allows you to use any string as a function name; however, many
deployment environments restrict the characters that can be used in a name. For
maximum portability, it is recommended that you use names that are allowed for
Ruby methods, i.e. beginning with a letter, and containing only letters,
numbers, and underscores.

## Defining an HTTP function

An HTTP function is a simple web service that takes an HTTP request and returns
an HTTP response. The following example defines an HTTP function named "hello"
that returns a simple message in the HTTP response body:

```ruby
require "functions_framework"

FunctionsFramework.http "hello" do |request|
  # Return the response body.
  "Hello, world!\n"
end
```

HTTP functions take a Rack Request object and return an HTTP response. We'll
now cover these in a bit more detail.

### Using the Request object

An HTTP function is passed a request, which is an object of type
[Rack::Request](https://rubydoc.info/gems/rack/Rack/Request). This object
provides methods for obtaining request information such as the method,
path, query parameters, body content, and headers. You can also obtain the raw
Rack environment using the `env` method. The following example includes some
request information in the response:

```ruby
require "functions_framework"

FunctionsFramework.http "request_info_example" do |request|
  # Include some request info in the response body.
  "Received #{request.method} from #{request.url}!\n"
end
```

The Functions Framework sets up a logger in the Rack environment, so you can
use the `logger` method on the request object if you want to emit logs. These
logs will be written to the standard error stream, and will appear in the
Google Cloud Logs if your function is running on a Google Cloud serverless
hosting environment.

```ruby
require "functions_framework"

FunctionsFramework.http "logging_example" do |request|
  # Log some request info.
  request.logger.info "I received #{request.method} from #{request.url}!"
  # A simple response body.
  "ok"
end
```

### Response types

The above examples return simple strings as the response body. Often, however,
you will need to return more complex responses such as JSON, binary data, or
even rendered HTML. The Functions Framework recognizes a variety of return
types from an HTTP function:

 *  **String** : If you return a string, the framework will use it as the
    response body in with a 200 (success) HTTP status code. It will set the
    `Content-Type` header to `text/plain`.
 *  **Array** : If you return an array, the framework will assume it is a
    standard three-element Rack response array, as defined in the
    [Rack spec](https://github.com/rack/rack/blob/master/SPEC.rdoc).
 *  **Rack::Response** : You can return a
    [Rack::Response](https://rubydoc.info/gems/rack/Rack/Response) object. The
    Framework will call `#finish` on this object and retrieve the contents.
 *  **Hash** : If you return a Hash, the Framework will attempt to encode it as
    JSON, and return it in the response body with a 200 (success) HTTP status
    code. The `Content-Type` will be set to `application/json`.
 *  **StandardError** : If you return an exception object, the Framework will
    return a 500 (server error) response. See the section below on
    Error Handling.

### Using Sinatra

The Functions Framework, and the functions-as-a-service (FaaS) solutions it
targets, are optimized for relatively simple HTTP requests such as webhooks and
simple APIs. If you want to deploy a large application or use a monolithic
framework such as Ruby on Rails, you may want to consider a solution such as
Google Cloud Run that is tailored to larger applications. However, a lightweight
framework such as Sinatra is sometimes useful when writing HTTP functions.

It is easy to connect an HTTP function to a Sinatra app. First, declare the
dependency on Sinatra in your `Gemfile`:

```ruby
source "https://rubygems.org"
gem "functions_framework", "~> 0.7"
gem "sinatra", "~> 2.0"
```

Write the Sinatra app using the "modular" Sinatra interface (i.e. subclass
`Sinatra::Base`), and then run the Sinatra app directly as a Rack handler from
the function. Here is a basic example:

```ruby
require "functions_framework"
require "sinatra/base"

class App < Sinatra::Base
  get "/hello/:name" do
    "Hello, #{params[:name]}!"
  end
end

FunctionsFramework.http "sinatra_example" do |request|
  App.call request.env
end
```

This technique gives you access to pretty much any feature of the Sinatra web
framework, including routes, templates, and even custom middleware.

## Defining an Event function

An event function is a handler for a standard cloud event. It can receive
industry-standard [CloudEvents](https://cloudevents.io), as well as events sent
by Google Cloud services such as [Pub/Sub](https://cloud.google.com/pubsub) and
[Storage](https://cloud.google.com/storage). Event functions do not have a
return value.

The following is a simple event handler that receives an event and logs some
information about it:

```ruby
require "functions_framework"

FunctionsFramework.cloud_event "hello" do |event|
  FunctionsFramework.logger.info "I received an event of type #{event.type}!"
end
```

The event parameter will be either a
[CloudEvents V0.3 Event](https://cloudevents.github.io/sdk-ruby/latest/CloudEvents/Event/V0)
object ([see spec](https://github.com/cloudevents/spec/blob/v0.3/spec.md)) or a
[CloudEvents V1.0 Event](https://cloudevents.github.io/sdk-ruby/latest/CloudEvents/Event/V1)
object ([see spec](https://github.com/cloudevents/spec/blob/v1.0/spec.md)).

Some Google Cloud services send events in a legacy event format that was defined
prior to CloudEvents. The Functions Framework will convert these legacy events
to an equivalent CloudEvents V1 type, so your function will always receive a
CloudEvent object when it is sent an event from Google Cloud. The precise
mapping between legacy events and CloudEvents is not specified in detail here,
but in general, the _data_ from the legacy event will be mapped to the `data`
field in the CloudEvent, and the _context_ from the legacy event will be mapped
to equivalent CloudEvent attributes.

## Error handling

If your function encounters an error, it can raise an exception. The Functions
Framework will catch `StandardError` exceptions and handle them appropriately.

If you raise an exception in an HTTP function, the Functions Framework will
return a 500 (server error) response. You can control whether the exception
details (e.g. exception type, message, and backtrace) are sent with the
response by setting the detailed-errors configuration in the server. The
Framework will also log the error for you.

If you need more control over the error response, you can also construct the
HTTP response yourself. For example:

```ruby
require "functions_framework"

FunctionsFramework.http "error_reporter" do |request|
  begin
    raise "whoops!"
  rescue RuntimeError => e
    [500, {}, ["Uh, oh, got an error message: #{e.message}."]]
  end
end
```

## The runtime environment

A serverless environment may be somewhat different from server-based runtime
environments you might be used to. Serverless runtimes often provide a simpler
programming model, transparent scaling, and cost savings, but they do so by
controlling how your code is managed and executed. The Functions Framework is
designed around a "functions-as-a-service" (FaaS) paradigm, which runs
self-contained stateless functions that have an input and a return value. It's
important to understand what that means for your Ruby code in order to get the
most out of a cloud serverless product.

For example, multithreading is a core element of the Functions Framework. When
you write functions, you should assume that multiple executions may be taking
place concurrently in different threads, and thus you should avoid operations
that can cause concurrency issues or race conditions. The easiest way to do
this is to make your functions self-contained and stateless. Avoid global
variables and don't share mutable data between different function executions.

Additionally, a serverless runtime may throttle the CPU whenever no actual
function executions are taking place. This lets it reduce the CPU resources
used (and therefore the cost to you), while keeping your application warmed up
and ready to respond to new requests quickly. An important implication, though,
is that you should avoid starting up background threads or processes. They may
not get any CPU time during periods when your Ruby application is not actually
executing a function.

In the sections below, we'll discuss a few techniques and features of the
Functions Framework to help you write Ruby code that fits well into a
serverless paradigm.

### Startup tasks

It is sometimes useful to perform one-time initialization that applies to many
function executions, for example to warm up caches, perform precomputation, or
establish shared remote connections. To run code during initialization, use
{FunctionsFramework.on_startup} to define a _startup task_.

```ruby
require "functions_framework"

FunctionsFramework.on_startup do |function|
  # Perform initialization here.
  require "my_cache"
  MyCache.warmup
end

FunctionsFramework.http "hello" do |request|
  # Initialization will be done by the time a normal function is called.
end
```

Startup tasks are run once per Ruby instance, before the framework starts
receiving requests and executing functions. You can define multiple startup
tasks, and they will run in order, and are guaranteed to complete before any
function is executed.

The block is optionally passed the {FunctionsFramework::Function} representing
the function that will be run. You code can, for example, perform different
initialization depending on the {FunctionsFramework::Function#name} or
{FunctionsFramework::Function#type}.

**In most cases, initialization code should live in an `on_startup` block
instead of at the "top level" of your Ruby file.** This is because some
serverless runtimes may load your Ruby code at build or deployment time (for
example, to verify that it properly defines the requested function), and this
will execute any code present at the top level of the Ruby file. If top-level
code is long-running or depends on runtime resources or environment variables,
this could cause the deployment to fail. By performing initialization in an
`on_startup` block instead, you ensure it will run only when an actual runtime
server is starting up, not at build/deployment time.

```ruby
require "functions_framework"

# DO NOT perform initialization here because this could get run at build time.
#   require "my_cache"
#   MyCache.warmup

# Instead initialize in an on_startup block, which is executed only when a
# runtime server is starting up.
FunctionsFramework.on_startup do
  # Perform initialization here.
  require "my_cache"
  MyCache.warmup
end

# ...
```

### The execution context and global data

When your function block executes, the _object context_ (i.e. `self`) is set to
an instance of {FunctionsFramework::Function::Callable}. Each function
invocation (including functions that might be running concurrently in separate
threads) runs within a different instance, to help you avoid having functions
interfere with each other.

The object context also defines a few methods that may be useful when writing
your function.

First, you can obtain the logger by calling the
{FunctionsFramework::Function::Callable#logger} convenience method. This is
the same logger that is provided by the HTTP request object or by the
{FunctionsFramework.logger} global method.

Second, you can access global shared data by passing a key to
{FunctionsFramework::Function::Callable#global}. _Global shared data_ is a set
of key-value pairs that are available to every function invocation. By default,
two keys are available to all functions:

 *  `:function_name` whose String value is the name of the running function.
 *  `:function_type` whose value is either `:http` or `:cloud_event` depending
    on the type of the running function.

Following is a simple example using the `logger` and `global` methods of the
context object:

```ruby
require "functions_framework"

FunctionsFramework.cloud_event "hello" do |event|
  logger.info "Now running the function called #{global(:function_name)}"
end
```

To avoid concurrency issues, global shared data is immutable when executing a
function. You cannot add or delete keys or change the value of existing keys.
However, the global data is settable during startup tasks, because startup
tasks never run concurrently. You can use this feature to initialize shared
resources, as described below.

Using the global data mechanism is generally preferred over actual Ruby global
variables, because the Functions Framework can help you avoid concurrent edits.
Additionally, the framework will isolate the sets of global data associated
with different sets of functions, which lets you test functions in isolation
without the tests interfering with one another by writing to global variables.

### Sharing resources

Although functions should generally be self-contained and stateless, it is
sometimes useful to share certain kinds of resources across multiple function
invocations that run on the same Ruby instance. For example, you might
establish a single connection to a remote database or other service, and share
it across function invocations to avoid incurring the overhead of
re-establishing it for every function invocation.

The best practice for sharing a resource across function invocations is to
initialize it in a {FunctionsFramework.on_startup} block, and reference it from
global shared data. (As discussed above, prefer to initialize shared resources
in a startup task rather than at the top level of a Ruby file, and prefer using
the Functions Framework's global data mechanism rather than Ruby's global
variables.)

Here is a simple example:

```ruby
require "functions_framework"

# Use an on_startup block to initialize a shared client and store it in
# the global shared data.
FunctionsFramework.on_startup do
  require "google/cloud/storage"
  set_global :storage_client, Google::Cloud::Storage.new
end

# The shared storage_client can be accessed by all function invocations
# via the global shared data.
FunctionsFramework.http "storage_example" do |request|
  bucket = global(:storage_client).bucket "my-bucket"
  file = bucket.file "path/to/my-file.txt"
  file.download.to_s
end
```

Importantly, if you do share a resource across function invocations, make sure
the resource is thread-safe, so that separate functions running concurrently in
different threads can access them safely. The API clients provided by Google,
for example, are thread-safe and can be used concurrently.

Also of note: There is no guaranteed cleanup hook. The Functions Framework does
not provide a way to register a cleanup task, and we recommend against using
resources that require explicit "cleanup". This is because serverless runtimes
may perform CPU throttling, and therefore there may not be an opportunity for
cleanup tasks to run. (For example, you could register a `Kernel.at_exit` task,
but the Ruby VM may still terminate without calling it.)

## Structuring a project

A Functions Framework based "project" or "application" is a typical Ruby
application. It should include a `Gemfile` that specifies the gem dependencies
(including the `functions_framework` gem itself), and any other dependencies
needed by the function. It must include at least one Ruby source file that
defines functions, and can also include additional Ruby files defining classes
and methods that assist in the function implementation.

By convention, the "main" Ruby file that defines functions should be called
`app.rb` and be located at the root of the project. The path to this file is
sometimes known as the **function source**. The Functions Framework allows you
to specify an arbitrary source, but some hosting environments (such as Google
Cloud Functions) require it to be `./app.rb`.

A source file can define any number of functions (with distinct names). Each of
the names is known as a **function target**.

Following is a typical layout for a Functions Framework based project.

```
(project directory)
|
+- Gemfile
|
+- app.rb
|
+- lib/
|  |
|  +- hello.rb
|
+- test/
   |
   ...
```

```ruby
# Gemfile
source "https://rubygems.org"
gem "functions_framework", "~> 0.7"
```

```ruby
# app.rb
require "functions_framework"

FunctionsFramework.on_startup do
  require_relative "lib/hello"
end

FunctionsFramework.http "hello" do |request|
  Hello.new(request).build_response
end
```

```ruby
# lib/hello.rb
class Hello
  def initialize request
    @request = request
  end

  def build_response
    "Received request: #{request.method} #{request.url}\n"
  end
end
```

## Next steps

To learn about writing unit tests for functions, see
{file:docs/testing-functions.md Testing Functions}.

To learn how to run your functions in a server, see
{file:docs/running-a-functions-server.md Running a Functions Server}.

To learn how to deploy your functions to Google Cloud Functions or Google Cloud
Run, see
{file:docs/deploying-functions.md Deploying Functions}.
