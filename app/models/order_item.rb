class OrderItem
  include Mongoid::Document
  include Mongoid::Timestamps
  # field :product_id
  # field :photo_id
  # field :order_id
  field :quantity, type: Integer

  #The fields: type, size, description, price, shipping, width, height 
  # -> are a copy of the product table fields at the time of the order.
  field :type, type: String
  field :size
  field :description, type: String
  field :price, type: Integer
  field :shipping, type: Integer
  field :width, type: Integer
  field :height, type: Integer

  field :quantity_set, type: Integer, default: 0

  field :frame, type: Boolean

  belongs_to :product
  belongs_to :photo
  belongs_to :order

  #for Gift Certificate: recipient_name, recipient_email, message, gift_value
  field :recipient_name, type: String
  field :recipient_email, type: String
  field :gift_message, type: String
  field :gift_value, type: Float

  validates_presence_of :quantity, :type, :size, :description, :price, :shipping,
    :product_id, :order_id, :quantity_set

  validates :width, :height, :numericality => {:greater_than_or_equal_to => 0}

  validates :quantity, :numericality => {:greater_than_or_equal_to => 0}

  validates :gift_value, :numericality => {:greater_than_or_equal_to => 0}, :allow_blank => true

  validates :photo_id, :presence => true, :if => :not_gift?

  def not_gift?
    gift_value ? false : true
  end
end
