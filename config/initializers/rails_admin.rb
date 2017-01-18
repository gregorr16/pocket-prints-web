require 'rails_admin_bulk_upload'
require 'rails_admin_accept'
require 'rails_admin_bulk_accept'
require 'rails_admin_download'
require 'rails_admin_shipped'
require 'rails_admin_address'
require 'rails_admin/config/actions/rails_admin_delete'
require 'csv_converter'

RailsAdmin.config do |config|

  ### Popular gems integration
  config.main_app_name = ['Pocket Prints', 'Admin']
  ## == Devise ==
  # config.current_user_method { current_user } # auto-generated  
  config.authenticate_with do
    warden.authenticate! scope: :user
  end
  config.current_user_method &:current_user
  config.authorize_with :cancan

  config.compact_show_view = false

  config.total_columns_width = 1000

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  ### More at https://github.com/sferik/rails_admin/wiki/Base-configuration

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new
    export
    bulk_delete
    bulk_upload

    download
    shipped
    address

    show
    edit
    delete
    show_in_app

    ## With an audit adapter, you can add:
    # history_index
    # history_show

    config.model User do
      edit do
        field :email, :string
        field :password, :password
        field :password_confirmation, :password
        
        field :admin do
          visible do
            bindings[:view]._current_user.admin?
          end
        end
      end

      list do
        exclude_fields :_id
      end
    end

    config.model Product do
      edit do
        field :code, :string
        field :main_image

        field :type, :string
        field :size, :string
        field :description
        
        field :price
        field :shipping
        field :requires_photo
        field :width do
          help ''
        end
        field :height do
          help ''
        end

        field :visible
        field :order

        field :quantity_set

        field :product_photos
      end

      list do
        sort_by :order, :desc
        field :order do
          sort_reverse true
        end
        field :main_image do
          :iphone4_url
        end
        [:type, :code, :size, :description, :price, :shipping, :requires_photo, :width, :height, :visible, :quantity_set, :product_photos, :created_at].each{|f| field f}
      end
    end


    config.model ProductPhoto do
      edit do
        field :product_type_size do
          read_only true
          visible do
            !bindings[:object].new_record?
          end

          formatted_value do
            bindings[:object].product ? (bindings[:object].product.try(:type).to_s + " " + bindings[:object].product.try(:size).to_s) : ''
          end
          label 'Product Type + Size'
          help ''
        end

        field :product

        field :order
        
        field :photo
      end

      show do
        field :product

        field :order
        
        field :photo
      end

      list do
        sort_by :created_at
        field :product

        field :order

        field :photo do
          :iphone4_url
        end
        field :created_at
      end
    end

    config.model Photo do
      configure :url do
        formatted_value do
          bindings[:view].tag(:a, { :href => bindings[:object].url, :target => "_blank" }) << value
        end
      end

      list do
        sort_by :created_at
        field :image do
          :thumbnails_url
        end

        field :photo_info
        field :checksum
        field :url
        field :success
        field :created_at
      end
    end

    config.model Coupon do
      edit do
        field :code, :string
        field :expiry, :date
        field :free_shipping
        field :discount_percentage do
          help ''
        end
        field :discount_amount do
          help ''
        end
        field :discount_on_product do
          help ''
        end

        field :product
      end

      list do
        sort_by :created_at
        exclude_fields :_id, :updated_at
      end
    end

    config.model Voucher do
      edit do
        field :code, :string
        field :expiry, :date
        field :purchase_price do
          help ''
        end
        field :redeemed do
          help ''
        end
        field :message
        field :email_address, :string
        field :is_used
      end

      list do
        sort_by :created_at
        exclude_fields :_id
      end
    end

    config.model Order do
      edit do
        field :status, :enum do

          enum do
            Order::STATUS.values
          end
        end
        field :note
      end

      list do
        sort_by :created_at
        [:order_code, :name, :email, :total, :status, :success, :created_at, :shipped_date, :note].each{|f| field f}
      end
      show do
        exclude_fields :paypal_transaction_token
      end
    end

    config.model Customer do
      list do
        sort_by :created_at
        [:token, :name, :email, :phone, :orders, :photos, :stripe_customers].each{|f| field f}
      end
    end

    config.model OrderItem do
      list do
        sort_by :created_at
        exclude_fields :_id, :updated_at
      end
    end

    config.model StripeCustomer do
      list do
        sort_by :created_at
        [:customer, :name, :email, :token, :phone, :created_at].each{|f| field f}
      end
    end
  end
end
