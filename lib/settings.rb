module SimplyAuthenticate

  # Settings for the SimplyAuthenticate plugin. You can override them on the global level
  # by putting the following into "config/initializers/simply_authenticate.rb":
  #
  #   SimplyAuthenticate::Settings.controller_name = 'uzytkownicy'
  #
  module Settings

    # Controller name used in the application
    @@controller_name = 'users'

    # Paths used in routes definitions
    @@path_names = {
      :registration_path => '/rejestracja',
      :activation_path => '/aktywacja/:activation_code',
      :send_activation_code_path => '/przeslij-kod-aktywacji',
      :login_path => '/logowanie',
      :forgot_password_path => '/zapomnialem-hasla',
      :profile_path => '/profil',
      :change_password_path => '/zmiana-hasla',
      :change_email_path => '/zmiana-adresu-email',
      :new_email_activation_path => '/aktywacja-adresu-email/:new_email_activation_code',
      :logout_path => '/wyloguj'
    }

    # Controller name used in paths
    @@path_names[:controller_prefix] = 'uzytkownicy'
    
    # Paths continued (administrator's actions)
    @@path_names[:users_path] = "/#{@@path_names[:controller_prefix]}"
    @@path_names[:user_show_path] = "/#{@@path_names[:controller_prefix]}/pokaz/:id"
    @@path_names[:user_edit_path] = "/#{@@path_names[:controller_prefix]}/edytuj/:id"

    mattr_accessor :controller_name, :path_names
  end

end
