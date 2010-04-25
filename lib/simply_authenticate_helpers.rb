module SimplyAuthenticate

  module Helpers

    # include helpers from the simply_settings plugin (http://github.com/pjg/simply_settings)
    # those helpers are like this: 'registration_allowed?' and 'password_change_allowed?'
    # you are not obliged to use this plugin; you can define those two methods somewhere else
    include SimplySettings::Helpers if defined?(SimplySettings::Helpers)

    # HELPER
    def logged_in?
      !session[:user_id].blank?
    end

    # FILTER
    def login_required
      return if logged_in?
      flash[:error] = 'Proszę się zalogować'
      session[:return_to] = request.request_uri
      redirect_to login_path
    end

    # FILTER (user is loaded for every page view)
    def load_user
      # from session
      @current_user = User.find(session[:user_id]) if session[:user_id]

      # from cookie
      # we store 'autologin_token' (hash of email, salt and expiration date) in user's cookie and in the database
      return unless cookies["autologin_token"] && !logged_in?
      @current_user = User.find_by_autologin_token(cookies["autologin_token"])
      if @current_user && !@current_user.autologin_expires.nil? && Time.now < @current_user.autologin_expires
        session[:user_id] = @current_user.id
      end
    end

    # FILTER (run for every action; check whether the profile is filled in, if not, redirect to profile)
    def valid_profile_required
      return if !logged_in? # do nothing if we are not logged
      return if @current_user.name.present? and @current_user.gender.present? # do nothing if the profile is already filled in
      return if params[:controller] == SimplyAuthenticate::Settings.controller_name and (params[:action] == 'profile' or params[:action] == 'logout') # do nothing if we are in the 'profile' or 'logout' action
      flash[:error] = 'Zanim zaczniesz korzystać z serwisu musisz uzupełnić swój profil'
      redirect_to profile_path # otherwise redirect to profile
    end

    # ACTION
    def redirect_to_stored
      return_to = session[:return_to]
      if return_to.present? then
        session[:return_to] = nil
        redirect_to return_to
      else
        redirect_to SimplyAuthenticate::Settings.default_redirect_to
      end
    end

    # Dynamic methods definitions (for roles)
    SimplyAuthenticate::Settings.roles.each do |role|
      # HELPERS: editor? administrator? etc. for views/controllers
      define_method "#{role.to_s}?" do
        logged_in? && @current_user && @current_user.roles.any? {|r| r.slug == role.to_s}
      end

      # FILTERS: editor_role_required administrator_role_required etc. for controllers
      define_method "#{role.to_s}_role_required" do
        return if send("#{role.to_s}?")
        flash[:error] = 'Brak wymaganych uprawnień'
        redirect_to SimplyAuthenticate::Settings.default_redirect_to
      end
    end

    # SETTINGS (methods, which work with the simply_settings plugin)

    # FILTER
    def registration_allowed
      return if registration_allowed?
      flash[:error] = 'Rejestracja jest obecnie wyłączona'
      redirect_to SimplyAuthenticate::Settings.default_redirect_to
    end

    # FILTER
    def password_change_allowed
      return if password_change_allowed?
      flash[:error] = 'Zmiana hasła jest w tym momencie niemożliwa'
      redirect_to profile_path
    end


    # Methods to use in the UsersController

    # REGISTER
    def register_and_redirect_to_default
      @title = 'Rejestracja'
      @user = User.new(params[:user])
      return unless request.post?

      # verify the legal requirements acceptance
      if SimplyAuthenticate::Settings.legal_requirements_message.present?
        flash.now[:error] = 'Rejestracja wymaga wyrażenia zgody na przetwarzanie danych osobowych' and return if params[:legal_requirements].blank? or params[:legal_requirements][:accepted].blank? or params[:legal_requirements][:accepted] != '1'
      end

      # captcha_verification

      @user.register!
      flash[:success] = 'Rejestracja pomyślna. Konto nie jest jeszcze aktywne. Na podany adres email została wysłana wiadomość z instrukcją jak je aktywować'
      redirect_to SimplyAuthenticate::Settings.default_redirect_to
    rescue SimplyAuthenticate::Exceptions::NotRegistered
      flash.now[:error] = 'Błąd podczas rejestracji'
    rescue ApplicationController::InvalidCaptcha
      flash.now[:error] = 'Zła wartość w polu captcha (źle rozwiązane działanie matematyczne)'
    end

    # ACTIVATE
    def activate_account_login_and_redirect_to_profile
      @title = 'Aktywacja konta'
      session[:user_id] = User.find_and_activate_account!(params[:activation_code]).id
      flash[:success] = 'Twoje konto jest teraz aktywne. Zostałeś automatycznie zalogowany. Aby dokończyć rejestrację w serwisie musisz uzupełnić swój profil'
      redirect_to profile_path
    rescue SimplyAuthenticate::Exceptions::ArgumentError
      flash.now[:error] = 'Brak kodu aktywacji'
    rescue SimplyAuthenticate::Exceptions::BadActivationCode
      flash.now[:error] = 'Podany kod aktywacji nie został odnaleziony'
    rescue SimplyAuthenticate::Exceptions::AlreadyActivated
      flash[:success] = 'Twoje konto już zostało aktywowane. Możesz się zalogować'
      redirect_to login_path
    rescue SimplyAuthenticate::Exceptions::UnauthorizedAccountBlocked
      flash.now[:error] = 'Twoje konto jest zablokowane. Jego aktywacja nie jest możliwa'
    end

    # SEND_ACTIVATION_CODE
    # Explicit activation code second delivery via email (normally it is sent in the welcome email)
    def send_activation_code_and_redirect_to_default
      @title = "Prześlij kod aktywacji"
      @user = User.new
      return unless request.post?
      User.find_and_send_activation_code!(params[:user][:email])
      flash[:success] = 'Na podany adres email został wysłany kod aktywacji wraz z instrukcją jak aktywować konto'
      redirect_to SimplyAuthenticate::Settings.default_redirect_to
    rescue SimplyAuthenticate::Exceptions::UnauthorizedWrongEmail
      flash.now[:error] = 'Brak użytkownika o podanym adresie email'
    rescue SimplyAuthenticate::Exceptions::AlreadyActivated
      flash[:success] = 'Twoje konto już zostało aktywowane. Możesz się zalogować'
      redirect_to login_path
    end

    # LOGIN
    def login_and_redirect_to_stored
      @title = 'Logowanie do systemu'
      @user = User.new(params[:user])
      return unless request.post?
      user = User.authenticate(params[:user][:email], params[:user][:password])
      session[:user_id] = user.id
      if params[:remember] && params[:remember][:me] && params[:remember][:me] == "1"
        user.remember_me
        cookies[:autologin_token] = {:value => user.autologin_token, :expires => user.autologin_expires}
      end
      user.update_last_logged_times(:login_count => user.login_count + 1,:last_ip => user.current_ip, :current_ip => request.remote_ip, :last_logged_on => user.current_logged_on, :current_logged_on => Time.now)
      redirect_to_stored
    rescue SimplyAuthenticate::Exceptions::UnauthorizedWrongEmail
      flash.now[:error] = 'Błędny email lub hasło'
    rescue SimplyAuthenticate::Exceptions::UnauthorizedWrongPassword
      User.find_by_email(params[:user][:email]).update_attributes(:last_failed_ip => request.remote_ip, :last_failed_logged_on => Time.now)
      flash.now[:error] = 'Błędny email lub hasło'
    rescue SimplyAuthenticate::Exceptions::UnauthorizedNotActivated
      @inactivated = true
      flash.now[:error] = 'Twoje konto nie zostało jeszcze aktywowane. Sprawdź swoją pocztę. Powinien znajdować się tam email z instrukcją aktywacji konta'
    rescue SimplyAuthenticate::Exceptions::UnauthorizedAccountBlocked
      flash.now[:error] = 'Twoje konto zostało zablokowane. Logowanie nie jest możliwe'
    end

    # FORGOT PASSWORD
    def reset_password_and_redirect_to_login
      @title = 'Generowanie nowego hasła'
      @user = User.new
      return unless request.post?
      User.find_and_reset_password!(params[:user][:email])
      flash[:success]  = 'Nowe hasło zostało przesłane na podany adres email'
      redirect_to login_path
    rescue ActiveRecord::RecordNotFound
      flash.now[:error] = 'Odzyskanie hasła nie było możliwe (nieprawidłowy adres email)'
    end

    # PROFILE
    def show_or_edit_profile
      @title = 'Twój profil'
      # we must have a new @user object here, so that if updating fails, we still have @current_user intact
      @user = User.find(@current_user.id)
      return unless request.put?
      @user.update_profile(params[:user])
      # update ok, let @current_user share @user's data - we have to do this because there is no redirect after successful execution
      @current_user = @user
      flash.now[:success] = 'Twój profil został uaktualniony'
    rescue SimplyAuthenticate::Exceptions::ProfileNotUpdated
      flash.now[:error] = 'Wystąpił błąd podczas uaktualniania profilu'
    end

    # CHANGE PASSWORD
    def change_password_and_redirect_to_profile
      @title = 'Zmiana hasła'
      # we must have a new @user object here, so if updating fails, we still have @current_user intact
      @user = User.find(@current_user.id)
      return unless request.put?
      @user.change_password(params[:user])
      flash[:success] = 'Twoje hasło zostało zmienione'
      redirect_to profile_path
    rescue SimplyAuthenticate::Exceptions::UnauthorizedWrongPassword
      @user.errors.add('old_password', 'wprowadzono złe hasło')
      flash.now[:error] = 'Zmiana hasła nie była możliwa'
    rescue SimplyAuthenticate::Exceptions::PasswordNotChanged
      flash.now[:error] = 'Wystąpił błąd podczas zmiany hasła'
    end

    # CHANGE EMAIL
    def change_email_address_and_redirect_to_profile
      @title = 'Zmiana adresu email'
      # we must have a new @user object here, so if updating fails, we still have @current_user intact
      @user = User.find(@current_user.id)
      return unless request.put?
      @user.change_email_address(params[:user][:new_email])
      flash[:success] = 'Na podany adres email został wysłany list z linkiem aktywującym nowy adres email'
      redirect_to profile_path
    rescue SimplyAuthenticate::Exceptions::ArgumentError, SimplyAuthenticate::Exceptions::EmailNotChanged
      flash.now[:error] = 'Zmiana adresu email nie była możliwa'
    end

    # ACTIVATE NEW EMAIL ADDRESS
    # activating new email address does not require being logged in; if we were logged in nothing changes after activating new email; if we were logged out, the same
    def activate_new_email_address_and_redirect_to_default
      @title = 'Aktywacja nowego adresu email'
      User.find_and_activate_new_email_address!(params[:new_email_activation_code])
      flash[:success] = 'Twój adres email został zmieniony'
      redirect_to SimplyAuthenticate::Settings.default_redirect_to
    rescue SimplyAuthenticate::Exceptions::ArgumentError
      flash.now[:error] = 'Brak kodu aktywacji'
    rescue ActiveRecord::RecordNotFound
      flash.now[:error] = 'Podany kod aktywacji nie został odnaleziony'
    rescue SimplyAuthenticate::Exceptions::EmailNotChanged
      flash.now[:error] = 'Zmiana adresu email nie była możliwa'
    end

    # LOGOUT
    def logout_and_redirect_to_default
      @current_user.forget_me
      reset_session
      cookies.delete :autologin_token
      flash[:success] = 'Zostałeś wylogowany z systemu'
      redirect_to SimplyAuthenticate::Settings.default_redirect_to
    end


    # Administrative methods

    def list_users
      @title = 'Lista użytkowników'
      @users = User.find(:all, :order => :id)
    end

    def show_user
      @user = User.find_by_id!(params[:id])
      @title = "Użytkownik: #{@user.name} [#{@user.email}]"
    rescue ActiveRecord::RecordNotFound
      flash[:error] = 'Nie odnaleziono użytkownika o takim id'
    end

    def edit_user
      @user = User.find_by_id!(params[:id])
      @roles = Role.find(:all, :order => :id)
      @title = "Edycja użytkownika: #{@user.name} [#{@user.email}]"
      return unless request.put?
      @user.update_user(params[:user])
      @user.update_roles(params[:role])
      flash[:success] = 'Dane użytkownika uaktualnione'
      redirect_to user_show_path(:id => @user)
    rescue ActiveRecord::RecordNotFound
      flash[:error] = 'Nie odnaleziono użytkownika o takim id'
      redirect_to users_path
    rescue SimplyAuthenticate::Exceptions::UserNotUpdated
      flash.now[:error] = 'Wystąpił błąd podczas uaktualniania danych użytkownika'
    end

  end

end
