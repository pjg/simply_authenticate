require File.dirname(__FILE__) + '/../test_helper'

class ActsAsAuthenticatedRoleTest < ActiveSupport::TestCase

  def test_existing_role
    assert_equal @user_role.slug, 'user'
    assert_equal @administrator_role.slug, 'administrator'
  end

  def test_creating_invalid_role
    # bad name
    role = Role.new(:name => @user_role.name, :slug => 'some-slug')
    assert !role.save
    assert role.errors.invalid?(:name)

    # bad slug
    role = Role.new(:name => 'Nowa rola', :slug => @user_role.slug)
    assert !role.save
    assert role.errors.invalid?(:slug)
  end

  def test_creating_role
    role = Role.new(:name => 'Super szkodnik', :slug => 'superuser')
    assert role.save

    assert_equal role, Role.find_by_slug('superuser')
    assert_equal role, Role.find_by_name('Super szkodnik')
  end

end
