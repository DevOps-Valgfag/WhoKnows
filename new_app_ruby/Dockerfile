FROM ruby:3.2

# Create a non-root user and dedicated app directory
RUN useradd -m myuser
WORKDIR /app

# Copy dependency files and install gems
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install

# Copy the rest of the application code
COPY . .

# Change ownership of the app directory
RUN chown -R myuser:myuser /app

# Switch to the non-root user
USER myuser

EXPOSE 8080

CMD ["bundle", "exec", "ruby", "app.rb"]
