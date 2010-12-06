class Notifications < ActionMailer::Base
  acts_as_authenticated_mailer
end
