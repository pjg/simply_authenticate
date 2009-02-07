require File.dirname(__FILE__) + '/../test_helper'

class ActsAsAuthenticatedRoleTest < Test::Unit::TestCase

  def test_existing_role
    assert_equal @user_role.function, 'user'
    assert_equal @administrator_role.function, 'administrator'
  end

  def test_creating_invalid_role
    role = Role.new(:function => 'user', :name => 'Użyszkodnik')
    assert !role.save
    assert role.errors.invalid?(:function)
  end

  def test_creating_role
    role = Role.new(:function => 'superuser', :name => 'Super szkodnik')
    assert role.save

    assert_equal role, Role.find_by_function('superuser')
    assert_equal role, Role.find_by_name('Super szkodnik')
  end

end
