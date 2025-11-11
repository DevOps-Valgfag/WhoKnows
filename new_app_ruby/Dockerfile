# Dockerfile beskriver hvordan image skal bygges af vores app
# Image er lig med opskriften på containeren

FROM ruby:3.3-slim

# Installerer nødvendige systempakker fx for at Ruby kan bruge SQlite
# Kommandoen no-install-recommends holder det hele på et minimum og sletter midlertidige filer efterfølgende

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential libsqlite3-0 libsqlite3-dev ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Dette er arbejdsmappen inde i containeren
WORKDIR /app

# Kopierer Ruby-afhængigheder først (Gemfile) for bedre cache.
# Hvis ikke der ændres i Gemfile, så genbruger Docker
# Medtager ikke gems der ligger i grupperne development og test
COPY Gemfile Gemfile.lock* ./
RUN bundle config set without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copy app code, denne ændres til mere specifik, så ikke docker-compose.yml og nginx.conf filerne også medtages i image
COPY app.rb ./
COPY public ./public
COPY views ./views
COPY open_api.yaml ./

# Create a writable data dir for sqlite and symlink to /app/whoknows.db
# (Your code expects DB_PATH at /app/whoknows.db; we persist it under /data)
RUN mkdir -p /data && \
    if [ ! -e /app/whoknows.db ]; then ln -s /data/whoknows.db /app/whoknows.db; fi

# Environment
ENV RACK_ENV=production

EXPOSE 8080

# Start the Sinatra app. Måske en ide at vi senere benytter PUMA?
CMD ["bundle", "exec", "ruby", "app.rb"]
