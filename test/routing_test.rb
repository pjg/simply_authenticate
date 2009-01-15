require "#{File.dirname(__FILE__)}/test_helper"

class RoutingTest < Test::Unit::TestCase # ActiveSupport::TestCase 

  def setup
    ActionController::Routing::Routes.draw do |map|
      map.simply_authenticate_routes
    end
  end

  def test_authentication_routes
    controller = SimplyAuthenticate::Settings.controller_name
    path_names = SimplyAuthenticate::Settings.path_names

    assert_recognition :get, path_names[:registration_path], :controller => controller, :action => "register"
    assert_recognition :get, path_names[:activation_path], :controller => controller, :action => "activate", :activation_code => ':activation_code'
    assert_recognition :get, path_names[:send_activation_code_path], :controller => controller, :action => "send_activation_code"
    assert_recognition :get, path_names[:login_path], :controller => controller, :action => "login"
    assert_recognition :get, path_names[:forgot_password_path], :controller => controller, :action => "forgot_password"
    assert_recognition :get, path_names[:profile_path], :controller => controller, :action => "profile"
    assert_recognition :get, path_names[:change_password_path], :controller => controller, :action => "change_password"
    assert_recognition :get, path_names[:change_email_path], :controller => controller, :action => "change_email"
    assert_recognition :get, path_names[:new_email_activation_path], :controller => controller, :action => "activate_new_email", :new_email_activation_code => ':new_email_activation_code'
    assert_recognition :get, path_names[:logout_path], :controller => controller, :action => "logout"

    assert_recognition :get, path_names[:users_path], :controller => controller, :action => "index"
    assert_recognition :get, path_names[:user_show_path], :controller => controller, :action => "show", :id => ':id'
    assert_recognition :get, path_names[:user_edit_path], :controller => controller, :action => "edit", :id => ':id'
  end

  private

  def assert_recognition(method, path, options)
    result = ActionController::Routing::Routes.recognize_path(path, :method => method)
    assert_equal options, result
  end

end
