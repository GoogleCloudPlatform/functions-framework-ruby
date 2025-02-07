<!--
# @title Deploying Functions
-->

# Deploying Functions

This guide covers how to deploy your Ruby functions written with the Functions
Framework. Functions can be deployed to
[Google Cloud Functions](https://cloud.google.com/functions), Google's
Functions-as-a-service (FaaS) product, to
[Google Cloud Run](https://cloud.google.com/run). Google's container-based
serverless environment, or to any KNative-based environment.
For more information about the Framework as a whole, see the
{file:docs/overview.md Overview Guide}.

## Before you begin

To deploy to Google Cloud, whether to Cloud Functions or Cloud Run, you'll need
a Google Cloud project with billing enabled. Go to the
[Google Cloud console](https://console.cloud.google.com/), create a project (or
select an existing project), and ensure billing is enabled.

Additionally, install the [Google Cloud SDK](https://cloud.google.com/sdk) if
you haven't done so previously.

## Deploying to Cloud Functions

Google Cloud Functions is Google's scalable pay-as-you-go Functions-as-a-Service
(FaaS) environment that can run your function with zero server management. The
Functions Framework is designed especially for functions that can be hosted on
Cloud Functions.

You can run Ruby functions on Google Cloud Functions by selecting the `ruby32`
runtime or `ruby33` runtime to use a recent release of Ruby 3.2 or Ruby 3.3.
Support for Ruby 3.4 is forthcoming.

### Deploying and updating your function

Before you can deploy to Cloud Functions, make sure your bundle, and in
particular your `Gemfile.lock` file, is up to date. The easiest way to do this
is to `bundle install` or `bundle update` and run your local tests prior to
deploying. Cloud Functions will not accept your function unless an up-to-date
`Gemfile.lock` is present.

Also, make sure your source file (which defines your function) is called
`app.rb`. The Functions Framework lets you choose a function source file, but
Cloud Functions currently requires you to use `app.rb`.

Decide _which_ function in the source file to invoke, that is, the name that you
used when writing the function. This is called the **target**. (Note that if you
did not specify a name for the function, it defaults to the name `function`.)

Choose a Cloud Functions **name** for your function. The **name** identifies
this function deployment (e.g. in the cloud console) and is also part of the
function's default URL. (Note: the **name** and the **target** do not have to
be the same value.)

Then, issue the gcloud command to deploy:

```sh
gcloud functions deploy $YOUR_FUNCTION_NAME \
    --project=$YOUR_PROJECT_ID \
    --runtime=ruby33 \
    --trigger-http \
    --entry-point=$YOUR_FUNCTION_TARGET
```

The `--entry-point=` flag can be omitted if the **target** has the same value
as the **name**. Additionally, the `--project` flag can be omitted if you've
set your default project using `gcloud config set project`.

If your function handles events rather than HTTP requests, you'll need to
replace `--trigger-http` with a different trigger. For details, see the
[reference documentation](https://cloud.google.com/sdk/gcloud/reference/functions/deploy)
for `gcloud functions deploy`.

To update your deployment, just redeploy using the same function **name**.

### Configuring Cloud Functions deployments

The Functions Framework provides various configuration parameters, described in
{file:docs/running-a-functions-server.md Running a Functions Server}.
If you want to set any of these parameters beyond the source file and target,
you must set environment variables. For example, to limit logging to WARN level
and above, set `FUNCTION_LOGGING_LEVEL` to `WARN` when deploying:

```sh
gcloud functions deploy $YOUR_FUNCTION_NAME --project=$YOUR_PROJECT_ID \
  --runtime=ruby33 --trigger-http --source=$YOUR_FUNCTION_SOURCE \
  --entry-point=$YOUR_FUNCTION_TARGET \
  --set-env-vars=FUNCTION_LOGGING_LEVEL=WARN
```

Consult the table in
{file:docs/running-a-functions-server.md Running a Functions Server}
for a list of the environment variables that can be set.

## Deploying to Cloud Run

Google Cloud Run is Google's managed compute platform for deploying and scaling
containerized applications quickly and securely. It can run any container-based
workload, including a containerized function.

Cloud Run has a hosted fully-managed option that runs on Google's infrastructure
and monitors and scales your application automatically, and a self-managed or
on-prem option called Cloud Run for Anthos that runs atop Kubernetes. Both
flavors use the same general interface and can run functions in the same way.
This tutorial is written for the managed option, but it should not be difficult
to adapt it if you have an Anthos installation.

### Building an image for your function

Before you can deploy to Cloud Run, make sure your bundle, and in
particular your `Gemfile.lock` file, is up to date. The easiest way to do this
is to `bundle install` or `bundle update` and run your local tests prior to
deploying. The configuration used in the Dockerfile below will not accept your
function unless an up-to-date `Gemfile.lock` is present.

First, build a Docker image containing your function. Following is a simple
Dockerfile that you can use as a starting point. Feel free to adjust it to the
needs of your project:

```
FROM ruby:3.3
WORKDIR /app
COPY . .
RUN gem install --no-document bundler \
    && bundle config --local frozen true \
    && bundle config --local without "development test" \
    && bundle install
ENTRYPOINT ["bundle", "exec", "functions-framework-ruby"]
```

You can test your image locally using the steps described under
{file:docs/running-a-functions-server.md Running a Functions Server}.

When your Dockerfile is ready, you can use
[Cloud Build](https://cloud.google.com/cloud-build) to build it and store the
image in your project's container registry.

```sh
gcloud builds submit --tag=gcr.io/$YOUR_PROJECT_ID/$YOUR_APP_NAME:$YOUR_BUILD_ID .
```

You must use your project ID, but you can choose an app name and build ID. The
command may ask you for permission to enable the Cloud Build API for the project
if it isn't already enabled.

Because you provide your own Docker image when deploying to Cloud Run, you can
use any version of Ruby supported by the Functions Framework, from 3.0 through
3.3.

### Deploying an image to Cloud Run

To deploy to Cloud Run, specify the same image URL that you built above. For
example:

```sh
gcloud run deploy $YOUR_APP_NAME --project=$YOUR_PROJECT_ID \
  --image=gcr.io/$YOUR_PROJECT_ID/$YOUR_APP_NAME:$YOUR_BUILD_ID \
  --platform=managed --allow-unauthenticated --region=us-central1 \
  --set-env-vars=FUNCTION_SOURCE=$YOUR_SOURCE,FUNCTION_TARGET=$YOUR_TARGET
```

You can omit the `--project` flag if you've already set it as the default with
`gcloud config set project`.

The command may ask you for permission to enable the Cloud Run API for the
project, if it isn't already enabled.

At the end of the deployment process, the command will display the hostname for
the Cloud Run service. You can use that hostname to send test requests to your
deployed function.

### Configuring Cloud Run deployments

Note that our Dockerfile's entrypoint did not pass any source file or target
name to the Functions Framework. If these are not specified, the Framework will
use the source `./app.rb` and the target `function` by default. To use different
values, you need to set the appropriate environment variables when deploying, as
illustrated above with the `FUNCTION_SOURCE` and `FUNCTION_TARGET` variables.

Source and target are not the only configuration parameters available. The
various parameters, along with their environment variables, are described in
{file:docs/running-a-functions-server.md Running a Functions Server}.
Any of these can be specified in the `--set-env-vars` flag when you deploy to
Google Cloud Run.

It is also possible to "hard-code" configuration into the Dockerfile, by setting
environment variables in the Dockerfile, or adding flags to the entrypoint.
However, it is often better practice to keep your Dockerfile "generic", and set
configuration environment variables during deployment, so that you do not need
to rebuild your Docker image every time you want to change configuration.
