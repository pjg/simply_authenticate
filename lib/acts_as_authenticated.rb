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

          # EMAIL (CREATE/UPDATE) user can be created having only a valid email (this email should be also valid when updating)
          validates_length_of :email, :in => 5..120, :too_short => "zbyt krótki adres email (minimum 5 znaków)", :too_long => "zbyt długi adres email (max 120 znaków)"
          validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, :message => "błędny adres email"
          validates_uniqueness_of :email, :message => "istnieje już użytkownik z takim samym adresem email"

          # NEW_EMAIL (UPDATE) normally this field should be empty/nil; active only when changing email
          # we have another custom validation in change_email_address() for nil/empty value when doing an actual email change
          validates_length_of :new_email, :in => 5..120, :too_short => "zbyt krótki adres email (minimum 5 znaków)", :too_long => "zbyt długi adres email (max 120 znaków)", :allow_blank => true
          validates_format_of :new_email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, :message => "błędny adres email", :allow_blank => true

          # PASSWORD (CREATE) when using .register! method .salt .password .password_confirmation .hashed_password fields are populated
          validates_length_of :password, :in => 5..40, :too_short => "zbyt krótkie hasło (minimum 5 znaków)", :too_long => "zbyt długie hasło (max 40 znaków)", :on => :create
          validates_confirmation_of :password, :message => "błędne potwierdzenie hasła", :on => :create

          # PASSWORD (UPDATE) we can allow password to be blank when updating, but it should be a good password if its not blank
          validates_length_of :password, :in => 5..40, :too_short => "zbyt krótkie hasło (minimum 5 znaków)", :too_long => "zbyt długie hasło (max 40 znaków)", :on => :update, :allow_nil => true
          validates_confirmation_of :password, :message => "błędne potwierdzenie hasła", :on => :update, :allow_nil => true

          # NAME (CREATE) user can have an empty name but if it's not empty, we should have it valid
          validates_length_of :name, :in => 3..30, :too_short => "zbyt krótkie imię/nazwisko (minimum 3 znaki)", :too_long => "zbyt długie imię/nazwisko (max 30 znaków)", :on => :create, :allow_blank => true
          validates_uniqueness_of :name, :message => "istnieje już użytkownik z takim samym imieniem/nazwiskiem", :on => :create, :allow_blank => true
          validates_format_of :name, :with => /^([a-zA-Z0-9_\- ęóąśłżźćńĘÓĄŚŁŻŹĆŃ]+)$/, :message => "imię/nazwisko może zawierać tylko znaki alfanumeryczne", :on => :create, :allow_blank => true

          # NAME (UPDATE) user cannot have an empty name
          validates_length_of :name, :in => 3..30, :too_short => "zbyt krótkie imię/nazwisko (minimum 3 znaki)", :too_long => "zbyt długie imię/nazwisko (max 30 znaków)", :on => :update
          validates_uniqueness_of :name, :message => "istnieje już użytkownik z takim samym imieniem/nazwiskiem", :on => :update, :allow_blank => true
          validates_format_of :name, :with => /^([a-zA-Z0-9_\- ęóąśłżźćńĘÓĄŚŁŻŹĆŃ]+)$/, :message => "imię/nazwisko może zawierać tylko znaki alfanumeryczne", :on => :update

          # SLUG (CREATE) can be empty
          validates_uniqueness_of :slug, :message => "istnieje już użytkownik z takim samym imieniem/nazwiskiem (slug)", :on => :create, :allow_blank => true

          # SLUG (UPDATE) cannot collide
          validates_uniqueness_of :slug, :message => "istnieje już użytkownik z takim samym imieniem/nazwiskiem (slug)", :on => :update, :allow_blank => true

          # GENDER
          # we have custom validate_on_update method to handle gender updates


          # ACTIVATION_CODE is created when adding user
          before_create :make_activation_code

          # SLUG is created ONLY when name is NOT nil and SLUG IS nil (but on BOTH CREATE and UPDATE actions)
          before_validation_on_create :make_slug
          before_validation_on_update :make_slug


          # access to attributes
          attr_protected :id, :salt, :activation_code, :is_activated, :is_blocked, :autologin_token, :autologin_expires
          attr_accessor :password


          # override default ActiveRecord's password= method
          alias_method_chain :password=, :hash_creation


          # Class methods

          def self.authenticate(email, pass)
            user = find_by_email(email)
            raise SimplyAuthenticate::Exceptions::UnauthorizedWrongEmail if user.nil?
            raise SimplyAuthenticate::Exceptions::UnauthorizedWrongPassword if encrypt(pass + user.salt) != user.hashed_password
            raise SimplyAuthenticate::Exceptions::UnauthorizedNotActivated if !user.is_activated?
            raise SimplyAuthenticate::Exceptions::UnauthorizedAccountBlocked if user.blocked?
            user
          end

          def self.find_and_send_activation_code!(email)
            user = find_by_email(email)
            raise SimplyAuthenticate::Exceptions::UnauthorizedWrongEmail if !user
            raise SimplyAuthenticate::Exceptions::AlreadyActivated if user.is_activated?
            user.send_activation_code
            user
          end

          def self.find_and_activate_account!(activation_code)
            raise SimplyAuthenticate::Exceptions::ArgumentError if activation_code.blank?
            user = find_by_activation_code(activation_code)
            raise SimplyAuthenticate::Exceptions::BadActivationCode if !user
            raise SimplyAuthenticate::Exceptions::AlreadyActivated if user.is_activated?
            raise SimplyAuthenticate::Exceptions::UnauthorizedAccountBlocked if user.blocked?

            # must use update_attribute because:
            #   :is_activated is a protected attribute so we cannot update it using update_attributes
            #   :name at this point is NIL so there will be validation errors when using update_attributes
            user.update_attribute(:is_activated, true)
            user.update_attribute(:login_count, (user.login_count + 1))
            user.update_attribute(:activated_on, Time.now)
            user
          end

          def self.find_and_reset_password!(email)
            user = find_by_email!(email)
            # we can have activated user with an empty profile (i.e. no gender), who wants to reset his password; so we bypass all validations here
            user.password = user.password_confirmation = random_string(10)
            user.update_attribute(:hashed_password, encrypt(user.password + user.salt))
            user.send_forgot_password
            user
          end

          def self.find_and_activate_new_email_address!(new_email_activation_code)
            raise SimplyAuthenticate::Exceptions::ArgumentError if new_email_activation_code.blank?
            user = find_by_new_email_activation_code!(new_email_activation_code)
            user.email = user.new_email
            user.new_email = nil
            user.new_email_activation_code = nil
            raise SimplyAuthenticate::Exceptions::EmailNotChanged if !user.save
          end


          protected

          def self.encrypt(str)
            Digest::SHA1.hexdigest(str)
          end

          # generate a random string consisting of characters and digits
          def self.random_string(len)
            chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
            string = ""
            1.upto(len) {|i| string << chars[rand(chars.size-1)]}
            string
          end

        end
      end

    end

    module InstanceMethods

      # Custom validation
      def validate
        # check that NEW_EMAIL does not collide with any existing EMAIL field (when changing email address)
        errors.add(:new_email, 'już istnieje użytkownik z takim adresem email') if self.class.find_by_email(new_email)
      end

      def validate_on_update
        errors.add(:gender_f, 'wymagane jest zadeklarowanie swojej płci') and errors.add(:gender_m, '') if self.gender.blank?
      end

      def email_address_with_name
        "#{self.name} <#{self.email}>"
      end

      def new_email_address_with_name
        "#{self.name} <#{self.new_email}>"
      end

      def password_with_hash_creation=(password)
        return if password.blank?
        self.password_without_hash_creation = password
        self.salt = self.class.random_string(10) if !self.salt?
        self.hashed_password = self.class.encrypt(self.password + self.salt)
      end

      def register!
        self.password = self.password_confirmation = self.class.random_string(10)
        raise SimplyAuthenticate::Exceptions::NotRegistered if !self.save
        self.roles << Role.find_by_slug('user')
        self.send_welcome_message
      end

      def send_welcome_message
        Notifications.deliver_welcome_message(self)
      end

      def send_activation_code
        Notifications.deliver_activation_code(self)
      end

      def send_forgot_password
        Notifications.deliver_forgot_password(self)
      end

      def send_new_password
        Notifications.deliver_new_password(self)
      end

      def send_new_email_activation_code
        Notifications.deliver_new_email_activation_code(self)
      end

      def remember_me
        self.autologin_expires = SimplyAuthenticate::Settings.autologin_expires.to_i.days.from_now
        self.autologin_token = self.class.encrypt(self.salt + self.email + self.autologin_expires.to_s)
        self.save
      end

      def forget_me
        self.autologin_expires = nil
        self.autologin_token = nil
        self.save
      end

      def blocked?
        self.is_blocked?
      end

      def change_password(params)
        # first check if old password is valid (typing old password is required while changing the password)
        self.class.authenticate(self.email, params[:old_password])

        # validations bug workaround (ie: validations work when in production mode but fail to work properly in functional tests)
        # you can comment out the next line and see if tests pass
        self.errors.add('password', 'nowe hasło nie może być puste') && raise(SimplyAuthenticate::Exceptions::PasswordNotChanged) if params[:password].blank?

        # try to change the password
        raise SimplyAuthenticate::Exceptions::PasswordNotChanged if !self.update_attributes(:password => params[:password], :password_confirmation => params[:password_confirmation])
        self.send_new_password
      end

      def update_profile(params)
        # only some parameters can be updated
        params.reject! {|key, value| ![:name, :gender].include?(key.to_sym)}
        raise SimplyAuthenticate::Exceptions::ProfileNotUpdated if !self.update_attributes(params)
      end

      def change_email_address(new_email)
        self.errors.add('new_email', 'adres email nie może być pusty') and raise(SimplyAuthenticate::Exceptions::ArgumentError) if new_email.blank?
        self.new_email = new_email
        self.make_new_email_activation_code
        raise SimplyAuthenticate::Exceptions::EmailNotChanged if !self.save
        self.send_new_email_activation_code
      end

      def update_last_logged_times(opts)
        opts.each do |key, value|
          # some security protection
          next if ![:login_count, :last_ip, :current_ip, :last_logged_on, :current_logged_on].include?(key.to_sym)
          # we must use update_attribute method because this can be executed before filling in the :name attribute (and :name cannot be empty on :update)
          self.update_attribute(key, value)
        end
      end


      # Administration methods

      def update_user(params)
        # :is_activated is a protected attribute and must be handled differently (we cannot use update_attributes)
        if params['is_activated']
          raise SimplyAuthenticate::Exceptions::UserNotUpdated if !self.update_attribute(:is_activated, params['is_activated'])
          params.delete('is_activated')
          params['activated_on'] = Time.now
        end

        # same goes for :is_blocked
        if params['is_blocked']
          raise SimplyAuthenticate::Exceptions::UserNotUpdated if !self.update_attribute(:is_blocked, params['is_blocked'])
          params.delete('is_blocked')
        end

        # normally update other attributes
        raise SimplyAuthenticate::Exceptions::UserNotUpdated if !self.update_attributes(params)
      end

      def update_roles(params)
        # remove current roles
        raise SimplyAuthenticate::Exceptions::UserNotUpdated if !self.roles.clear

        # add new roles
        params.each do |role, value|
          self.roles << Role.find_by_slug(role) if value == "1"
        end
      end

      protected

      def make_activation_code
        self.activation_code = self.class.encrypt(self.salt + Time.now.to_s)
      end

      # SLUG is created ONLY when name is NOT nil and SLUG IS nil
      def make_slug
        self.slug = self.name.to_slug if self.name.present? and self.slug.blank?
      end

      def make_new_email_activation_code
        self.new_email_activation_code = self.class.encrypt(self.salt + self.new_email + Time.now.to_s)
      end

    end
  end

end
