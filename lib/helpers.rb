module SimplyAuthenticate

  module Helpers

    # HELPER
    def logged_in?
      !session[:user_id].blank?
    end

    # FILTER
    def login_required
      return if logged_in?
      flash[:warning] = 'Proszę się zalogować'
      session[:return_to] = request.request_uri
      redirect_to login_path
    end

    # FILTER (user is loaded for every page view)
    def load_user
      # from session
      @current_user = User.find(session[:user_id]) if session[:user_id]
 
      # from cookie
      # we store 'autologin_token' (hash of email, salt and expiration date) in user's cookie and in the database
      return unless cookies[:autologin_token] && !logged_in?
      @current_user = User.find_by_autologin_token(cookies[:autologin_token])
      if @current_user && !@current_user.autologin_expires.nil? && Time.now < @current_user.autologin_expires
        session[:user_id] = @current_user.id
      end
    end

    # ACTION
    def redirect_to_stored
      if return_to = session[:return_to] then
        session[:return_to] = nil
        redirect_to return_to
      else
        redirect_to root_path
      end
    end

    # Dynamic methods definitions (for roles)
    SimplyAuthenticate::Settings.roles.each do |role|
      # HELPERS: editor? administrator? etc. for views/controllers
      define_method "#{role.to_s}?" do
        logged_in? && @current_user && @current_user.roles.any? {|r| r.function == role.to_s}
      end

      # FILTERS: editor_role_required administrator_role_required etc. for controllers
      define_method "#{role.to_s}_role_required" do
        return if send("#{role.to_s}?")
        flash[:warning] = 'Brak wymaganych uprawnień'
        redirect_to root_path
      end
    end
  end

end
