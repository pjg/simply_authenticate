ENV['RAILS_ENV'] = 'test'
ENV['RAILS_ROOT'] ||= File.dirname(__FILE__) + '/../../../..'

require 'test/unit'
require 'rubygems'

# Optional gems
begin
  require 'redgreen'
rescue LoadError
end

# Load Rails
require File.expand_path(File.join(ENV['RAILS_ROOT'], 'config/environment.rb'))

# Setup the database
config = YAML::load(IO.read(File.dirname(__FILE__) + '/config/database.yml'))

Dir.mkdir(File.dirname(__FILE__) + '/log') if !File.exists?(File.dirname(__FILE__) + '/log')
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + '/log/test.log')

db_adapter =
  begin
    require 'sqlite3'
    'sqlite3'
  end

if db_adapter.nil?
  raise "Could not select the database adapter. Please install Sqlite3 (gem install sqlite3-ruby)."
end


ActiveRecord::Base.establish_connection(config[db_adapter])

# We are loading the APPLICATION's database schema for testing
# This way we can test that the integration with the application is ok
# And we don't have to redefine the schema just for the plugin
load(File.expand_path(File.join(ENV['RAILS_ROOT'], 'db/schema.rb')))


# Load the plugin
require File.dirname(__FILE__) + '/../init.rb'


# Setup fixtures
require 'active_support/test_case'
require 'active_record/fixtures'

# But we are using the plugin's fixtures
Test::Unit::TestCase.fixture_path = File.dirname(__FILE__) + "/fixtures"

class Test::Unit::TestCase
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = true
  fixtures :all
end
