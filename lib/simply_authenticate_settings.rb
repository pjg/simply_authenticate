module SimplyAuthenticate
  # Settings for the SimplyAuthenticate plugin. You can override them on the global level
  # by putting the following into "config/initializers/simply_authenticate.rb":
  #
  #   SimplyAuthenticate::Settings.notifications[:application] = 'MyApplication.com'
  #
  module Settings

    # Controller name used in the application
    # Actually, having a 'users' controller is a requirement, so changing it will only cause problems
    @@controller_name = 'users'

    # Paths used in routes definitions
    @@path_names = {:controller_prefix => 'uzytkownicy'}
    @@path_names.merge!(
      # user actions
      :register_path => '/rejestracja',
      :activate_account_path => '/aktywacja/:activation_code',
      :send_activation_code_path => '/przeslij-kod-aktywacji',
      :login_path => '/logowanie',
      :forgot_password_path => '/zapomnialem-hasla',
      :profile_path => '/profil',
      :change_password_path => '/zmiana-hasla',
      :change_email_address_path => '/zmiana-adresu-email',
      :activate_new_email_address_path => '/aktywacja-nowego-adresu-email/:new_email_activation_code',
      :logout_path => '/wyloguj',
      # administrator actions
      :users_path => "/#{@@path_names[:controller_prefix]}",
      :user_edit_path => "/#{@@path_names[:controller_prefix]}/:id/edytuj",
      :user_show_path => "/#{@@path_names[:controller_prefix]}/:id"
    )

    # Notifications (Mailer)
    @@notifications = {
      :application => 'Aplikacja',
      :host => 'localhost',
      :email => 'poczta@localhost'
    }

    # Autologin expire time (in days)
    @@autologin_expires = 30

    # Default redirect_to destination (after registering, when no appropriate credentials, etc.)
    # Unfortunately you cannot use 'root_path' et al.
    @@default_redirect_to = '/'

    # Legal notice and legal requirements message (when registering)
    @@legal_notice = ''
    @@legal_requirements_message = ''

    mattr_accessor :controller_name, :path_names, :notifications, :roles, :autologin_expires, :default_redirect_to, :legal_notice, :legal_requirements_message
  end
end
