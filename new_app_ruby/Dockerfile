FROM ruby:3.2

WORKDIR /app

COPY . .

RUN gem install bundler && bundle install

EXPOSE 8080

CMD ["bundle", "exec", "ruby", "app.rb"]
