require 'open-uri'

class Photo
  include Mongoid::Document
  include Mongoid::Paperclip
  include Mongoid::Timestamps

  has_mongoid_attached_file :image, styles: { thumb: ["100x100#", :jpg] }, 
                                    convert_options: {all: ["-unsharp 0.3x0.3+5+0", "-quality 90%", "-auto-orient"]}, 
                                    processors: [:thumbnail]

  validates_attachment_content_type :image, :content_type => %w(image/png image/jpg image/jpeg image/gif)

  field :photo_info, type: String
  field :checksum, type: String
  field :image_fingerprint, type: String
  field :url, type: String

  field :error, type: String
  field :params, type: String
  field :success, type: Boolean, default: true

  field :attemps_num, type: Integer, default: 0

  MAX_ATTEMPS_NUM = 5

  validates_presence_of :image
  #validates_uniqueness_of :image_fingerprint, message: 'has already existed', scope: :customer_id
  #field :customer_id

  belongs_to :customer

  before_save do
    self.image_file_name = self.image_name
  end

  def image_from_url(url)
    self.url = url
    self.image = open(url)
  end

  def checksum
    image_fingerprint
  end

  def thumbnails_url
    self.image_file_name ? self.image.url(:thumb) : ""
  end

  def image_name
    if image_file_name.to_s.end_with(".jpg") || image_file_name.to_s.end_with(".png") || image_file_name.to_s.end_with(".jpeg") || image_file_name.to_s.end_with(".gif")
      
    else
      first_path = url.to_s.split("?").first
      [".jpg", ".jpeg", ".png", ".gif"].each do |e|
        if first_path.to_s.end_with(e)
          return "#{image_file_name}#{e}"
        end
      end
    end

    image_file_name.to_s
  end

  def self.retry(photo)
    return if photo.success || (photo.attemps_num && photo.attemps_num > MAX_ATTEMPS_NUM)

    if photo.url
      valid_photo_url = false
      first_path = photo.url.to_s.downcase.split("?").first.to_s
      [".jpg", ".jpeg", ".png", ".gif"].each do |e|
        if first_path.end_with(e)
          valid_photo_url = true
          break
        end
      end

      return unless valid_photo_url

      begin
        photo.attemps_num = (photo.attemps_num || 0) + 1
        photo.success = true
        photo.image_from_url(photo.url)
        photo.save
      rescue Exception => e
        photo.attemps_num = (photo.attemps_num || 0) + 1
        photo.save(validate: false)
        Photo.delay.retry(photo)
      end
    end
  end
end
