class Product
  include Mongoid::Document
  include Mongoid::Paperclip 
  include Mongoid::Timestamps

  field :type, type: String
  field :size, type: String
  field :description, type: String
  
  field :price, type: Float, default: 0.00
  field :shipping, type: Float, default: 0.00
  field :requires_photo, type: Boolean, default: true
  field :width, type: Integer, default: 0
  field :height, type: Integer, default: 0

  field :visible, type: Boolean
  field :order, type: Integer, default: 0

  field :quantity_set, type: Integer, default: 0

  field :code, type: String

  has_mongoid_attached_file :main_image, styles: { iphone4: ["464x464#", :jpg] }, 
                                    convert_options: {all: ["-unsharp 0.3x0.3+5+0", "-quality 90%", "-auto-orient"]}, 
                                    processors: [:thumbnail]

  #has_one :voucher
  #has_one :coupon

  # On creation make these the default: "Requires Photo" is true; "Price" is 0.00; "Shipping" is 0.00; 
  # "Order" is 0. All fields are required except width & height.

  validates_presence_of :type, :size, :description, :main_image, :price, :shipping, :type, :requires_photo, 
    :visible, :order, :quantity_set

  validates_attachment_content_type :main_image, :content_type => %w[image/png image/jpg image/jpeg image/gif]

  validates :width, :height, :numericality => {:greater_than_or_equal_to => 0}

  validates :order, :quantity_set, :numericality => {:greater_than_or_equal_to => 0, :only_integer => true}

  has_many :product_photos, :order => [[:order, :asc]]

  def total
    (price || 0) + (shipping || 0)
  end

  def iphone4_url
    self.main_image.url(:iphone4)
  end

  def name
    type.to_s + " " + size.to_s
  end
end
