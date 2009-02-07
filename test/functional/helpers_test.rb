require File.dirname(__FILE__) + '/../test_helper'
require 'action_controller'
require 'action_controller/test_process'

require File.dirname(__FILE__) + '/../fixtures/users_controller.rb'

class UsersControllerTest < ActionController::TestCase

  include SimplyAuthenticate::Helpers

  def setup
    @controller = UsersController.new
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new

    @request.host = "localhost"

    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    ActionController::Routing::Routes.draw do |map|
      map.root :controller => 'users', :action => 'root'
      map.simply_authenticate_routes
    end
  end

  def test_logged_in
    # not yet logged in
    get :login
    assert !logged_in?

    # setup session & check again
    session[:user_id] = @bob.id
    assert logged_in?
  end

  def test_load_invalid_user_from_session
    get :login
    session[:user_id] = 54151515616
    assert_raise(ActiveRecord::RecordNotFound) {load_user}
    assert_equal @current_user, nil
  end

  def test_load_user_from_session
    get :login
    session[:user_id] = @bob.id
    load_user
    assert_equal @current_user, @bob
  end

  def test_roles
    get :login

    # user
    session[:user_id] = @bob.id
    load_user
    assert logged_in?
    assert user?
    assert !editor?
    assert !administrator?
    assert !moderator?

    # administrator
    session[:user_id] = @administrator.id
    load_user
    assert logged_in?
    assert user?
    assert !editor?
    assert administrator?
    assert !moderator?

    # moderator
    session[:user_id] = @moderator.id
    load_user
    assert logged_in?
    assert user?
    assert !editor?
    assert !administrator?
    assert moderator?
  end

  def test_login_required
    # can't access 'profile' if not logged in
    get :profile
    assert_response :redirect
    assert_redirected_to login_path
    assert flash.has_key?(:warning)

    login_as(@bob)

    # can access it now
    get :profile
    assert_response :success
    assert flash.empty?
    assert_template "users/profile"
  end

  def test_invalid_registration
    # fetch registration page
    get :register
    assert_response :success
    assert_tag :h1, :child => /REJESTRACJA/
    assert !flash.now[:notice]
    assert !flash.now[:warning]

    # empty email
    post :register, {:user => {:email => ''}}
    assert_response :success
    assert flash.now[:warning]
    assert @response.template_objects['user'].errors.invalid?(:email)

    # too short email
    post :register, {:user => {:email => "eee"}}
    assert_response :success
    assert flash.now[:warning]
    assert @response.template_objects['user'].errors.invalid?(:email)

    # wrong email
    post :register, {:user => {:email => "wrong@email"}}
    assert_response :success
    assert flash.now[:warning]
    assert @response.template_objects['user'].errors.invalid?(:email)

    # wrong email (collision)
    post :register, {:user => {:email => @bob.email}}
    assert_response :success
    assert flash.now[:warning]
    assert @response.template_objects['user'].errors.invalid?(:email)
  end

  def test_registration
    email = "albert@albert.com"

    # register
    post :register, {:user => {:email => email}}
    assert flash.has_key?(:notice)
    assert_response :redirect
    assert flash[:notice]
    assert_redirected_to root_path

    # check proper role assignment
    @albert = User.find_by_email(email)
    assert @albert.roles.include?(Role.find_by_slug('user'))

    # extract password and activation code
    email_sent = ActionMailer::Base.deliveries.first
    assert_not_nil email_sent
    password = email_sent.body[/Hasło: (\w+)$/, 1]
    assert_not_nil password
    activation_code = email_sent.body[/aktywacja\/(\w+)$/, 1]
    assert_not_nil activation_code

    # check that we cannot yet login
    post :login, {:user => {:email => email, :password => password}, :remember => {:me => "0"}}
    assert_response :success
    assert_nil session[:user_id]
    assert_template 'users/login'
    assert_tag :div, :child => /Twoje konto nie zostało jeszcze aktywowane/

    # assume the activation key was lost and request it again
    get :send_activation_code
    assert_response :success
    assert_template 'users/send_activation_code'
    post :send_activation_code, {:user => {:email => email}}
    second_email_sent = ActionMailer::Base.deliveries.second
    assert_not_nil second_email_sent
    second_activation_code = second_email_sent.body[/aktywacja\/(\w+)$/, 1]
    assert_equal second_activation_code, activation_code

    # activate user (we should be automatically logged in)
    @albert.reload
    login_count = @albert.login_count
    get :activate_account, {:activation_code => activation_code}
    @albert.reload
    assert flash.has_key?(:notice)
    assert_equal @albert.id, session[:user_id]
    assert @albert.is_activated?
    assert_not_nil @albert.activated_on
    assert_equal User.find_by_activation_code(activation_code), User.find_by_id(session[:user_id])
    assert_equal login_count + 1, @albert.login_count
    assert_response :redirect
    assert_redirected_to root_path

    logout

    login_as(@albert, :password => password)
  end

  def test_invalid_login
    # fetch login page
    get :login
    assert_response :success
    assert_tag :h1, :child => /LOGOWANIE/
    assert_template 'users/login'

    # bad email
    post :login, {:user => {:email => "blahblah@bob.com", :password => "test"}, :remember => {:me => "0"}}
    assert_response :success
    assert_template "users/login"
    assert !session[:user_id]
    assert_tag :div, :child => /Błędny email lub hasło/

    # bad password
    post :login, {:user => {:email => @bob.email, :password => "bad-password"}, :remember => {:me => "0"}}
    assert_response :success
    assert_template "users/login"
    assert !session[:user_id]
    assert_tag :div, :child => /Błędny email lub hasło/

    # not activated
    post :login, {:user => {:email => "bill@bill.com", :password => "test"}, :remember => {:me => "0"}}
    assert_response :success
    assert_template "users/login"
    assert !session[:user_id]
    assert_tag :div, :child => /Twoje konto nie zostało jeszcze aktywowane/

    # account blocked
    post :login, {:user => {:email => "kyrlie@kyrlie.com", :password => "test"}, :remember => {:me => "0"}}
    assert_response :success
    assert_template "users/login"
    assert !session[:user_id]
    assert_tag :div, :child => /Twoje konto zostało zablokowane/
  end

  def test_login_logout
    # fetch login page
    get :login
    assert_response :success
    assert_tag :h1, :child => /LOGOWANIE/
    assert !logged_in?

    # login
    login_as(@bob)
    assert_redirected_to root_path

    logout
  end

  def test_return_to
    # can't access 'profile' without being logged in
    get :profile
    assert flash.has_key?(:warning)
    assert_response :redirect
    assert_redirected_to login_path
    assert @response.has_session_object?(:return_to)

    # login
    login_as(@bob)
    # redirected to 'profil' instead of the default action
    assert_redirected_to profile_path
    assert !@response.has_session_object?(:return_to)
    assert @response.has_session_object?(:user_id)

    logout

    # login again but this time we should be redirected to the default action
    login_as(@bob)
    assert_redirected_to root_path
  end

  def test_login_from_cookie
    # login
    login_as(@bob, :remember_me => true)

    # check whether the cookies were set
    assert_equal cookies.size, 1
    assert_equal cookies['autologin_token'].value.first, User.find(@bob.id).autologin_token

    # reset the session (equivalent of closing the browser)
    session[:user_id] = nil

    # set cookies to the ones we got after logging in
    @request.cookies = cookies

    # fetch a page requiring being logged in
    get :profile
    assert_response :success
    assert_equal session[:user_id], @bob.id
    assert_equal cookies['autologin_token'].value.first, User.find(@bob.id).autologin_token
  end

  def test_forgot_password
    # fetch forgot password page
    get :forgot_password
    assert_response :success
    assert_tag :h1, :child => /GENEROWANIE NOWEGO HASŁA/

    # enter an email that doesn't exist
    post :forgot_password, :user => {:email => "notauser@doesntexist.com"}
    assert_response :success
    assert !@response.has_session_object?(:user_id)
    assert_template "users/forgot_password"
    assert_tag :div, :child => /Odzyskanie hasła nie było możliwe/

    # enter a valid email
    post :forgot_password, :user => {:email => @bob.email}
    assert_response :redirect
    assert_redirected_to login_path
    assert flash.has_key?(:notice)

    # parse new password
    password = $1 if Regexp.new("\n\n(\\w{10})\n\n") =~ ActionMailer::Base.deliveries.first.body
    assert_not_nil password

    # login with new password
    login_as(@bob, :password => password)
  end

  def test_profile_fields_visibility
    # make sure SLUG field is not visible to normal users while viewing profile
    get :profile, {}, {:user_id => @bob}
    assert_response :success
    assert_no_tag :p, :child => /SLUG/

    # make sure SLUG field is visible to the administrator
    get :profile, {}, {:user_id => @administrator}
    assert_response :success
    assert_tag :p, :child => /SLUG/
  end

  def test_profile_change
    # login
    login_as(@bob)

    # try changing name to a wrong name
    put :profile, {:user => {:name => "yo"}}
    assert_response :success
    @response.template_objects['user'].errors
    assert @response.template_objects['user'].errors.invalid?(:name)
    assert_template "users/profile"

    # our name is not changed
    get :profile
    assert_select "#user_name[value=#{@bob.name}]"

    # valid name change
    put :profile, {:user => {:name => "ThisIsNewMe"}}
    assert_response :success
    assert_template "users/profile"

    # our name has been changed
    @bob = User.find_by_email(@bob.email)
    assert_equal @bob.name, "ThisIsNewMe"
    get :profile
    assert_select "#user_name[value=#{@bob.name}]"
  end

  def test_password_change
    login_as(@bob)

    # fetch password change page
    get :change_password
    assert_response :success
    assert_tag :h1, :child => /ZMIANA HASŁA/

    # try to change the password

    # bad old password
    put :change_password, {:user => {:old_password => 'blah', :password => "newpass", :password_confirmation => "newpass"}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:old_password)
    assert_tag :div, :child => /Zmiana hasła nie była możliwa/

    # empty new password
    put :change_password, {:user => {:old_password => 'test', :password => '', :password_confirmation => ''}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:password)

    # passwords don't match
    put :change_password, {:user=> {:old_password => 'test', :password => "newpass", :password_confirmation => "newpassdoesntmatch"}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:password)

    # success - password changed
    password = "newpass"
    put :change_password, {:user => {:old_password => 'test', :password => password, :password_confirmation => "newpass"}}
    assert_response :redirect
    assert flash.has_key?(:notice)
    assert @response.template_objects['user'].errors.empty?
    assert_redirected_to profile_path

    logout

    # old password no longer works
    post :login, {:user => {:email => @bob.email, :password => "test"}, :remember => {:me => "0"}}
    assert_response :success
    assert_nil session[:user_id]
    assert_template "users/login"

    # new password works
    login_as(@bob, :password => password)
  end

  def test_invalid_email_change
    login_as(@bob)

    # fetch the email change page
    get :change_email_address
    assert_response :success

    # nil email
    put :change_email_address, {:user => {:new_email => nil}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:new_email)

    # empty email
    put :change_email_address, {:user => {:new_email => ''}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:new_email)

    # wrong email
    put :change_email_address, {:user => {:new_email => "bob@bob"}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:new_email)

    # collision
    put :change_email_address, {:user => {:new_email => @inactivated.email}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:new_email)
  end

  def test_valid_email_change
    old_email = @bob.email
    email = "bob@newbob.com"

    login_as(@bob)

    # change email
    put :change_email_address, {:user => {:new_email => email}}
    assert_response :redirect
    assert flash.has_key?(:notice)

    # check that the current email has not yet been changed
    bob = User.find(@bob.id)
    assert_not_equal email, bob.email
    assert_equal email, bob.new_email
    assert bob.new_email_activation_code.present?

    # fetch the new email activation code
    new_email_activation_code = $1 if Regexp.new("\n\n.+\/aktywacja-nowego-adresu-email\/(\\w{40})\n\n") =~ ActionMailer::Base.deliveries.first.body
    assert_not_nil new_email_activation_code

    # first try to activate without activation code
    get :activate_new_email_address
    assert_response :success
    assert flash.has_key?(:warning)

    # try to activate with bad activation code
    get :activate_new_email_address, {:new_email_activation_code => 'asdf'}
    assert_response :success
    assert flash.has_key?(:warning)

    # logout (activating a new email address should work this way too)
    logout

    # activate new email
    get :activate_new_email_address, {:new_email_activation_code => new_email_activation_code}
    assert_response :redirect
    assert flash.has_key?(:notice)
    assert_redirected_to root_path

    # email changed successfully
    @bob = User.find(@bob.id)
    assert_equal email, @bob.email
    assert_nil @bob.new_email
    assert_nil @bob.new_email_activation_code

    # we cannot login using the old email
    post :login, {:user => {:email => old_email, :password => "test"}, :remember => {:me => "0"}}
    assert_response :success
    assert_nil session[:user_id]

    # we can login using new email
    login_as(@bob)
  end

  def test_administrative_user_update
    login_as(@administrator)

    # bad name update
    put :edit, {:id => @administrator.id, :user => {:name => "x"}, :role => {"administrator" => "1"}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:name)

    # bad password update
    put :edit, {:id => @administrator.id, :user => {:password => "123"}, :role => {"administrator" => "1"}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:password)

    # correct name and password update
    put :edit, {:id => @administrator.id, :user => {:name => "MyNewName", :password => "new-passwd"}, :role => {"administrator" => "1"}}
    assert_response :redirect
    assert flash.has_key?(:notice)

    logout

    # login using new password
    post :login, {:user => {:email => "john@john.com", :password => "new-passwd"}, :remember => {:me => "0"}}
    assert_equal @administrator.id, session[:user_id]

    # activate user
    assert !User.find(@inactivated.id).is_activated?
    put :edit, {:id => @inactivated.id, :user => {:is_activated => "1"}, :role => {"user" => "1"}}
    assert_response :redirect
    assert flash.has_key?(:notice)
    assert User.find(@inactivated.id).is_activated?

    # unblock user
    assert User.find(@blocked_activated.id).is_blocked?
    put :edit, {:id => @blocked_activated.id, :user => {:is_blocked => "0"}, :role => {"user" => "1"}}
    assert_response :redirect
    assert flash.has_key?(:notice)
    assert !User.find(@blocked_activated.id).is_blocked?

    # take all user roles
    put :edit, {:id => @bob.id, :user => {}, :role => {}}
    assert_response :redirect
    assert flash.has_key?(:notice)
    assert User.find(@bob.id).roles.empty?

    # add admin role
    put :edit, {:id => @bob.id, :user => {}, :role => {"administrator" => "1"}}
    assert_response :redirect
    assert flash.has_key?(:notice)

    # check this admin role
    login_as(@bob)
    assert_equal @bob.id, session[:user_id]
    get :index
    assert_response :success
  end

  def test_administrator_role_required
    login_as(@bob)

    # access denied
    get :index
    assert_redirected_to root_path
    assert flash.has_key?(:warning)

    # login as administrator
    login_as(@administrator)
    assert User.find(session[:user_id]).roles.collect{|r| r.slug == "administrator"}.any?

    # access allowed
    get :index
    assert_response :success

    # view our user and confirm his administrator role
    get :show, {:id => @administrator.id}
    assert_response :success
    assert_tag :strong, :child => /administrator/
  end

  private

  def login_as(user, options = {})
    user.reload
    remember_me = options[:remember_me] && options[:remember_me] == true ? "1" : "0"
    password = options[:password] ? options[:password] : "test"
    login_count = user.login_count

    # every user's password in fixtures is 'test'
    post :login, {:user => {:email => user.email, :password => password}, :remember => {:me => remember_me}}
    assert @response.has_session_object?(:user_id)
    assert_equal user.id, session[:user_id]
    assert_equal @response.cookies['autologin_token'].present?, remember_me == "1" ? true : false
    assert logged_in?
    user.reload
    assert_equal login_count + 1, user.login_count
    assert_response :redirect
  end

  def logout
    get :logout
    assert_response :redirect
    assert !@response.has_session_object?(:user_id)
    assert_nil session[:user_id]
    assert_equal @response.cookies['autologin_token'], []
    assert_redirected_to root_path
  end

end