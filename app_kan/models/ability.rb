class Ability
  include CanCan::Ability

  def initialize(user)
    can :access, :rails_admin   # grant access to rails_admin
    can :dashboard              # grant access to the dashboard   
    user ||= User.new
  
    if user.admin?
      can [:read], :all

      #Admin: Remove editing from Customers, Orders, Order Items & Photos
      [Customer, OrderItem, Photo].each do |klass|
        cannot [:create, :update, :destroy], klass
      end

      cannot [:create], Order
      can [:download, :shipped, :update, :address], Order

      can [:destroy], [Order]

      can :manage, [Coupon, Product, ProductPhoto, User, Voucher]
    end

  end
end
