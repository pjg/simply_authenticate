ENV['RAILS_ENV'] = 'test'
ENV['RAILS_ROOT'] ||= File.dirname(__FILE__) + '/../../../..'

require 'test/unit'
require 'rubygems'
require 'redgreen'

# Load Rails
require File.expand_path(File.join(ENV['RAILS_ROOT'], 'config/environment.rb'))


# Setup database
config = YAML::load(IO.read(File.dirname(__FILE__) + '/config/database.yml'))

Dir.mkdir(File.dirname(__FILE__) + '/log') if !File.exists?(File.dirname(__FILE__) + '/log')
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + '/log/test.log')

db_adapter =
  begin
    require 'sqlite3'
    'sqlite3'
  end

if db_adapter.nil?
  raise "Could not select the database adapter. Please install Sqlite3."
end

ActiveRecord::Base.establish_connection(config[db_adapter])
load(File.dirname(__FILE__) + "/db/schema.rb")


# Load the plugin
require File.dirname(__FILE__) + '/../init.rb'


# Setup fixtures
require 'active_support/test_case'
require 'active_record/fixtures'

Test::Unit::TestCase.fixture_path = File.dirname(__FILE__) + "/fixtures"

class Test::Unit::TestCase
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = true
  fixtures :all
end


# Setup models
class Role < ActiveRecord::Base
  acts_as_authenticated_role
end

class User < ActiveRecord::Base
  acts_as_authenticated
end

# STUB options (so we can run tests)
class Option < ActiveRecord::Base
end
