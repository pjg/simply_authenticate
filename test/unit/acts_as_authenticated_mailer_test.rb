require File.dirname(__FILE__) + '/../test_helper'

class ActsAsAuthenticatedMailerTest < Test::Unit::TestCase

  def setup
    super
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  def test_registration
    # new user
    u = User.new(:name => "Jeremy", :email => "jeremy@boles.com", :password => "password", :password_confirmation => "password")

    # register our new user
    assert_emails 0
    u.register_me
    sent_welcome_message, sent_activation_code = ActionMailer::Base.deliveries
    assert_not_nil sent_welcome_message
    assert_not_nil sent_activation_code
    assert_emails 2

    # check proper role assignment
    assert u.roles.include?(Role.find_by_function('user'))

    # check that we cannot login just yet
    assert !u.activated?
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedNotActivated) {User.authenticate(u.email, u.password)}

    # emails sent
    assert_match /Aktywacja konta w serwisie/, sent_activation_code.subject
    assert_match /Rejestracja w serwisie/, sent_welcome_message.subject

    # to jeremy
    assert_equal u.email, sent_activation_code.to.first
    assert_equal u.email, sent_welcome_message.to.first

    # assume the email got lost and send another email with the activation code
    User.find_and_send_activation_code!(u.email)
    sent_again_activation_code = ActionMailer::Base.deliveries.last

    # email sent
    assert_match /Aktywacja konta w serwisie/, sent_again_activation_code.subject
    assert_emails 3

    # to jeremy
    assert_equal u.email, sent_again_activation_code.to.first

    # fetch first activation code
    first_activation_code = $1 if Regexp.new("\n\n.+\/aktywacja\/(\\w{40})\n\n") =~ sent_activation_code.body
    assert_not_nil first_activation_code

    # fetch second activation code
    second_activation_code = $1 if Regexp.new("\n\n.+\/aktywacja\/(\\w{40})\n\n") =~ sent_again_activation_code.body
    assert_not_nil second_activation_code

    # Compare activation codes
    assert_equal first_activation_code, second_activation_code

    # activate user
    u = User.find_and_activate!(first_activation_code)

    # correct user activated
    assert_equal u.email, "jeremy@boles.com"
    assert_equal u.name, "Jeremy"

    # now we can login
    assert u.activated?
    assert_equal u, User.authenticate("jeremy@boles.com", "password")
  end

  def test_forgot_password
    # check user authenticates
    assert_equal @bob, User.authenticate("bob@bob.com", "test")

    # send new password
    assert_emails 0
    User.find_and_reset_password!("bob@bob.com")
    sent_new_password = ActionMailer::Base.deliveries.first
    assert_not_nil sent_new_password
    assert_emails 1

    # old password no longer valid
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedWrongPassword) {User.authenticate("bob@bob.com", "test")}

    # email sent ...
    assert_match /Twoje nowe hasło/, sent_new_password.subject

    # ... to bob
    assert_equal @bob.email, sent_new_password.to.first

    # can authenticate with the new password
    new_password = $1 if Regexp.new("\n\n(\\w{10})\n\n") =~ sent_new_password.body
    assert_not_nil new_password
    assert_equal @bob, User.authenticate("bob@bob.com", new_password)
  end

  def test_low_level_password_change
    # test that we can login
    assert_equal @bob, User.authenticate("bob@bob.com", "test")

    # low level
    @bob.password = @bob.password_confirmation = "new-passwd"
    assert @bob.save

    # old password is now invalid
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedWrongPassword) {User.authenticate("bob@bob.com", "test")}

    # new password is ok
    assert_equal @bob, User.authenticate("bob@bob.com", "new-passwd")
  end

  def test_password_change_in_model
    # another password change - using model's method
    assert_emails 0
    @administrator.change_password(:old_password => "test", :password => "new-passwd", :password_confirmation => "new-passwd")
    assert_emails 1
    sent_new_password = ActionMailer::Base.deliveries.first

    # email sent
    assert_not_nil sent_new_password
    assert_match /Zmiana hasła/, sent_new_password.subject

    # to administrator
    assert_equal @administrator.email, sent_new_password.to.first

    # fetch new password from email and compare whether it is right
    new_password = $1 if Regexp.new("hasło to:\n\n(.+)\n") =~ sent_new_password.body
    assert_equal "new-passwd", new_password

    # login using new password
    assert_equal @administrator, User.authenticate(@administrator.email, "new-passwd")
  end

  def test_email_change
    # check login
    assert_equal @bob, User.authenticate("bob@bob.com", "test")

    # change email
    assert_emails 0
    @bob.change_email("bob@newbob.com")
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
    u.activate_new_email(new_email_activation_code)

    # check proper field assigment
    assert_nil u.new_email
    assert_nil u.new_email_activation_code
    assert_equal u.email, "bob@newbob.com"

    # check old email no longer works
    assert_raise(SimplyAuthenticate::Exceptions::UnauthorizedWrongEmail) {User.authenticate("bob@bob.com", "test")}

    # check new email works
    assert_equal @bob, User.authenticate("bob@newbob.com", "test")
  end

end
