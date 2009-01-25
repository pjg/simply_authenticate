module SimplyAuthenticate
  # acts_as_authenticated_role methods for ActiveRecord's Role model
  module ActsAsAuthenticatedRole
    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods 
      def acts_as_authenticated_role
        has_and_belongs_to_many :users

        validates_uniqueness_of :function, :message => "istnieje już taka rola w systemie"
      end
    end
  end

end
