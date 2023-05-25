FROM ruby:2.6@sha256:a79c8ddb7f3d3748427e2d3a45dcae6d42f1d80d9ae3b98959b3a27b220bf434

WORKDIR /app
COPY . .
RUN gem install --no-document bundler \
    && bundle config --local frozen true \
    && bundle config --local without "development test" \
    && bundle install

ENTRYPOINT ["bundle", "exec", "functions-framework-ruby"]
