require 'rubygems'
require 'bundler/setup'
require 'pathname'
require 'test/unit'

JRUBY = defined?(JRUBY_VERSION)

if JRUBY
  require 'jdbc/sqlite3'
  require 'active_record'
  require 'active_record/connection_adapters/jdbcsqlite3_adapter'
else
  require 'sqlite3'
end

require 'shoulda'
require 'mocha/setup'
require 'active_support/core_ext/hash/indifferent_access'

