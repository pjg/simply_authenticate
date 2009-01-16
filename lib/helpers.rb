module SimplyAuthenticate

  module Helpers

    def logged_in?
      !session[:user_id].blank?
    end

    # FILTER: user is loaded for every page view
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

    # Dynamic methods definitions (for roles)
    # Unfortunately ActiveRecord models are not yet fully 'activated' so we must go with straight SQL
    ActiveRecord::Base.connection.select_all('SELECT function FROM roles').each do |role|
      # HELPERS: editor? administrator? etc. for views/controllers
      define_method "#{role['function']}?" do
        logged_in? && @current_user && @current_user.roles.collect {|r| r.function == role['function']}.any?
      end

      # FILTERS: editor_role_required administrator_role_required etc. for controllers
      define_method "#{role['function']}_role_required" do
        #return if editor?
        return if send "#{role['function']}?"
        flash[:warning] = 'Brak wymaganych uprawnień'
        redirect_to root_path
      end
    end
  end

end
