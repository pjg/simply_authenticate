require 'digest/sha1'

require 'settings'
require 'exceptions'
require 'routing'
require 'helpers'

require 'acts_as_authenticated'
require 'acts_as_authenticated_role'
require 'acts_as_authenticated_mailer'

# acts_as_authenticated & acts_as_authenticated_role for ActiveRecord's models
ActiveRecord::Base.send :include, SimplyAuthenticate::ActsAsAuthenticated
ActiveRecord::Base.send :include, SimplyAuthenticate::ActsAsAuthenticatedRole

# Helpers will be available in the views
ActionView::Base.send :include, SimplyAuthenticate::Helpers

# Helpers will be available in all controllers
ActionController::Base.send :include, SimplyAuthenticate::Helpers

# Exceptions will be available in all controllers
ActionController::Base.send :include, SimplyAuthenticate::Exceptions

# Before filters (will be run for every action in every controller) (:load_user must be THE FIRST filter)
ActionController::Base.send :prepend_before_filter, :load_user

# Filter password related parameters
ActionController::Base.send :filter_parameter_logging, :password, :password_confirmation, :old_password

# Templates for the UsersController
ActionController::Base.view_paths.push File.expand_path(File.dirname(__FILE__) + '/../app/views/')

# Named routes definitions
ActionController::Routing::RouteSet::Mapper.send :include, SimplyAuthenticate::Routing::MapperExtensions

# Notifications mailer setup
ActionMailer::Base.send :include, SimplyAuthenticate::ActsAsAuthenticatedMailer
ActionMailer::Base.template_root = File.expand_path(File.dirname(__FILE__) + '/../app/views/')
