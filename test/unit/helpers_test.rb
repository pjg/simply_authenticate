require File.dirname(__FILE__) + '/../test_helper'
require 'action_controller'
require 'action_controller/test_process'

class MockController < ActionController::Base
  def index
  end

  private

  def rescue_action(e)
    raise e unless ActionView::MissingTemplate # no templates
  end
end

class HelpersTest < Test::Unit::TestCase

  include SimplyAuthenticate::Helpers

  def setup
    @controller = MockController.new
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new

    ActionController::Routing::Routes.draw do |map|
      map.root :controller => 'mock'
    end
  end

  def test_logged_in
    # not yet logged in
    get :index
    assert !logged_in?

    # setup session & check again
    session[:user_id] = @bob.id
    assert logged_in?
  end

  def test_load_invalid_user_from_session
    get :index
    session[:user_id] = 54151515616
    assert_raise(ActiveRecord::RecordNotFound) {load_user}
    assert_equal @current_user, nil
  end

  def test_load_user_from_session
    get :index
    session[:user_id] = @bob.id
    load_user
    assert_equal @current_user, @bob
  end

  def test_roles
    get :index

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

end
