require File.dirname(__FILE__) + '/../test_helper'
require 'action_controller'
require 'action_controller/test_process'

require File.dirname(__FILE__) + '/../fixtures/users_controller.rb'
require File.dirname(__FILE__) + '/../fixtures/notifications.rb'
require File.dirname(__FILE__) + '/../fixtures/settings.rb'

class UsersControllerTest < ActionController::TestCase

  include SimplyAuthenticate::Helpers

  def setup
    @controller = UsersController.new
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new

    @request.host = 'localhost'

    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    ActionController::Routing::Routes.draw do |map|
      map.root :controller => 'users', :action => 'root'
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
    assert flash.has_key?(:alert)

    login_as(@bob)

    # can access it now
    get :profile
    assert_response :success
  end

  def test_invalid_registration
    # set legal notice to empty (not required)
    SimplyAuthenticate::Settings.legal_notice = ''
    SimplyAuthenticate::Settings.legal_requirements_message = ''

    # fetch registration page
    get :register
    assert_response :success
    assert_select 'h1', :text => /REJESTRACJA/
    assert !flash.has_key?(:notice)
    assert !flash.has_key?(:alert)

    # empty email
    post :register, {:user => {:email => ''}}
    assert_response :success
    assert flash.has_key?(:alert)
    assert @response.template_objects['user'].errors.invalid?(:email)

    # too short email
    post :register, {:user => {:email => 'eee'}}
    assert_response :success
    assert flash.has_key?(:alert)
    assert @response.template_objects['user'].errors.invalid?(:email)

    # wrong email
    post :register, {:user => {:email => 'wrong@email'}}
    assert_response :success
    assert flash.has_key?(:alert)
    assert @response.template_objects['user'].errors.invalid?(:email)

    # wrong email (collision)
    post :register, {:user => {:email => @bob.email}}
    assert_response :success
    assert flash.has_key?(:alert)
    assert @response.template_objects['user'].errors.invalid?(:email)

    # require confirmation of legal notice
    SimplyAuthenticate::Settings.legal_notice = 'Required now'
    SimplyAuthenticate::Settings.legal_requirements_message = 'Really required'

    # legal notice not accepted
    post :register, {:user => {:email => 'nowy@email.pl'}}
    assert_response :success
    assert flash.has_key?(:alert)
  end

  def test_registration
    # require confirmation of legal notice
    SimplyAuthenticate::Settings.legal_notice = 'Required now'
    SimplyAuthenticate::Settings.legal_requirements_message = 'Really required'

    email = 'albert@albert.com'

    # register
    post :register, {:user => {:email => email}, :legal_requirements => {:accepted => '1'}}
    assert flash.has_key?(:notice)
    assert_response :redirect
    assert flash.has_key?(:notice)
    assert_redirected_to SimplyAuthenticate::Settings.default_redirect_to

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
    post :login, {:user => {:email => email, :password => password}, :remember => {:me => '0'}}
    assert_response :success
    assert_nil session[:user_id]
    assert_select 'div', :text => /Twoje konto nie zostało jeszcze aktywowane/

    # assume the activation key was lost and request it again
    get :send_activation_code
    assert_response :success
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
    assert_redirected_to profile_path

    # try to fetch some other action to see that without filling in the profile we will be redirected to profile
    get :register
    assert_response :redirect
    assert_redirected_to profile_path
    assert flash.has_key?(:alert)

    # accessing profile action directly should work without any redirects
    get :profile
    assert_response :success

    # as should logout
    logout

    # after login the first redirect is always to the SimplyAuthenticate::Settings.default_redirect_to and from there we are redirected to profile_path
    login_as(@albert, :password => password)
    assert_redirected_to SimplyAuthenticate::Settings.default_redirect_to

    # try to fetch some other action to see that without filling in the profile we will be redirected to profile
    get :root
    assert_response :redirect
    assert_redirected_to profile_path
    assert flash.has_key?(:alert)

    # fill in the required profile fields
    put :profile, {:user => {:name => 'ThisIsMe', :gender => 'm'}}
    assert_response :success

    # see that going to root now should work without redirect
    get :root
    assert_response :success
  end

  def test_invalid_login
    # fetch login page
    get :login
    assert_response :success
    assert_select 'h1', :text => /LOGOWANIE/

    # bad email
    post :login, {:user => {:email => 'blahblah@bob.com', :password => 'test'}, :remember => {:me => '0'}}
    assert_response :success
    assert !session[:user_id]
    assert_select 'div', :text => /Błędny email lub hasło/

    # bad password
    post :login, {:user => {:email => @bob.email, :password => 'bad-password'}, :remember => {:me => '0'}}
    assert_response :success
    assert !session[:user_id]
    assert_select 'div', :text => /Błędny email lub hasło/

    # not activated
    post :login, {:user => {:email => 'bill@bill.com', :password => 'test'}, :remember => {:me => '0'}}
    assert_response :success
    assert !session[:user_id]
    assert_select 'div', :text => /Twoje konto nie zostało jeszcze aktywowane/

    # account blocked
    post :login, {:user => {:email => 'kyrlie@kyrlie.com', :password => 'test'}, :remember => {:me => '0'}}
    assert_response :success
    assert !session[:user_id]
    assert_select 'div', :text => /Twoje konto zostało zablokowane/
  end

  def test_login_logout
    # fetch login page
    get :login
    assert_response :success
    assert_select 'h1', :text => /LOGOWANIE/

    # login/password fields
    assert_select "p input[type=text]#user_email"
    assert_select "p input[type=password]#user_password"

    # not logged in
    assert !logged_in?

    # login
    login_as(@bob)
    assert_redirected_to SimplyAuthenticate::Settings.default_redirect_to

    logout
  end

  def test_return_to
    # can't access 'profile' without being logged in
    get :profile
    assert flash.has_key?(:alert)
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
    assert_redirected_to SimplyAuthenticate::Settings.default_redirect_to
  end

  def test_login_from_cookie
    # login
    login_as(@bob, :remember_me => true)

    # check whether the cookies were set
    assert_equal cookies.size, 1
    assert_equal cookies['autologin_token'], User.find(@bob.id).autologin_token

    # reset the session (equivalent of closing the browser)
    session[:user_id] = nil

    # set cookies to the ones we got after logging in (cookies is a shortcut to @response.cookies)
    @request.cookies = cookies

    # fetch a page requiring being logged in
    get :profile
    assert_response :success
    assert_equal session[:user_id], @bob.id
    assert_equal cookies['autologin_token'], User.find(@bob.id).autologin_token
  end

  def test_forgot_password
    # fetch forgot password page
    get :forgot_password
    assert_response :success
    assert_select 'h1', :text => /GENEROWANIE NOWEGO HASŁA/

    # enter an email that doesn't exist
    post :forgot_password, :user => {:email => 'notauser@doesntexist.com'}
    assert_response :success
    assert !@response.has_session_object?(:user_id)
    assert_nil session[:user_id]
    assert_select 'div', :text => /Odzyskanie hasła nie było możliwe/

    # enter a valid email
    post :forgot_password, :user => {:email => @bob.email}
    assert_response :redirect
    assert_redirected_to login_path
    assert flash.has_key?(:notice)

    # parse new password
    password = $1 if Regexp.new("\n\n(\\w{10})\n\n") =~ ActionMailer::Base.deliveries.first.body
    assert_not_nil password

    # old password no longer works
    post :login, {:user => {:email => @bob.email, :password => 'test'}, :remember => {:me => '0'}}
    assert_response :success
    assert_nil session[:user_id]

    # login with new password
    login_as(@bob, :password => password)
  end

  def test_forgot_password_before_filling_in_the_profile
    get :forgot_password
    assert_response :success

    post :forgot_password, :user => {:email => @genderless_activated.email}
    assert_response :redirect
    assert_redirected_to login_path
    assert flash.has_key?(:notice)

    # parse new password
    password = $1 if Regexp.new("\n\n(\\w{10})\n\n") =~ ActionMailer::Base.deliveries.first.body
    assert_not_nil password

    # login with new password
    login_as(@genderless_activated, :password => password)
  end

  def test_profile_fields_visibility
    # make sure SLUG field is not visible to normal users while viewing profile
    get :profile, {}, {:user_id => @bob}
    assert_response :success
    assert_no_tag :p, :child => /SLUG/

    # make sure SLUG field is visible to the administrator
    get :profile, {}, {:user_id => @administrator}
    assert_response :success
    assert_select 'p', :text => /SLUG/
  end

  def test_profile_change
    # login
    login_as(@bob)
    assert_equal 'm', @bob.gender

    # try changing name to a wrong name
    put :profile, {:user => {:name => 'yo'}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:name)

    # our name is not changed
    get :profile
    assert_select "#user_name[value=#{@bob.name}]"

    # valid name and gender change
    put :profile, {:user => {:name => 'ThisIsNewMe', :gender => 'f'}}
    assert_response :success

    # our name and gender have been changed
    @bob.reload
    assert_equal 'ThisIsNewMe', @bob.name
    assert_equal 'f', @bob.gender
    get :profile
    assert_select "#user_name[value=#{@bob.name}]"
  end

  def test_password_change
    login_as(@bob)

    # fetch password change page
    get :change_password
    assert_response :success
    assert_select 'h1', :text => /ZMIANA HASŁA/

    # try to change the password

    # bad old password
    put :change_password, {:user => {:old_password => 'blah', :password => 'newpass', :password_confirmation => 'newpass'}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:old_password)
    assert_select 'div', :text => /Zmiana hasła nie była możliwa/

    # empty new password
    put :change_password, {:user => {:old_password => 'test', :password => '', :password_confirmation => ''}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:password)

    # passwords don't match
    put :change_password, {:user=> {:old_password => 'test', :password => 'newpass', :password_confirmation => 'newpassdoesntmatch'}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:password)

    # success - password changed
    password = 'newpass'
    put :change_password, {:user => {:old_password => 'test', :password => password, :password_confirmation => 'newpass'}}
    assert_response :redirect
    assert flash.has_key?(:notice)
    assert @response.template_objects['user'].errors.empty?
    assert_redirected_to profile_path

    logout

    # old password no longer works
    post :login, {:user => {:email => @bob.email, :password => 'test'}, :remember => {:me => '0'}}
    assert_response :success
    assert_nil session[:user_id]

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
    put :change_email_address, {:user => {:new_email => 'bob@bob'}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:new_email)

    # collision
    put :change_email_address, {:user => {:new_email => @inactivated.email}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:new_email)
  end

  def test_valid_email_change
    old_email = @bob.email
    email = 'bob@newbob.com'

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
    assert flash.has_key?(:alert)

    # try to activate with bad activation code
    get :activate_new_email_address, {:new_email_activation_code => 'asdf'}
    assert_response :success
    assert flash.has_key?(:alert)

    # logout (activating a new email address should work this way too)
    logout

    # activate new email
    get :activate_new_email_address, {:new_email_activation_code => new_email_activation_code}
    assert_response :redirect
    assert flash.has_key?(:notice)
    assert_redirected_to SimplyAuthenticate::Settings.default_redirect_to

    # email changed successfully
    @bob = User.find(@bob.id)
    assert_equal email, @bob.email
    assert_nil @bob.new_email
    assert_nil @bob.new_email_activation_code

    # we cannot login using the old email
    post :login, {:user => {:email => old_email, :password => 'test'}, :remember => {:me => '0'}}
    assert_response :success
    assert_nil session[:user_id]

    # we can login using new email
    login_as(@bob)
  end

  def test_administrative_user_update
    login_as(@administrator)

    # bad name update
    put :edit, {:id => @administrator.id, :user => {:name => 'x'}, :role => {'administrator' => '1'}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:name)

    # bad password update
    put :edit, {:id => @administrator.id, :user => {:password => '123'}, :role => {'administrator' => '1'}}
    assert_response :success
    assert @response.template_objects['user'].errors.invalid?(:password)

    # correct name and password update
    put :edit, {:id => @administrator.id, :user => {:name => 'MyNewName', :password => 'new-passwd'}, :role => {'administrator' => '1'}}
    assert_response :redirect
    assert flash.has_key?(:notice)

    logout

    # login using new password
    post :login, {:user => {:email => 'john@john.com', :password => 'new-passwd'}, :remember => {:me => '0'}}
    assert_equal @administrator.id, session[:user_id]

    # activate user
    assert !User.find(@inactivated.id).is_activated?
    put :edit, {:id => @inactivated.id, :user => {:is_activated => '1'}, :role => {'user' => '1'}}
    assert_response :redirect
    assert flash.has_key?(:notice)
    assert User.find(@inactivated.id).is_activated?

    # unblock user
    assert User.find(@blocked_activated.id).is_blocked?
    put :edit, {:id => @blocked_activated.id, :user => {:is_blocked => '0'}, :role => {'user' => '1'}}
    assert_response :redirect
    assert flash.has_key?(:notice)
    assert !User.find(@blocked_activated.id).is_blocked?

    # take all user roles
    put :edit, {:id => @bob.id, :user => {}, :role => {}}
    assert_response :redirect
    assert flash.has_key?(:notice)
    assert User.find(@bob.id).roles.empty?

    # add admin role
    put :edit, {:id => @bob.id, :user => {}, :role => {'administrator' => '1'}}
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
    assert_redirected_to login_path
    assert flash.has_key?(:alert)

    # login as administrator
    login_as(@administrator)
    assert User.find(session[:user_id]).roles.collect{|r| r.slug == 'administrator'}.any?

    # access allowed
    get :index
    assert_response :success

    # view our user and confirm his administrator role
    get :show, {:id => @administrator.id}
    assert_response :success
    assert_select 'strong', :text => /administrator/
  end

  private

  def login_as(user, options = {})
    user.reload
    remember_me = options[:remember_me] && options[:remember_me] == true ? '1' : '0'
    password = options[:password] ? options[:password] : 'test' # every user's password in fixtures is 'test'
    login_count = user.login_count

    post :login, {:user => {:email => user.email, :password => password}, :remember => {:me => remember_me}}
    assert @response.has_session_object?(:user_id)
    assert_equal user.id, session[:user_id]
    assert_equal @response.cookies['autologin_token'].present?, remember_me == '1' ? true : false
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
    assert_nil cookies[:autologin_token]
    assert_redirected_to SimplyAuthenticate::Settings.default_redirect_to
  end

end
