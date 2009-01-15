module SimplyAuthenticate

  # A bunch of custom exceptions to handle authentication logic
  module Exceptions
    class UnauthorizedWrongEmail < StandardError; end
    class UnauthorizedWrongPassword < StandardError; end
    class UnauthorizedNotActivated < StandardError; end
    class UnauthorizedAccountBlocked < StandardError; end
    class BadActivationCode < StandardError; end
    class AlreadyActivated < StandardError; end
    class NotRegistered < StandardError; end
    class PasswordNotChanged < StandardError; end
    class ProfileNotUpdated < StandardError; end
    class UserNotUpdated < StandardError; end
    class EmailNotChanged < StandardError; end
  end

end
