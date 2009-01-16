module SimplyAuthenticate
  # acts_as_authenticated methods for ActiveRecord's User model
  module ActsAsAuthenticated
    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods 
      def acts_as_authenticated
        send :include, InstanceMethods

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
      end

      # User.authenticate
      def authenticate(email, pass)
        user = find_by_email(email)
        raise SimplyAuthenticate::Exceptions::UnauthorizedWrongEmail if user.nil?
        raise SimplyAuthenticate::Exceptions::UnauthorizedWrongPassword if self.encrypt(pass + user.salt) != user.hashed_password
        raise SimplyAuthenticate::Exceptions::UnauthorizedNotActivated if !user.activated?
        raise SimplyAuthenticate::Exceptions::UnauthorizedAccountBlocked if user.blocked?
        user
      end
    end

    # User
    module InstanceMethods
      def testing
        "acts_as: 123"
      end
    end
  end

end
