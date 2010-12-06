# Define Settings helpers here so that when the host Rails application does disable password reset or registering, the test will still pass.
module SimplyAuthenticate
  module Helpers
    def password_reset_allowed?
      true
    end

    def registration_allowed?
      true
    end

    def password_change_allowed?
      true
    end
  end
end
