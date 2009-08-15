require File.dirname(__FILE__) + '/../test_helper'

class ActsAsAuthenticatedMailerTest < ActiveSupport::TestCase

  def setup
    super
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  # just some basic tests; more comprehensive test are in 'helpers_test.rb'
  def test_registration
    assert_emails 0
    email = "jeremy@boles.com"
    u = User.new(:email => email)
    assert_nothing_raised {u.register!}
    assert_emails 1

    email_sent = ActionMailer::Base.deliveries.first
    assert_not_nil email_sent
    password = email_sent.body[/Hasło: (\w+)$/, 1]
    activation_code = email_sent.body[/aktywacja\/(\w+)$/, 1]
    assert_not_nil password
    assert_not_nil activation_code

    # check that we cannot login just yet
    assert !u.is_activated?
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedNotActivated) {User.authenticate(u.email, u.password)}

    # assume the email got lost and send another email with the activation code
    User.find_and_send_activation_code!(u.email)
    assert_emails 2
    second_email_sent = ActionMailer::Base.deliveries.second
    assert_not_nil second_email_sent
    second_activation_code = second_email_sent.body[/aktywacja\/(\w+)$/, 1]
    assert_equal second_activation_code, activation_code

    # activate user
    u = User.find_and_activate_account!(activation_code)

    # correct user activated
    assert_equal u.email, email

    # now we can login
    assert u.is_activated?
    assert_equal u, User.authenticate(email, password)
  end

  def test_forgot_password
    # send new password
    assert_emails 0
    User.find_and_reset_password!(@bob.email)
    email_sent = ActionMailer::Base.deliveries.first
    assert_emails 1
    assert_not_nil email_sent
    password = email_sent.body[/\n\n(\w{10})\n\n/, 1]
    assert_not_nil password

    # old password no longer valid
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedWrongPassword) {User.authenticate(@bob.email, "test")}

    # new password works
    assert_equal @bob, User.authenticate(@bob.email, password)
  end

  def test_invalid_password_change
    # bad old password
    params = {}
    params[:old_password] = 'bad-password'
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedWrongPassword) {@bob.change_password(params)}

    # too short
    params = {:old_password => 'test'}
    params[:password] = params[:password_confirmation] = 'tiny'
    assert_raise(SimplyAuthenticate::Exceptions::PasswordNotChanged) {@bob.change_password(params)}
    assert @bob.errors.invalid?(:password)

    # empty
    params[:password] = params[:password_confirmation] = ''
    assert_raise(SimplyAuthenticate::Exceptions::PasswordNotChanged) {@bob.change_password(params)}
    assert @bob.errors.invalid?(:password)

    # nil
    params[:password] = params[:password_confirmation] = nil
    assert_raise(SimplyAuthenticate::Exceptions::PasswordNotChanged) {@bob.change_password(params)}
    assert @bob.errors.invalid?(:password)

    # bad confirmation
    params[:password] = 'new-password'
    params[:password_confirmation] = 'bad-confirmation'
    assert_raise(SimplyAuthenticate::Exceptions::PasswordNotChanged) {@bob.change_password(params)}
    assert @bob.errors.invalid?(:password)
  end

  def test_change_password
    assert_emails 0
    assert_nothing_raised {@administrator.change_password(:old_password => "test", :password => "newpasswrd", :password_confirmation => "newpasswrd")}
    assert_emails 1
    email_sent = ActionMailer::Base.deliveries.first

    # email sent
    assert_not_nil email_sent
    assert_match /Zmiana hasła/, email_sent.subject

    # to administrator
    assert_equal @administrator.email, email_sent.to.first

    # fetch new password from email and compare whether it is right
    new_password = email_sent.body[/\n\n(\w{10})\n\n/, 1]
    assert_equal "newpasswrd", new_password

    # authenticate using the new password
    assert_equal @administrator, User.authenticate(@administrator.email, "newpasswrd")
  end

  def test_email_change
    # check login
    assert_equal @bob, User.authenticate(@bob.email, "test")

    # change email
    assert_emails 0
    @bob.change_email_address("bob@newbob.com")
    sent_new_email_activation_code = ActionMailer::Base.deliveries.first
    assert_not_nil sent_new_email_activation_code
    assert_emails 1

    # email sent
    assert_match /Zmiana adresu email/, sent_new_email_activation_code.subject

    # to bob
    u = User.find(@bob.id)
    assert_equal u.new_email, sent_new_email_activation_code.to.first

    # fetch new email activation code
    new_email_activation_code = $1 if Regexp.new("\n\n.+\/aktywacja-nowego-adresu-email\/(\\w{40})\n\n") =~ sent_new_email_activation_code.body

    # check proper field assigment
    assert_equal u.email, "bob@bob.com"
    assert_equal u.new_email, "bob@newbob.com"
    assert_equal u.new_email_activation_code, new_email_activation_code

    # activate new email
    User.find_and_activate_new_email_address!(new_email_activation_code)

    # check proper field assigment
    u = User.find(@bob.id)
    assert_nil u.new_email
    assert_nil u.new_email_activation_code
    assert_equal u.email, "bob@newbob.com"

    # check old email no longer works
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedWrongEmail) {User.authenticate("bob@bob.com", "test")}

    # check new email works
    assert_equal @bob, User.authenticate("bob@newbob.com", "test")
  end

end
