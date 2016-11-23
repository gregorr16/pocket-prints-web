class ProductPhoto
  include Mongoid::Document
  include Mongoid::Paperclip
  include Mongoid::Timestamps
  #field :product_id
  
  field :order, type: Integer, default: 0

  has_mongoid_attached_file :photo, styles: {   iphone4: ["640x530#", :jpg] }, 
                                    convert_options: {all: ["-unsharp 0.3x0.3+5+0", "-quality 90%", "-auto-orient"]}, 
                                    processors: [:thumbnail]

  field :product_type_size, type: String #just to show product type size 

  validates_presence_of :photo, :order

  validates_attachment_content_type :photo, :content_type => %w[image/png image/jpg image/jpeg image/gif]

  validates :order, :numericality => {:greater_than_or_equal_to => 0, :only_integer => true}

  belongs_to :product

  def iphone4_url
    self.photo.url(:iphone4)
  end
end
