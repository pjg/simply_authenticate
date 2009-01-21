require File.dirname(__FILE__) + '/../test_helper'

class ActsAsAuthenticatedTest < Test::Unit::TestCase

  def test_fixtures_for_administrator_rights_in_actual_user
    assert @administrator.roles.collect {|r| r.function == 'administrator'}.any?
  end

  def test_email_validations
    u = User.new(:name => "Larry", :password => "passwd", :password_confirmation => "passwd")

    # wrong
    u.email = "wrong@email"
    assert !u.save
    assert u.errors.invalid?('email')

    # empty
    u.email = ""
    assert !u.save
    assert u.errors.invalid?('email')

    # nil
    u.email = nil
    assert !u.save
    assert u.errors.invalid?('email')

    # too long
    u.email = "hugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhugebobhug@bob.com"
    assert !u.save
    assert u.errors.invalid?('email')

    # ok
    u.email = "valid@email.com"
    assert u.save
    assert u.errors.empty?
  end

  def test_password_validations
    u = User.new(:name => "Larry", :email => "my@email.com")

    # too short
    u.password = u.password_confirmation = "tiny"
    assert !u.save
    assert u.errors.invalid?('password')

    # too long
    u.password = u.password_confirmation = "hugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehuge"
    assert !u.save
    assert u.errors.invalid?('password')

    # empty
    u.password = u.password_confirmation = ""
    assert !u.save
    assert u.errors.invalid?('password')

    # ok
    u.password = u.password_confirmation = "bobs_secure_password"
    assert u.save
    assert u.errors.empty?
  end

  def test_name_validations
    u = User.new(:email => "larry@brown.com", :password => "passwd", :password_confirmation => "passwd")

    # too short
    u.name = "B"
    assert !u.save
    assert u.errors.invalid?('name')

    # too long
    u.name = "VeryVeryLongVeryVeryLongVeryVeryLongVeryVeryLongVeryVeryLongVeryVeryLongVeryVeryLongVeryVeryLongName"
    assert !u.save
    assert u.errors.invalid?('name')

    # empty
    u.name = nil
    assert !u.save
    assert u.errors.invalid?('name')

    # ok
    u.name = "Just Bob"
    assert u.save
    assert u.errors.empty?
  end

  def test_collision_validations
    u = User.new(:name => "Larry", :email => "larry@brown.com", :password => "passwd", :password_confirmation => "passwd")

    # name exists
    u.name = "Bob"
    assert !u.save
    assert u.errors.invalid?('name')

    # email exists
    u.name = "Larry"
    u.email = "bob@bob.com"
    assert !u.save
    assert u.errors.invalid?('email')

    # slug exists
    u.name = " Bob "
    u.email = "some@another.bob.com"
    assert !u.save
    assert_equal u.slug, "bob"
  end

  def test_random_string
    new_pass = User.random_string(10)
    assert_not_nil new_pass
    assert_equal 10, new_pass.length
  end

  def test_slug_creation
    u = User.new(:name => "!@ To$Łódź?żółć!pójdź[]do-mnie", :email => "przyjdz@do.mnie.com", :password => "passwd", :password_confirmation => "passwd")
    assert u.save
    assert_equal u.slug, "to-lodz-zolc-pojdz-do-mnie"
  end

  def test_sha1
    u = User.new
    u.name = "Another Bob"
    u.email = "another@bob.com"
    u.salt = "1000"
    u.password = u.password_confirmation = "bobs_secure_password"
    assert u.save
    assert_equal 'b1d27036d59f9499d403f90e0bcf43281adaa844', u.hashed_password
    assert_equal 'b1d27036d59f9499d403f90e0bcf43281adaa844', User.encrypt("bobs_secure_password" + "1000")
  end

  def test_protected_attributes
    u = User.new(:id => 999999, :salt => "I-want-to-set-my-salt", :name => "Bad bob", :email => "bab@bob.com", :password => "new_password", :password_confirmation => "new_password", :activation_code => "12345", :activated_on => "2007-07-07 07:07:07", :autologin_token => "12345", :autologin_expires => "2010-10-10 10:10:10")
    assert u.save
    assert_not_equal 999999, u.id
    assert_not_equal "I-want-to-set-my-salt", u.salt
    assert_not_equal "12345", u.activation_code
    assert_nil u.activated_on
    assert_not_equal "12345", u.autologin_token
    assert_nil u.autologin_expires

    u.update_attributes(:id => 999999, :salt => "I-want-to-set-my-salt", :name => "Very Bad Bob", :activation_code => "12345", :activated_on => "2007-07-07 07:07:07", :autologin_token => "12345", :autologin_expires => "2010-10-10 10:10:10")
    assert u.save
    assert_not_equal 999999, u.id
    assert_not_equal "I-want-to-set-my-salt", u.salt
    assert_not_equal "12345", u.activation_code
    assert_nil u.activated_on
    assert_not_equal "12345", u.autologin_token
    assert_nil u.autologin_expires
    assert_equal "Very Bad Bob", u.name
  end

  def test_invalid_authentication
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedWrongEmail) {User.authenticate("random@email.com", "test")}
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedWrongPassword) {User.authenticate("bob@bob.com", "wrong-password")}
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedNotActivated) {User.authenticate("bill@bill.com", "test")}
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedAccountBlocked) {User.authenticate("kyrlie@kyrlie.com", "test")}
  end

  def test_authentication
    assert_equal @bob, User.authenticate("bob@bob.com", "test")
    assert_equal @administrator, User.authenticate("john@john.com", "test")
  end

  def test_activation
    # nil activation code
    assert_raise(SimplyAuthenticate::Exceptions::ArgumentError) {User.find_and_activate!(nil)}

    # wrong activation code
    assert_raise(SimplyAuthenticate::Exceptions::BadActivationCode) {User.find_and_activate!('f423omfo34i5fo34')}

    # already activated
    assert_raise(SimplyAuthenticate::Exceptions::AlreadyActivated) {User.find_and_activate!('123')}

    # account blocked
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedAccountBlocked) {User.find_and_activate!('456')}

    # not activated
    u = @inactivated
    assert_equal u.name, "Bill Inactivated"
    assert !u.activated?

    # activate user
    u = User.find_and_activate!('345')
    assert_equal u, @inactivated
    assert u.activated?
  end

  def test_registration
    # tested in 'notifications_test.rb'
    assert true
  end

  def test_password_change
    # tested in 'notifications_test.rb'
    assert true
  end

  def test_profile_update
    # valid
    assert_nil @bob.update_profile(:name => "Bob no more")
    assert_equal @bob.name, "Bob no more"

    # invalid
    assert_raise(SimplyAuthenticate::Exceptions::ProfileNotUpdated) {@bob.update_profile(:name => "B")}
  end

  def test_invalid_email_change
    # nil
    assert_raise(SimplyAuthenticate::Exceptions::ArgumentError) {@bob.change_email(nil)}

    # empty
    assert_raise(SimplyAuthenticate::Exceptions::ArgumentError) {@bob.change_email('')}

    # invalid
    assert_raise(SimplyAuthenticate::Exceptions::EmailNotChanged) {@bob.change_email('bob')}

    # collision
    assert_raise(SimplyAuthenticate::Exceptions::EmailNotChanged) {@bob.change_email('bill@bill.com')}
  end

  def test_valid_email_change
    # tested in 'notifications_test.rb'
    assert true
  end

  def test_new_email_activation
    # enter new email
    @administrator.new_email = "new@administrator.com"

    # nil new email activation code
    assert_raise(SimplyAuthenticate::Exceptions::ArgumentError) {@administrator.activate_new_email(nil)}

    # wrong activation code
    assert_raise(SimplyAuthenticate::Exceptions::BadActivationCode) {@administrator.activate_new_email('f423omfo34i5fo34')}

    # activate new email
    assert_not_equal @administrator.email, @administrator.new_email
    @administrator.activate_new_email('1234')
    assert_equal @administrator.email, "new@administrator.com"
    assert @administrator.new_email.nil?
    assert @administrator.new_email_activation_code.nil?
  end

  def test_administrative_update_user
    # activate
    @inactivated.update_user("activate" => "1")
    u = User.find_by_email(@inactivated.email)
    assert_equal u, @inactivated
    assert u.activated?

    # block
    @inactivated.update_user("is_blocked" => "1")
    u = User.find_by_email(@inactivated.email)
    assert_equal u, @inactivated
    assert u.blocked?

    # invalid password change
    assert_raise(SimplyAuthenticate::Exceptions::UserNotUpdated) {@bob.update_user("password" => "123")}

    # valid password change
    @bob.update_user("password" => "new-passwd")

    # new password works
    assert @bob, User.authenticate("bob@bob.com", "new-passwd")
  end

  def test_administrative_update_roles
    # clear roles
    @bob.update_roles({})
    assert @bob.roles.empty?

    # add user role
    @bob.update_roles({'user' => '1'})
    assert_equal @bob.roles.size, 1
    assert @bob.roles.include?(Role.find_by_function('user'))

    # add user and administator role
    @bob.update_roles({'user' => '1', 'administrator' => '1'})
    assert_equal @bob.roles.size, 2
    assert @bob.roles.include?(Role.find_by_function('user'))
    assert @bob.roles.include?(Role.find_by_function('administrator'))
  end

  def test_remember_forget
    assert_nil @bob.autologin_expires
    assert_nil @bob.autologin_token

    # remember
    @bob.remember_me
    assert @bob.autologin_token
    assert_equal @bob.autologin_expires.year, 1.month.from_now.year
    assert_equal @bob.autologin_expires.month, 1.month.from_now.month
    assert_equal @bob.autologin_expires.day, 1.month.from_now.day

    # forget
    @bob.forget_me
    assert_nil @bob.autologin_expires
    assert_nil @bob.autologin_token
  end

end
