FROM ruby:4.0.9-slim AS build
WORKDIR /rails
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config && rm -rf /var/lib/apt/lists/*
ENV BUNDLE_PATH=/usr/local/bundle BUNDLE_WITHOUT=development:test BUNDLE_DEPLOYMENT=1
COPY Gemfile Gemfile.lock ./
RUN bundle install && rm -rf /usr/local/bundle/ruby/*/cache
COPY . .
RUN SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bundle exec rails assets:precompile
FROM ruby:4.0.9-slim
WORKDIR /rails
RUN apt-get update -qq && apt-get install --no-install-recommends -y libyaml-0-2 curl sqlite3 && rm -rf /var/lib/apt/lists/* && groupadd --gid 1000 rails && useradd --uid 1000 --gid 1000 --create-home rails
ENV RAILS_ENV=production BUNDLE_PATH=/usr/local/bundle BUNDLE_WITHOUT=development:test BUNDLE_DEPLOYMENT=1 PORT=3000
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /rails /rails
USER rails
EXPOSE 3000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
