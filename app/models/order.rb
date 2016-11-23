require 'net/ftp'
require 'open-uri'
require 'zip'
require 'fileutils.rb'

class Order
  include Mongoid::Document
  include Mongoid::Timestamps

  field :paypal_transaction_token, type: String
  field :stripe_transaction_token, type: String

  field :total, type: Float
  field :shipping_cost, type: Float
  field :name, type: String
  field :email, type: String
  field :voucher_email, type: String
  # field :voucher_id
  # field :coupon_id
  field :coupon_discount
  field :phone
  field :address, type: String
  field :suburb
  field :state
  field :postcode
  # khanhpt added
  field :shipped_date, :type => DateTime
  field :note, :type => String
  # field :customer_id
  # field :product_id

  field :order_code, type: String

  field :error, type: String
  field :params, type: String
  field :success, type: Boolean, default: true

  field :ftp_upload_attempts_num, type: Integer, default: 0

  belongs_to :customer

  #belongs_to :product
  belongs_to :coupon
  has_and_belongs_to_many :vouchers, class_name: "Voucher", inverse_of: :orders

  has_many :order_items, :order => [[:id, :asc]], dependent: :destroy

  validates_presence_of :total, :name, :email, 
    :phone, :address, :suburb, :state, :postcode, :customer_id, :status

  validates :total, :numericality => {:greater_than_or_equal_to => 0}

  #In Admin, add column "Status". The values will be "New Order" & "Shipped". 
  #When the order is shipped, update this status. (Also Status will be editable)
  STATUS = {
    "new" => "New Order",
    "shipped" => "Shipped"
  }

  field :status, type: String, default: STATUS["new"]

  validate do
    if paypal_transaction_token.blank? && stripe_transaction_token.blank? && (total > 0.0 rescue false)
      self.errors.add(:paypal_transaction_token, :blank)
    end
  end

  before_save do
    if self.new_record?
      self.order_code = Order.get_available_code
    end
  end

  def self.get_available_code
    a_code = String.generate_key(:all, 6)
    return self.get_available_code if self.where(:order_code => a_code).first

    a_code
  end

  def shipped?
    self.status == STATUS["shipped"]
  end

  def shipped!
    self.update_attribute(:status, STATUS["shipped"])
    self.update_attribute(:shipped_date, DateTime.now)
    OrderMailer.delay.shipped(self)
  end

  ##
  # products price
  ##
  def products_price
    pros_price = 0
    self.order_items.each do |o_i|
      pros_price += o_i.price * o_i.quantity
    end

    pros_price
  end

  ##
  # Shipping rules: For each product in the inventory, find which product has the higher shipping price. 
  # That then becomes the shipping price for the whole order. 
  # If the total of the order is >= 100.0, then make the shipping free.
  ##
  def shipping
    shipping = self.order_items.max(:shipping)
    
    if products_price >= 100
      shipping = 0
    end

    shipping
  end

  def first_name
    name.split(" ")[0]
  end

  def last_name
    (name.split(" ")[1] || "").strip
  end

  def to_xml(folder = nil)
    file_name = "#{self.order_code}_" + Time.now.strftime('%Y%m%d%H%M%S%L') + ".xml"

    if folder
      file_name = "#{folder}/wrapper.xml"
    else
      file_name = "tmp/#{file_name}"
    end

    File.delete(file_name) if File.exists?(file_name)

    file = File.new(file_name, "wb")
    xml = ::Builder::XmlMarkup.new :target => file

    #TODO: Generate xml tags
    xml.instruct!

    order_attrs = {
      "black_white" => "false", "colour_correction" => "false",
      "custom" => "false", "customer" => "SCO800", "date" => "#{Time.now}", "delivery_type" => "Immediate",
      "enclosed_images" => "true", "is_canvas" => "false",  "is_metal" => "false", "large_print" => "false",
      "minorderfee" => "0.00", "mounting" => "false", "order" => "###", "order_ref" => "#{self.id}", "psd" => "false",
      "save_to_cd" => "false", "save_to_dvd" => "false", "stretching" => "false", "type" => "output", "version" => "1.0", "photographer" => "Pocket Prints"}

    xml.order(order_attrs) do 
      self.order_items.each_with_index do |o_i, index|
        next if o_i.photo.nil? || o_i.photo.image_file_name.nil?
        
        xml.file({"index" => "#{index}", "name" => "#{index}_#{o_i.photo.image_name}"}) do
          xml.product({"code" => "#{o_i.product.code}", "quantity" => "#{o_i.quantity}"})
        end
      end

      xml.special_instructions "None"
      xml.credit_card_details({"on_file" => "true"})

      xml.Customer({"FirstName" => "#{first_name}", "LastName" => "#{last_name}", "Phone1" => "#{phone}", "Phone2" => "", "Email" => "orders@pocketprints.com.au"})
      
      xml.Address({"AddressLine1" => "#{address}", "AddressLine2" => "", "City" => "#{suburb}", "PostCode" => "#{postcode}", "State" => "#{state}", "Country" => "Australia"})
      
    end

    file.close

    file_name
  end

  
  #XML + photos will be uploaded to FTP: ftp://ftp.nulabgroup.com.au
  # if run development mode, photo url should be add the host like "http://192.168.4.177:3000/"
  def upload_to_ftp
    self.order_items.each do |o_i|
      # if o_i.gift_value.nil?
      #   return
      # end
      if (o_i.photo.nil? || o_i.photo.image_file_name.nil?) && o_i.gift_value.nil?
        self.success = false
        self.ftp_upload_attempts_num = (self.ftp_upload_attempts_num || 0) + 1
        self.save(validate: false)
        
        if self.ftp_upload_attempts_num <= 3
          Order.delay(run_at: 15.minutes.from_now).upload_xml_photos(self) 
        else
          OrderMailer.delay.notify_error_retry_ftp_upload_failed(self, "Order Item #{o_i.id} is invalid")
        end
        return
      end
    end

    xml_file = to_xml

    ftp = Net::FTP.open(CONTENT_SERVER_DOMAIN_NAME, CONTENT_SERVER_FTP_LOGIN, CONTENT_SERVER_FTP_PASSWORD)

    ftp.passive = true

    # check if the directory existence
    # create the directory if it does not exist yet
    folder_name = xml_file.split(".xml")[0].split("tmp/")[1]

    ftp.mkdir("/#{folder_name}") if !ftp.list("/").any?{|dir| dir.index(folder_name)}
   
    txt_file_object = File.new(xml_file)
    ftp.putbinaryfile(txt_file_object, "#{folder_name}/wrapper.xml")

    uploaded_photos = {}

    finished = false
    max_attempts = 1000
    errors = []
    
    self.order_items.each_with_index do |o_i, index|
      next if o_i.photo.nil? || o_i.photo.image_file_name.nil?
      finished = false
      while !finished
        begin
          o_photo_url = o_i.photo.image.url

          if uploaded_photos[o_photo_url]
            if uploaded_photos[o_photo_url][:success]
              finished = true
            else
              uploaded_photos[o_photo_url][:attempts] += 1

              if uploaded_photos[o_photo_url][:attempts] > max_attempts
                finished = true
                ftp.close

                Airbrake.notify_or_ignore(Exception.new("Upload Order to FTP Failed: Order #{self.order_code} , Order Item #{o_i.id} , Error: #{errors.uniq.join(', ')}")) if defined?(Airbrake) && Rails.env.production?
                return
              end
            end
          else
            uploaded_photos[o_photo_url] = {
              attempts: 1,
              success: true
            }
          end

          unless finished
            o_photo = open(o_photo_url)
            txt_file_object = File.new(o_photo)
            ftp.putbinaryfile(txt_file_object, "#{folder_name}/#{index}_#{o_i.photo.image_name}")

            finished = true
          end
        rescue Exception => e
          errors << e.message
          
          finished = false
          if uploaded_photos[o_photo_url]
            uploaded_photos[o_photo_url][:success] = false
          else
            uploaded_photos[o_photo_url] = {
              attempts: 1,
              success: false
            }
          end
        end
        
      end

    end

    txt_file_object = File.new("tmp/message.txt")
    ftp.putbinaryfile(txt_file_object, "#{folder_name}/#{File.basename(txt_file_object)}")

    ftp.close
  end

  #XML + photos will be uploaded to FTP: ftp://ftp.nulabgroup.com.au
  # if run development mode, photo url should be add the host like "http://192.168.4.177:3000/"
  def upload_to_sftp
    self.order_items.each do |o_i|
      #if o_i.gift_value.nil?
      #  return
      #end
      logger.debug "khanhdebuggiftmail"
      if (o_i.photo.nil? || o_i.photo.image_file_name.nil?) && o_i.gift_value.nil?
        self.success = false
        self.ftp_upload_attempts_num = (self.ftp_upload_attempts_num || 0) + 1
        self.save(validate: false)
        
        if self.ftp_upload_attempts_num <= 3
          Order.delay(run_at: 15.minutes.from_now).upload_xml_photos(self) 
        else
          OrderMailer.delay.notify_error_retry_ftp_upload_failed(self, "Order Item #{o_i.id} is invalid")
        end
        return
      end
    end

    xml_file = to_xml
    
    # check if the directory existence
    # create the directory if it does not exist yet
    folder_name = xml_file.split(".xml")[0].split("tmp/")[1]

    Dir::mkdir("tmp/#{folder_name}") if Dir["tmp/#{folder_name}"].empty?

    Net::SFTP.start(CONTENT_SERVER_SFTP_DOMAIN_NAME, CONTENT_SERVER_SFTP_LOGIN, password: CONTENT_SERVER_SFTP_PASSWORD) do |sftp|

      sftp.mkdir!("/FTP/#{folder_name}") if !sftp.dir.entries("/FTP").map{ |e| e.name }.any?{|dir| dir.index(folder_name)}
     
      sftp.upload!(xml_file, "/FTP/#{folder_name}/wrapper.xml")

      uploaded_photos = {}

      finished = false
      max_attempts = 1000
      errors = []
      
      self.order_items.each_with_index do |o_i, index|
        next if o_i.photo.nil? || o_i.photo.image_file_name.nil?
        finished = false
        while !finished
          begin
            o_photo_url = o_i.photo.image.url

            if uploaded_photos[o_photo_url]
              if uploaded_photos[o_photo_url][:success]
                finished = true
              else
                uploaded_photos[o_photo_url][:attempts] += 1

                if uploaded_photos[o_photo_url][:attempts] > max_attempts
                  finished = true

                  Airbrake.notify_or_ignore(Exception.new("Upload Order to FTP Failed: Order #{self.order_code} , Order Item #{o_i.id} , Error: #{errors.uniq.join(', ')}")) if defined?(Airbrake) && Rails.env.production?
                  return
                end
              end
            else
              uploaded_photos[o_photo_url] = {
                attempts: 1,
                success: true
              }
            end

            unless finished
              o_photo = open(o_photo_url, &:read)

              File.open("tmp/#{folder_name}/#{index}_#{o_i.photo.image_name}", 'wb') do |file|
                file << o_photo
              end
              sftp.upload!("tmp/#{folder_name}/#{index}_#{o_i.photo.image_name}", "/FTP/#{folder_name}/#{index}_#{o_i.photo.image_name}")

              finished = true
            end
          rescue Exception => e
            errors << e.message
            
            finished = false
            if uploaded_photos[o_photo_url]
              uploaded_photos[o_photo_url][:success] = false
            else
              uploaded_photos[o_photo_url] = {
                attempts: 1,
                success: false
              }
            end
          end
          
        end

      end

      sftp.upload!("tmp/message.txt", "/FTP/#{folder_name}/message.txt")
    end

    FileUtils.rm_rf(folder_name)
    FileUtils.rm_rf(xml_file)
  end

  def self.upload_xml_photos(order)
    order.upload_to_sftp
  end

  ##
  # Zip an order and allow user download it
  ##
  def download!
    folder = "tmp/#{self.order_code}_" + Time.now.strftime('%Y%m%d%H%M%S%L')
    files = []

    # check if the directory existence
    # create the directory if it does not exist yet
    Dir::mkdir(folder) if Dir[folder].empty?

    xml_file = to_xml(folder)

    files << xml_file
    
    self.order_items.each_with_index do |o_i, index|
      next if o_i.photo.nil? || o_i.photo.image_file_name.nil?

      o_photo_url = o_i.photo.image.url

      o_photo = open(o_photo_url, &:read)

      File.open("#{folder}/#{index}_#{o_i.photo.image_name}", 'wb') do |file|
        file << o_photo
      end

      files << "#{folder}/#{index}_#{o_i.photo.image_name}"
    end
    
    File.open("#{folder}/message.txt", 'wb') do |file|
      file << ""
    end
    files << "#{folder}/message.txt"

    ## zip
    Zip::File.open("#{folder}.zip", Zip::File::CREATE) do |zipfile|
      files.each do |file|
        zipfile.add(file.split("/").last, file)
      end
    end

    FileUtils.rm_rf(folder)

    "#{folder}.zip"
  end

  def full_address
    address_parts = []
    [:name, :address, :suburb, :state, :postcode].each do |field|
      address_parts << self[field] if self[field]
    end

    address_parts.join(", ")
  end
end
