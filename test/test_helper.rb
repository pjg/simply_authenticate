ENV['RAILS_ENV'] = 'test'
ENV['RAILS_ROOT'] ||= File.dirname(__FILE__) + '/../../../..'

require 'test/unit'
require 'rubygems'
require 'redgreen'
require File.expand_path(File.join(ENV['RAILS_ROOT'], 'config/environment.rb'))

config = YAML::load(IO.read(File.dirname(__FILE__) + '/config/database.yml'))

Dir.mkdir(File.dirname(__FILE__) + '/log') if !File.exists?(File.dirname(__FILE__) + '/log')
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + '/log/test.log')

db_adapter =
  begin
    require 'sqlite3'
    'sqlite3'
  end

if db_adapter.nil?
  raise "Could not select database adapter. Please install Sqlite3."
end

ActiveRecord::Base.establish_connection(config[db_adapter])
load(File.dirname(__FILE__) + "/db/schema.rb")

require File.dirname(__FILE__) + '/../init.rb'
