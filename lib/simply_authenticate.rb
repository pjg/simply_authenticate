require 'digest/sha1'

require 'acts_as_authenticated'
require 'acts_as_authenticated_role'
require 'exceptions'
require 'helpers'
require 'routing'
require 'settings'

# acts_as_authenticated & acts_as_authenticated_role for ActiveRecord's models
ActiveRecord::Base.send :include, SimplyAuthenticate::ActsAsAuthenticated
ActiveRecord::Base.send :include, SimplyAuthenticate::ActsAsAuthenticatedRole

# Helpers will be available in the views
ActionView::Base.send :include, SimplyAuthenticate::Helpers

# Helpers will be available in all controllers
ActionController::Base.send :include, SimplyAuthenticate::Helpers

# Exceptions will be available in all controllers
ActionController::Base.send :include, SimplyAuthenticate::Exceptions

# Before filters (will be run for every action in every controller)
ActionController::Base.send :prepend_before_filter, :load_user

# Filter password related parameters
ActionController::Base.send :filter_parameter_logging, :password, :password_confirmation, :old_password

# Named routes definitions
ActionController::Routing::RouteSet::Mapper.send :include, SimplyAuthenticate::Routing::MapperExtensions
