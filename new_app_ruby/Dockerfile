FROM ruby:3.3-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential libpq-dev ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle config set without 'development test' && \
    bundle install --jobs 4 --retry 3

COPY app.rb ./
COPY public ./public
COPY views ./views
COPY open_api.yaml ./
COPY migrations ./migrations
COPY db ./db

ENV RACK_ENV=production
EXPOSE 8080

# Run migrations then start app
CMD ["sh", "-c", "bundle exec ruby db/migrate.rb && bundle exec ruby app.rb"]
