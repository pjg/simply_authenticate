module SimplyAuthenticate
  module ActsAsAuthenticatedMailer
    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      def acts_as_authenticated_mailer
        send :include, InstanceMethods

        class_eval do
          layout 'notifications'
        end
      end
    end

    module InstanceMethods

      # recipient here is a fully fledged User model
      def welcome_message(recipient)
        set_defaults(recipient)
        subject 'Rejestracja w serwisie ' + SimplyAuthenticate::Settings.notifications[:application]
        body :email => recipient.email, :password => recipient.password, :activation_code => recipient.activation_code
      end

      def activation_code(recipient)
        set_defaults(recipient)
        subject 'Aktywacja konta w serwisie ' + SimplyAuthenticate::Settings.notifications[:application]
        body :activation_code => recipient.activation_code
      end

      def forgot_password(recipient)
        set_defaults(recipient)
        subject 'Twoje nowe hasło w serwisie ' + SimplyAuthenticate::Settings.notifications[:application]
        body :password => recipient.password
      end

      def new_password(recipient)
        set_defaults(recipient)
        subject 'Zmiana hasła w serwisie ' + SimplyAuthenticate::Settings.notifications[:application]
        body :password => recipient.password
      end

      def new_email_activation_code(recipient)
        set_defaults(recipient)
        recipients recipient.new_email_address_with_name
        subject 'Zmiana adresu email w serwisie ' + SimplyAuthenticate::Settings.notifications[:application]
        body :new_email_activation_code => recipient.new_email_activation_code
      end

      private

      def set_defaults(recipient)
        recipients recipient.email_address_with_name
        from SimplyAuthenticate::Settings.notifications[:application] + ' <' + SimplyAuthenticate::Settings.notifications[:email] + '>'
      end
    end
  end

end
