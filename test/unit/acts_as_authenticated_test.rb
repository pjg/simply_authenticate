require File.dirname(__FILE__) + '/../test_helper'

class ActsAsAuthenticatedTest < Test::Unit::TestCase

  # COMPLEMENTARY METHODS

  def test_random_string
    (1..10).each do
      new_pass = User.random_string(10)
      assert_not_nil new_pass
      assert_equal 10, new_pass.length
      assert new_pass.match(/[a-zA-Z0-9]{10}/)
    end
  end

  def test_sha1
    u = User.new
    u.name = 'Another Bob'
    u.email = 'another@bob.com'
    u.salt = '1000'
    u.password = u.password_confirmation = 'bobs_secure_password'
    assert u.save
    assert_equal u.hashed_password, 'b1d27036d59f9499d403f90e0bcf43281adaa844'
    assert_equal User.encrypt('bobs_secure_password' + '1000'), 'b1d27036d59f9499d403f90e0bcf43281adaa844'
  end

  def test_email_address_with_name
    assert_equal "#{@bob.name} <#{@bob.email}>", @bob.email_address_with_name
  end

  def test_new_email_address_with_name
    assert @bob.update_attributes(:new_email => 'my@new.shiny.email.pl')
    assert_equal "#{@bob.name} <#{@bob.new_email}>", @bob.new_email_address_with_name
  end


  # FIXTURES

  def test_fixtures_for_administrator_rights_in_actual_user
    assert @administrator.roles.collect {|r| r.function == 'administrator'}.any?
  end


  # VALIDATIONS

  def test_email_validations
    u = User.new
    u.password = u.password_confirmation = '123456' # this will also create .salt and .hashed_password fields (so we don't have to use .register! method here)

    # wrong
    u.email = 'wrong@email'
    assert !u.save
    assert u.errors.invalid?('email')

    # empty
    u.email = ''
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

    # collision
    u.email = @bob.email
    assert !u.save
    assert u.errors.invalid?('email')

    # ok
    u.email = 'valid@email.com'
    assert u.save
    assert u.errors.empty?
  end

  def test_password_validations_on_create
    # too short
    u = User.new(:email => 'my@email.com')
    u.password = u.password_confirmation = 'tiny'
    assert !u.save
    assert u.errors.invalid?('password')

    # too long
    u = User.new(:email => 'my@email.com')
    u.password = u.password_confirmation = 'hugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehuge'
    assert !u.save
    assert u.errors.invalid?('password')

    # empty
    u = User.new(:email => 'my@email.com')
    u.password = u.password_confirmation = ''
    assert !u.save
    assert u.errors.invalid?('password')

    # nil
    u = User.new(:email => 'my@email.com')
    u.password = u.password_confirmation = nil
    assert !u.save
    assert u.errors.invalid?('password')

    # password_confirmation wrong
    u = User.new(:email => 'my@email.com')
    u.password = 'my-new-password'
    u.password_confirmation = 'wrong-confirmation'
    assert !u.save
    assert u.errors.invalid?('password')

    # ok
    u = User.new(:email => 'my@email.com')
    u.password = u.password_confirmation = 'bobs_secure_password'
    assert u.save
    assert u.errors.empty?
  end

  def test_password_validations_on_update
    # too short
    assert !@bob.update_attributes(:password => 'tiny', :password_confirmation => 'tiny')
    assert @bob.errors.invalid?(:password)

    # too long
    params = {:password => 'hugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehugehuge'}
    params[:password_confirmation] = params[:password]
    assert !@bob.update_attributes(params)
    assert @bob.errors.invalid?(:password)

    # empty
    assert !@bob.update_attributes(:password => '', :password_confirmation => '')
    assert @bob.errors.invalid?(:password)

    # nil
    assert !@bob.update_attributes(:password => nil, :password_confirmation => nil)
    assert @bob.errors.invalid?(:password)

    # bad confirmation
    @bob.password = 'good_password'
    @bob.password_confirmation = 'bad_confirmation'
    assert !@bob.save
    assert @bob.errors.invalid?(:password)

    # ok
    @bob.password = 'good_password'
    @bob.password_confirmation = 'good_password'
    assert @bob.save
  end

  # administrator can create users with name attribute being not empty
  def test_name_validations_on_create
    # too short
    u = User.new(:email => 'larry@brown.com', :password => 'passwd')
    u.name = 'B'
    assert !u.save
    assert u.errors.invalid?('name')

    # too long
    u = User.new(:email => 'larry@brown.com', :password => 'passwd')
    u.name = 'VeryVeryLongVeryVeryLongVeryVeryLongVeryVeryLongVeryVeryLongVeryVeryLongVeryVeryLongVeryVeryLongName'
    assert !u.save
    assert u.errors.invalid?('name')

    # non alphanumeric characters
    u = User.new(:email => 'larry@brown.com', :password => 'passwd')
    u.name = ';:!^%()'
    assert !u.save
    assert u.errors.invalid?('name')

    # collision
    u = User.new(:email => 'larry@brown.com', :password => 'passwd')
    u.name = @bob.name
    assert !u.save
    assert u.errors.invalid?('name')

    # can be empty
    u = User.new(:email => 'larry@brown.com', :password => 'passwd')
    u.name = ''
    assert u.save
    assert u.errors.empty?

    # can be nil
    u = User.new(:email => 'james@brown.com', :password => 'passwd')
    assert u.save
    assert u.errors.empty?

    # ok
    u = User.new(:email => 'frank@brown.com', :password => 'passwd')
    u.name = 'Larry Brown'
    assert u.save
    assert u.errors.empty?
  end

  def test_name_validations_on_update
    # empty
    assert !@bob.update_attributes(:name => '')
    assert @bob.errors.invalid?(:name)

    # nil
    assert !@bob.update_attributes(:name => nil)
    assert @bob.errors.invalid?(:name)

    # too short
    assert !@bob.update_attributes(:name => 'xx')
    assert @bob.errors.invalid?(:name)

    # too long
    assert !@bob.update_attributes(:name => 'VeryVeryLongVeryVeryLongVeryVeryLongVeryVeryLongVeryVeryLongVeryVeryLongVeryVeryLongVeryVeryLongName')
    assert @bob.errors.invalid?(:name)

    # non alphanumeric characters
    assert !@bob.update_attributes(:name => ';:!^%()')
    assert @bob.errors.invalid?('name')

    # collision
    assert !@bob.update_attributes(:name => @administrator.name)
    assert @bob.errors.invalid?(:name)
  end

  def test_slug_validations_on_create
    # collision
    u = User.new(:email => 'my@email.com', :password => '12345', :name => @bob.name + '-')
    assert !u.save
    assert u.errors.invalid?(:slug)

    # no name == no slug
    u = User.new(:email => 'my@email.com', :password => '12345')
    assert u.save
    assert_equal '', u.name
    assert_equal '', u.slug

    # valid name == valid slug
    u = User.new(:email => 'some@email.co.uk', :password => '12345', :name => 'Just my name')
    assert u.save
    assert_equal 'just-my-name', u.slug

    # more complicated slug
    u = User.new(:name => '!@ To$Łódź?żółć!pójdź[]do-mnie', :email => 'przyjdz@do.mnie.com', :password => 'passwd')
    assert u.save
    assert_equal 'to-lodz-zolc-pojdz-do-mnie', u.slug
  end

  def test_slug_validations_on_update
    # collision
    assert !@bob.update_attributes(:slug => @administrator.slug)
    assert @bob.errors.invalid?(:slug)
  end


  # PROTECTED ATTRIBUTES

  def test_protected_attributes_on_create
    u = User.new(:id => 999999, :salt => 'I-want-to-set-my-salt', :name => 'Bad bob', :email => 'bab@bob.com', :password => 'new_password', :activation_code => '12345', :is_activated => true, :is_blocked => true, :autologin_token => '12345', :autologin_expires => '2010-10-10 10:10:10')
    assert u.save
    assert_not_equal 999999, u.id
    assert_not_equal 'I-want-to-set-my-salt', u.salt
    assert_not_equal '12345', u.activation_code
    assert !u.is_activated?
    assert !u.is_blocked?
    assert_not_equal '12345', u.autologin_token
    assert_nil u.autologin_expires
  end

  def test_protected_attributes_on_update
    @inactivated.update_attributes(:id => 999999, :salt => 'I-want-to-set-my-salt', :name => 'Very Bad Bob', :activation_code => '12345', :is_activated => true, :autologin_token => '12345', :autologin_expires => '2010-10-10 10:10:10')
    assert @inactivated.save
    assert_not_equal 999999, @inactivated.id
    assert_not_equal 'I-want-to-set-my-salt', @inactivated.salt
    assert_not_equal '12345', @inactivated.activation_code
    assert !@inactivated.is_activated?
    assert_not_equal '12345', @inactivated.autologin_token
    assert_nil @inactivated.autologin_expires
    assert_equal 'Very Bad Bob', @inactivated.name
  end


  # AUTHENTICATION

  def test_invalid_authentication
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedWrongEmail) {User.authenticate('random@email.com', 'test')}
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedWrongPassword) {User.authenticate(@bob.email, 'wrong-password')}
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedNotActivated) {User.authenticate(@inactivated.email, 'test')}
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedAccountBlocked) {User.authenticate(@blocked_activated.email, 'test')}
  end

  def test_authentication
    assert_equal User.authenticate(@bob.email, 'test'), @bob
    assert_equal User.authenticate(@administrator.email, 'test'), @administrator
  end

  # REGISTRATION

  def test_invalid_registration
    u = User.new(:email => 'invalid-email')
    assert_raise(SimplyAuthenticate::Exceptions::NotRegistered) {u.register!}
  end

  def test_registration
    # tested in acts_as_authenticated_mailer_test.rb
  end


  # ACTIVATION

  def test_activation
    assert_raise(SimplyAuthenticate::Exceptions::ArgumentError) {User.find_and_activate_account!(nil)} # nil activation code
    assert_raise(SimplyAuthenticate::Exceptions::BadActivationCode) {User.find_and_activate_account!('f423omfo34i5fo34')} # wrong activation code
    assert_raise(SimplyAuthenticate::Exceptions::AlreadyActivated) {User.find_and_activate_account!(@bob.activation_code)} # already activated
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedAccountBlocked) {User.find_and_activate_account!(@blocked_inactivated.activation_code)} # account blocked

    # activate user
    assert !@inactivated.is_activated?
    login_count = @inactivated.login_count
    u = User.find_and_activate_account!(@inactivated.activation_code)
    assert_equal u, @inactivated
    assert u.is_activated?
    assert_equal login_count + 1, u.login_count
  end


  # PASSWORD (basic tests; rest is tested in acts_as_authenticated_mailer_test.rb)

  def test_password_change
    # test that we can login
    assert_equal @bob, User.authenticate(@bob.email, 'test')

    # change password
    @bob.password = @bob.password_confirmation = 'new-passwd'
    assert @bob.save

    # old password is now invalid
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedWrongPassword) {User.authenticate(@bob.email, 'test')}

    # new password is ok
    assert_equal @bob, User.authenticate(@bob.email, 'new-passwd')
  end


  # PROFILE

  def test_profile_update
    # valid
    assert_nil @bob.update_profile(:name => 'Bob no more')
    assert_equal 'Bob no more', @bob.name

    # invalid
    assert_raise(SimplyAuthenticate::Exceptions::ProfileNotUpdated) {@bob.update_profile(:name => 'B')}
  end


  # EMAIL

  def test_invalid_email_change
    assert_raise(SimplyAuthenticate::Exceptions::ArgumentError) {@bob.change_email_address(nil)} # nil
    assert_raise(SimplyAuthenticate::Exceptions::ArgumentError) {@bob.change_email_address('')} # empty
    assert_raise(SimplyAuthenticate::Exceptions::EmailNotChanged) {@bob.change_email_address('bob')} # invalid
    assert_raise(SimplyAuthenticate::Exceptions::EmailNotChanged) {@bob.change_email_address('bill@bill.com')} # collision
  end

  def test_email_change
    # tested in acts_as_authenticated_mailer_test.rb
  end

  def test_invalid_new_email_activation
    assert_raise(SimplyAuthenticate::Exceptions::ArgumentError) {User.find_and_activate_new_email_address!(nil)} # nil
    assert_raise(SimplyAuthenticate::Exceptions::ArgumentError) {User.find_and_activate_new_email_address!('')} # empty
    assert_raise(ActiveRecord::RecordNotFound) {User.find_and_activate_new_email_address!('f34f32fasfd')} # invalid
  end

  def test_new_email_activation
    # tested in acts_as_authenticated_mailer_test.rb
  end

  def test_update_last_logged_times
    slug = 'abcdefg'
    login_count = 10
    current_logged_on = Time.now

    @bob.update_last_logged_times(:slug => slug, :login_count => login_count, :current_logged_on => current_logged_on)
    @bob.reload

    # slug should not be updated
    assert_not_equal slug, @bob.slug

    # rest should be updated
    assert_equal login_count, @bob.login_count
    assert_equal current_logged_on.iso8601, @bob.current_logged_on.iso8601
  end

  def test_administrative_update_user
    # activate
    @inactivated.update_user('is_activated' => '1')
    u = User.find_by_email(@inactivated.email)
    assert_equal u, @inactivated
    assert u.is_activated?

    # block
    @inactivated.update_user('is_blocked' => '1')
    u = User.find_by_email(@inactivated.email)
    assert_equal u, @inactivated
    assert u.blocked?

    # invalid password change
    assert_raise(SimplyAuthenticate::Exceptions::UserNotUpdated) {@bob.update_user('password' => '123')}

    # valid password change (to blank; old password should work)
    assert_nothing_raised {@administrator.update_user(:password => '', :password_confirmation => '')}
    assert_equal User.authenticate(@administrator.email, 'test'), @administrator

    # valid password change (to new password; new password should work)
    @bob.update_user('password' => 'new-passwd')
    assert_equal User.authenticate('bob@bob.com', 'new-passwd'), @bob
  end

  def test_administrative_update_roles
    # clear roles
    @bob.update_roles({})
    assert @bob.roles.empty?

    # add user role
    @bob.update_roles({'user' => '1'})
    assert_equal 1, @bob.roles.size
    assert @bob.roles.include?(Role.find_by_function('user'))

    # add user and administator role
    @bob.update_roles({'user' => '1', 'administrator' => '1'})
    assert_equal 2, @bob.roles.size
    assert @bob.roles.include?(Role.find_by_function('user'))
    assert @bob.roles.include?(Role.find_by_function('administrator'))
  end

  def test_remember_forget
    assert_nil @bob.autologin_expires
    assert_nil @bob.autologin_token

    # remember
    @bob.remember_me
    assert @bob.autologin_token
    assert_equal 2.months.from_now.year, @bob.autologin_expires.year
    assert_equal 2.months.from_now.month, @bob.autologin_expires.month
    assert_equal 2.months.from_now.day, @bob.autologin_expires.day

    # forget
    @bob.forget_me
    assert_nil @bob.autologin_expires
    assert_nil @bob.autologin_token
  end

end
