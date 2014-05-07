source 'https://rubygems.org'

# Specify your gem's dependencies in elastic-rebound.gemspec
gemspec

gem 'sidekiq'
gem 'elasticsearch'
gem 'hashie'

platform :jruby do
  gem "jdbc-sqlite3"
  gem "activerecord-jdbcsqlite3-adapter"
  gem "json" if defined?(RUBY_VERSION) && RUBY_VERSION < '1.9'
end
