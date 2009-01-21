module SimplyAuthenticate
  module ActsAsAuthenticated
    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      def acts_as_authenticated
        send :include, InstanceMethods

        class_eval do
          has_and_belongs_to_many :roles

          validates_length_of :email, :within => 5..120, :too_short => "zbyt krótki adres email (minimum 5 znaków)", :too_long => "zbyt długi adres email (max 120 znaków)"
          validates_length_of :new_email, :within => 5..120, :too_short => "zbyt krótki adres email (minimum 5 znaków)", :too_long => "zbyt długi adres email (max 120 znaków)", :allow_blank => true
          validates_length_of :name, :within => 3..30, :too_short => "zbyt krótki pseudonim (minimum 3 znaki)", :too_long => "zbyt długi pseudonim (max 30 znaków)"
          validates_length_of :password, :within => 5..40, :too_short => "zbyt krótkie hasło (minimum 5 znaków)", :too_long => "zbyt długie hasło (max 40 znaków)", :on => :create
          validates_length_of :password, :within => 5..40, :too_short => "zbyt krótkie hasło (minimum 5 znaków)", :too_long => "zbyt długie hasło (max 40 znaków)", :on => :update, :allow_nil => true
          validates_uniqueness_of :email, :message => "istnieje już użytkownik z takim samym adresem email"
          validates_uniqueness_of :name, :message => "istnieje już użytkownik z takim samym imieniem"
          validates_uniqueness_of :slug, :message => "istnieje już użytkownik z takim samym imieniem"
          validates_confirmation_of :password, :message => "błędne potwierdzenie hasła", :on => :create
          validates_confirmation_of :password, :message => "błędne potwierdzenie hasła", :on => :update, :allow_nil => true
          validates_format_of :email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :message => "błędny adres email"
          validates_format_of :new_email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :message => "błędny adres email", :allow_blank => true
          # allow_blank for 'new_email' is ok as this field is usually empty/nil
          # we have another pseudo validation in change_email() for nil/empty value when doing an actual email change


          attr_protected :id, :salt, :activation_code, :activated_on, :autologin_token, :autologin_expires

          attr_accessor :password, :password_confirmation

          before_create :make_activation_code

          before_validation_on_create :make_slug

          # override default ActiveRecord password= method
          alias_method_chain :password=, :hash_creation


          # Class methods

          def self.authenticate(email, pass)
            user = find_by_email(email)
            raise SimplyAuthenticate::Exceptions::UnauthorizedWrongEmail if user.nil?
            raise SimplyAuthenticate::Exceptions::UnauthorizedWrongPassword if self.encrypt(pass + user.salt) != user.hashed_password
            raise SimplyAuthenticate::Exceptions::UnauthorizedNotActivated if !user.activated?
            raise SimplyAuthenticate::Exceptions::UnauthorizedAccountBlocked if user.blocked?
            user
          end

          def self.find_and_send_activation_code!(email)
            user = find_by_email(email)
            raise SimplyAuthenticate::Exceptions::UnauthorizedWrongEmail if !user
            user.send_activation_code
          end

          def self.find_and_activate!(activation_code)
            raise SimplyAuthenticate::Exceptions::ArgumentError if activation_code.blank?
            user = find_by_activation_code(activation_code)
            raise SimplyAuthenticate::Exceptions::BadActivationCode if !user
            raise SimplyAuthenticate::Exceptions::AlreadyActivated if user.activated?
            raise SimplyAuthenticate::Exceptions::UnauthorizedAccountBlocked if user.blocked?
            user.update_attribute(:activated_on, Time.now.utc)
            user
          end

          def self.find_and_reset_password!(email)
            user = find_by_email(email)
            raise SimplyAuthenticate::Exceptions::UnauthorizedWrongEmail if !user
            new_pass = self.random_string(10)
            user.password = user.password_confirmation = new_pass
            user.save
            user.send_forgot_password(new_pass)
          end


          protected

          def self.encrypt(str)
            Digest::SHA1.hexdigest(str)
          end

          # generate a random password consisting of characters and digits
          def self.random_string(len)
            chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
            newpass = ""
            1.upto(len) {|i| newpass << chars[rand(chars.size-1)]}
            return newpass
          end

        end
      end

    end


    module InstanceMethods

      # Custom validation
      def validate
        # Assures that an updated email address does not conflict with any of the existing email addresses
        errors.add(:new_email, 'już istnieje użytkownik z takim adresem email') if self.class.find_by_email(new_email)
      end

      def password_with_hash_creation=(pass)
        @password = pass
        self.salt = self.class.random_string(10) if !self.salt?
        self.hashed_password = self.class.encrypt(@password + self.salt)
      end

      def register_me
        raise SimplyAuthenticate::Exceptions::NotRegistered if !self.save
        self.roles << Role.find_by_function('user')
        return self.send_welcome_message, self.send_activation_code
      end

      def send_activation_code
        Notifications.deliver_activation_code(self.email, self.activation_code)
      end

      def send_welcome_message
        Notifications.deliver_welcome_message(self.email, self.password)
      end

      def send_forgot_password(new_pass)
        Notifications.deliver_forgot_password(self.email, new_pass)
      end

      def send_new_password(new_pass)
        Notifications.deliver_new_password(self.email, new_pass)
      end

      def send_new_email_activation_code
        Notifications.deliver_new_email_activation_code(self.new_email, self.new_email_activation_code)
      end

      def remember_me
        self.autologin_expires = 1.month.from_now
        self.autologin_token = self.class.encrypt(self.salt + self.email + self.autologin_expires.to_s)
        self.save
      end

      def forget_me
        self.autologin_expires = nil
        self.autologin_token = nil
        self.save
      end

      def activated?
        !self.activated_on.blank?
      end

      def blocked?
        self.is_blocked?
      end

      def change_password(params)
        # first check if old password is valid (typing old password is required while changing the password)
        self.class.authenticate(self.email, params[:old_password])
        # only then try to change the password
        raise SimplyAuthenticate::Exceptions::PasswordNotChanged if !self.update_attributes(:password => params[:password], :password_confirmation => params[:password_confirmation])
        self.send_new_password(params[:password])
      end

      def update_profile(params)
        raise SimplyAuthenticate::Exceptions::ProfileNotUpdated if !self.update_attributes(:name => params[:name])
      end

      def change_email(new_email)
        raise SimplyAuthenticate::Exceptions::ArgumentError if new_email.blank?
        self.new_email = new_email
        self.make_new_email_activation_code
        raise SimplyAuthenticate::Exceptions::EmailNotChanged if !self.save
        return self.send_new_email_activation_code
      end

      def activate_new_email(new_email_activation_code)
        raise SimplyAuthenticate::Exceptions::ArgumentError if new_email_activation_code.blank?
        raise SimplyAuthenticate::Exceptions::BadActivationCode if self.new_email_activation_code != new_email_activation_code
        self.email = self.new_email
        self.new_email = nil
        self.new_email_activation_code = nil
        raise SimplyAuthenticate::Exceptions::EmailNotChanged if !self.save
      end


      # Administration methods

      def update_user(params)
        # bypass password validation if password is empty (in other words: no password change)
        params.delete('password') unless params['password'] && params['password'].any?

        # manual user activation
        self.activated_on = Time.now.utc if params['activate'] && params['activate'] == "1"
        params.delete('activate')

        raise SimplyAuthenticate::Exceptions::UserNotUpdated if !self.update_attributes(params)
      end

      def update_roles(params)
        # remove current roles
        raise SimplyAuthenticate::Exceptions::UserNotUpdated if !self.roles.clear

        # add new roles
        params.each do |role, value|
          self.roles << Role.find_by_function(role) if value == "1"
        end
      end

      protected

      def make_activation_code
        self.activation_code = self.class.encrypt(self.salt + Time.now.to_s)
      end

      def make_slug
        # create slug if name is not nil
        self.slug = self.name.to_slug if self.name
      end

      def make_new_email_activation_code
        self.new_email_activation_code = self.class.encrypt(self.salt + self.new_email + Time.now.to_s)
      end

    end
  end

end
