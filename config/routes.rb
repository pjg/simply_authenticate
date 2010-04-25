ActionController::Routing::Routes.draw do |map|
  controller = SimplyAuthenticate::Settings.controller_name
  path_names = SimplyAuthenticate::Settings.path_names

  # user actions
  map.register                   "#{path_names[:register_path]}",                   :controller => controller, :action => 'register'
  map.activate_account           "#{path_names[:activate_account_path]}",           :controller => controller, :action => 'activate_account', :activation_code => nil
  map.send_activation_code       "#{path_names[:send_activation_code_path]}",       :controller => controller, :action => 'send_activation_code'
  map.login                      "#{path_names[:login_path]}",                      :controller => controller, :action => 'login'
  map.forgot_password            "#{path_names[:forgot_password_path]}",            :controller => controller, :action => 'forgot_password'
  map.profile                    "#{path_names[:profile_path]}",                    :controller => controller, :action => 'profile'
  map.change_password            "#{path_names[:change_password_path]}",            :controller => controller, :action => 'change_password'
  map.change_email_address       "#{path_names[:change_email_address_path]}",       :controller => controller, :action => 'change_email_address'
  map.activate_new_email_address "#{path_names[:activate_new_email_address_path]}", :controller => controller, :action => 'activate_new_email_address', :new_email_activation_code => nil
  map.logout                     "#{path_names[:logout_path]}",                     :controller => controller, :action => 'logout'

  # administratior actions
  map.users                      "#{path_names[:users_path]}",                      :controller => controller
  map.user_show                  "#{path_names[:user_show_path]}",                  :controller => controller, :action => 'show'
  map.user_edit                  "#{path_names[:user_edit_path]}",                  :controller => controller, :action => 'edit'
end
