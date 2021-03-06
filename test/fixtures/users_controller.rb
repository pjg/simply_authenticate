class UsersController < ApplicationController
  layout 'test'

  # clear all filters defined in the application_controller.rb
  skip_filter filter_chain

  # skip_filter cleaned this up, so we need to add this here too (prepend because those HAVE TO BE the first filters)
  prepend_before_filter :load_user, :valid_profile_required

  # certain filters for certain actions
  before_filter :login_required, :only => [:logout, :profile, :change_password, :change_email_address]
  before_filter :registration_allowed, :only => [:register]
  before_filter :password_change_allowed, :only => [:change_password]
  before_filter :password_reset_allowed, :only => [:forgot_password]
  before_filter :administrator_role_required, :only => [:index, :show, :edit]

  def root
    render :nothing => true
  end

  def register
    register_and_redirect_to_default
  end

  def activate_account
    activate_account_login_and_redirect_to_profile
  end

  def send_activation_code
    send_activation_code_and_redirect_to_default
  end

  def login
    login_and_redirect_to_stored
  end

  def forgot_password
    reset_password_and_redirect_to_login
  end

  def profile
    show_or_edit_profile
  end

  def change_password
    change_password_and_redirect_to_profile
  end

  def change_email_address
    change_email_address_and_redirect_to_profile
  end

  def activate_new_email_address
    activate_new_email_address_and_redirect_to_default
  end

  def logout
    logout_and_redirect_to_default
  end

  # Administrative methods

  def index
    list_users
  end

  def show
    show_user
  end

  def edit
    edit_user
  end
end
