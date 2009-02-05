module SimplyAuthenticate
  module Routing
    module MapperExtensions
      def simply_authenticate_routes
        controller = SimplyAuthenticate::Settings.controller_name
        path_names = SimplyAuthenticate::Settings.path_names

        # user actions
        @set.add_named_route('register',                     "#{path_names[:register_path]}",                   {:controller => controller, :action => 'register'})
        @set.add_named_route('activate_account',             "#{path_names[:activate_account_path]}",           {:controller => controller, :action => 'activate_account', :activation_code => nil})
        @set.add_named_route('send_activation_code',         "#{path_names[:send_activation_code_path]}",       {:controller => controller, :action => 'send_activation_code'})
        @set.add_named_route('login',                        "#{path_names[:login_path]}",                      {:controller => controller, :action => 'login'})
        @set.add_named_route('forgot_password',              "#{path_names[:forgot_password_path]}",            {:controller => controller, :action => 'forgot_password'})
        @set.add_named_route('profile',                      "#{path_names[:profile_path]}",                    {:controller => controller, :action => 'profile'})
        @set.add_named_route('change_password',              "#{path_names[:change_password_path]}",            {:controller => controller, :action => 'change_password'})
        @set.add_named_route('change_email_address',         "#{path_names[:change_email_address_path]}",       {:controller => controller, :action => 'change_email_address'})
        @set.add_named_route('activate_new_email_address',   "#{path_names[:activate_new_email_address_path]}", {:controller => controller, :action => 'activate_new_email_address', :new_email_activation_code => nil})
        @set.add_named_route('logout',                       "#{path_names[:logout_path]}",                     {:controller => controller, :action => 'logout'})

        # administrator actions
        @set.add_named_route('users',                        "#{path_names[:users_path]}",                      {:controller => controller})
        @set.add_named_route('user_show',                    "#{path_names[:user_show_path]}",                  {:controller => controller, :action => 'show'})
        @set.add_named_route('user_edit',                    "#{path_names[:user_edit_path]}",                  {:controller => controller, :action => 'edit'})
      end
    end
  end
end
