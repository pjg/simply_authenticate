# temporary Role model so that the dynamic function definitions work
class TemporaryRoleModel < ActiveRecord::Base
  set_table_name 'roles'
end
