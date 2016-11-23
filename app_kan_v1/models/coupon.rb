class Coupon
  include Mongoid::Document
  include Mongoid::Timestamps
  field :code, type: String
  field :expiry, type: DateTime
  field :free_shipping, type: Boolean
  field :discount_percentage, type: Float
  field :discount_amount, type: Float
  field :discount_on_product, type: Float
  # field :product_id
  #field :is_used, type: Boolean

  belongs_to :product

  validates_presence_of :code, :expiry

  validates_uniqueness_of :code, message: 'has already existed'

  validates :discount_percentage, :discount_amount, :discount_on_product, :numericality => {:greater_than_or_equal_to => 0}, :allow_blank => true

  validate do 
    if code && code_changed? 
      if Voucher.code_existed?(code) || Coupon.code_existed?(code)
        self.errors.add(:code, 'has already existed')
      end
    end
  end

  ##
  # If the coupon is discount on product, and the product_id != product.id 
  #  => return false
  # Return true if else, or coupon doesn't has discount on product
  ##
  def is_applied_to_product?(product)
    if discount_on_product
      return (product_id == product.id)
    end

    return true
  end

  def self.code_existed?(promotion_code)
    self.where(:code => promotion_code).first   
  end
end

