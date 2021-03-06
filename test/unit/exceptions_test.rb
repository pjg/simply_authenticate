require File.dirname(__FILE__) + '/../test_helper'

class ExceptionsTest < ActiveSupport::TestCase

  def test_exceptions
    exceptions = [
      SimplyAuthenticate::Exceptions::ArgumentError,
      SimplyAuthenticate::Exceptions::UnauthorizedWrongEmail,
      SimplyAuthenticate::Exceptions::UnauthorizedWrongPassword,
      SimplyAuthenticate::Exceptions::UnauthorizedNotActivated,
      SimplyAuthenticate::Exceptions::UnauthorizedAccountBlocked,
      SimplyAuthenticate::Exceptions::BadActivationCode,
      SimplyAuthenticate::Exceptions::AlreadyActivated,
      SimplyAuthenticate::Exceptions::NotRegistered,
      SimplyAuthenticate::Exceptions::PasswordNotChanged,
      SimplyAuthenticate::Exceptions::ProfileNotUpdated,
      SimplyAuthenticate::Exceptions::UserNotUpdated,
      SimplyAuthenticate::Exceptions::EmailNotChanged
    ]

    exceptions.each do |e|
      assert_raise(e) {raise e}
    end
  end

end
