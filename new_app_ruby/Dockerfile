# Ruby with build tools
FROM ruby:3.3-slim

# Install system deps for sqlite3 & building native gems
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential libsqlite3-0 libsqlite3-dev ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Pre-copy gem manifests for caching
COPY Gemfile Gemfile.lock* ./
RUN bundle config set without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copy app code
COPY . .

# Create a writable data dir for sqlite and symlink to /app/whoknows.db
# (Your code expects DB_PATH at /app/whoknows.db; we persist it under /data)
RUN mkdir -p /data && \
    if [ ! -e /app/whoknows.db ]; then ln -s /data/whoknows.db /app/whoknows.db; fi

# Environment
ENV RACK_ENV=production

EXPOSE 8080

# Start the Sinatra app
CMD ["bundle", "exec", "ruby", "app.rb"]
