class Voucher
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :code, type: String
  field :expiry, type: DateTime
  field :purchase_price, type: Float
  field :redeemed, type: Float, default: 0.0
  field :message, type: String
  field :email_address, type: String
  # field :product_id
  field :is_used, type: Boolean
  field :recipient_name, type: String

  #belongs_to :product

  has_and_belongs_to_many :orders, class_name: "Order", inverse_of: :vouchers

  validates_presence_of :code, :expiry, :purchase_price, :redeemed, :message, :is_used, :email_address

  validates :purchase_price, :redeemed, :numericality => {:greater_than_or_equal_to => 0}

  validates_uniqueness_of :code, message: 'has already existed'

  validate do 
    if code && code_changed? 
      if Voucher.code_existed?(code) || Coupon.code_existed?(code)
        self.errors.add(:code, 'has already existed')
      end
    end
  end

  def remaining
    purchase_price - redeemed
  end

  def self.code_existed?(promotion_code)
    self.where(:code => promotion_code).first   
  end

  def to_json
    {
      :code => code, 
      :purchase_price => purchase_price, 
      :redeemed => redeemed, 
      :expiry => expiry, 
      :message => message, 
      :email_address => email_address
    }
  end

  def self.to_json(coll = [])
    coll_json = []
    coll.each do |e|
      coll_json << e.to_json
    end

    coll_json
  end

  def self.get_available_code
    a_code = String.generate_key(:all, 6)
    return self.get_available_code if self.where(:code => a_code).first

    a_code
  end
end
