require 'paypal-sdk-rest'
include PayPal::SDK::REST

module Api
  module V1
    class OrdersController < ApplicationController
      respond_to :json
      before_filter :token_required

      ##
      #Create Order  /order.json     POST  
      # @params: 
          # {
          #   paypal_transaction_token: '', 
          #   stripe_token: ,
          #   total: , 
          #   shipping_cost , 
          #   name , email , 
          #   voucher_email , 
          #   promotions: [
          #     {promotion_code, voucher_email}
          #   ], 
          #   phone, address, suburb, state, postcode,
          #   products: [
          #     {id: "product_id", quantity: 1, image_id: "photo_id", frame: true, recipient_name, recipient_email, message, gift_value},
          #     {id: "product_id", quantity: 1, image_id: "photo_id", frame: false, recipient_name, recipient_email, message, gift_value}
          #   ]
          # }
      #
      # @response: success 
      #
      # If there is a difference between the paypal transaction total (access Paypal) and the total in 
      # the request, send an alert email to the admin (this could be fraud). 
      #    =>  no order is created, just send an alert email to admin
      # Also verify (reconcile) 
      # that the total adds up to the products and shipping in the server database.
      #
      # @todo: Check the paypal transaction total with total ...
      ##
      def create
        
        order_params = params.permit(:paypal_transaction_token, :total, :shipping_cost, :name,
          :email, :voucher_email, :voucher_id, :coupon_id, :coupon_discount, :phone,
          :address, :suburb, :state, :postcode, :customer_id, :stripe_transaction_token)

        order_params[:params] = params.to_s

        @order = @customer.orders.create(order_params)

        unless @order.valid?
          @error = @order.errors.full_messages.join(", ")
          error_notify(Exception.new("Error when validate order: #{@error}"))
          return render_error
        end

        @coupon = nil
        @voucher = nil
        @promotion = nil

        @vouchers = []
        @promotions = []
        @vouchers_ids = []

        promotions_param = params[:promotions]
        unless promotions_param.blank?

          if promotions_param.is_a?(String)
            begin
              promotions_param = ActiveSupport::JSON.decode(promotions_param)
            rescue Exception => e
              error_notify(Exception.new("Promotions are invalid: #{e.message}"))
              @error = I18n.t('discount.in_valid')
              return render_error
            end
          end

          if !promotions_param.is_a?(Array)
            error_notify(Exception.new(I18n.t('discount.in_valid')))
            @error = I18n.t('discount.in_valid')
            return render_error
          end

          promotions_param.each do |promotion_hash|
            @promotion = Coupon.where(:code => promotion_hash["promotion_code"]).first
            
            if @coupon && @promotion
              error_notify(Exception.new(I18n.t('discount.two_coupons_not_allow')))
              @error = I18n.t('discount.two_coupons_not_allow')
              return render_error
            end

            if @promotion
              @coupon = @promotion
            else
              @promotion = Voucher.where(:code => promotion_hash["promotion_code"]).first
              if @voucher = @promotion
                if @voucher.email_address != promotion_hash["voucher_email"]
                  error_notify(Exception.new(I18n.t('voucher.email_invalid')))
                  @error = I18n.t('voucher.email_invalid')
                  return render_error
                end

                if @vouchers_ids.index(@voucher.id)
                  error_notify(Exception.new(I18n.t('discount.duplicated_vouchers')))
                  @error = I18n.t('discount.duplicated_vouchers')
                  return render_error
                end

                @vouchers << @voucher
                @vouchers_ids << @voucher.id
              end
            end

            if @promotion
              if @promotion.expiry < Date.today
                error_notify(Exception.new(I18n.t('discount.expired')))
                @error = I18n.t('discount.expired')
                return render_error
              end

              if @promotion.is_a?(Voucher) && @promotion.remaining <= 0
                error_notify(Exception.new(t("voucher.has_been_used", {code: @promotion.code})))
                @error = t("voucher.has_been_used", {code: @promotion.code})
                return render_error
              end

            elsif promotion_hash["promotion_code"].present?
              error_notify(Exception.new(I18n.t('discount.can_not_found')))
              @error = I18n.t('discount.can_not_found')
              return render_error
            end
          end
        end

        products = params[:products]
        if products.is_a?(String)
          begin
            products = ActiveSupport::JSON.decode(products)
          rescue Exception => e
            error_notify(Exception.new("Product is invalid: #{e.message}"))
            @error = I18n.t('product.in_valid')
            return render_error
          end
        end

        if !products.is_a?(Array)
          error_notify(Exception.new("Products are invalid"))
          @error = I18n.t('product.in_valid')
          return render_error

        elsif products.blank?
          error_notify(Exception.new("Products are blank"))
          @error = "Products are blank"
          return render_error
        end

        total = 0.0  # just total price of all order products, not minus discount amount
        shipping_cost = 0.0
        max_shipping_cost = 0.0
        discount = 0.0

        @gift_vouchers = []
        order_products = {}

        #collect products info
        products.each do |pro_hash|
          product = Product.where(:id => pro_hash["id"]).first
          photo = Photo.where(:id => pro_hash["image_id"]).first
          quantity = pro_hash["quantity"].to_i

          if product && (photo || !pro_hash["gift_value"].blank?)
            unless order_products[product.id.to_s]
              order_products[product.id.to_s] = {
                product: product,
                quantity: 0,
                price: 0,
                unit_cost: 0,
                photos: [],
                quantity_base_on_set: 0
              }
            end

            if pro_hash["gift_value"].blank?
              order_products[product.id.to_s][:photos] << {
                photo: photo,
                quantity: quantity
              }

              unit_cost = product.price
            else
              quantity = 1
              unit_cost = pro_hash["gift_value"].to_f
            end

            order_products[product.id.to_s][:quantity] += quantity

            order_products[product.id.to_s][:unit_cost] = unit_cost
          end
        end

        #calculate price of each product
        order_products.values.each do |pro|
          product = pro[:product]

          if product.quantity_set >= 1
            pro[:quantity_base_on_set] = (pro[:quantity] / product.quantity_set.to_f).ceil
          end

          product_price = pro[:unit_cost] * pro[:quantity_base_on_set]

          if pro[:unit_cost] && @coupon && @coupon.discount_on_product && @coupon.product_id == product.id
            product_discount = @coupon.discount_on_product * pro[:quantity_base_on_set]

            if product_price < product_discount
              discount += product_price
            else
              discount += product_discount
            end
          end

          total += pro[:unit_cost] * pro[:quantity_base_on_set]

          max_shipping_cost = product.shipping if product.shipping > max_shipping_cost
        end
        
        products.each do |pro_hash|
          product = Product.where(:id => pro_hash["id"]).first
          photo = Photo.where(:id => pro_hash["image_id"]).first
          quantity = pro_hash["quantity"].to_i

          if product && (photo || !pro_hash["gift_value"].blank?)
            unit_cost = product.price

            if pro_hash["gift_value"].blank?
              
            else
              # Gift Certificate
              quantity = 1
              begin
                unit_cost = pro_hash["gift_value"].to_f
              rescue Exception => e
                error_notify(Exception.new("Gift value is invalid: #{e.message}"))
                @error = I18n.t('voucher.gift_value_invalid')
                return render_error
              end
            end

            order_item_hash = {:quantity => quantity, 
                product_id: product.id, price: unit_cost, type: product.type, 
                size: product.size, description: product.description, shipping: product.shipping,
                width: product.width, height: product.height, frame: pro_hash["frame"], quantity_set: product.quantity_set,
                recipient_name: pro_hash["recipient_name"], recipient_email: pro_hash["recipient_email"],
                gift_message: pro_hash["message"], gift_value: unit_cost
              }

            order_item_hash[:gift_value] = nil if pro_hash["gift_value"].nil?

            order_item_hash[:photo_id] = photo.id if photo

            order_item = @order.order_items.create(order_item_hash)

            unless order_item.valid?
              @error = order_item.errors.full_messages

              return render_error
            end

            # Create gift vouchers
            if pro_hash["recipient_email"] && pro_hash["message"] && pro_hash["recipient_name"]
              gift_voucher = Voucher.create({code: Voucher.get_available_code, expiry: (Time.now.utc.to_date + 1.year), 
                  purchase_price: unit_cost, redeemed: 0.0, message: pro_hash["message"], email_address: pro_hash["recipient_email"], 
                  is_used: false, recipient_name: pro_hash["recipient_name"]})

              unless gift_voucher.valid?
                @error = gift_voucher.errors.full_messages

                return render_error
              end

              @gift_vouchers << gift_voucher
            end
          else
            @error = []
            @error << I18n.t('product.id_can_not_found', {:id => pro_hash["id"]}) unless product
            @error << I18n.t('photo.id_can_not_found', {:id => pro_hash["image_id"]}) if (photo.nil? && pro_hash["gift_value"].nil?)

            error_notify(Exception.new("Product || Photo is not found: #{@error.join(', ')}"))
            return render_error
          end
        end

        # Calculate shipping cost
        shipping_cost = max_shipping_cost if total < 100
        total += shipping_cost

        #coupon coupon_id/voucher_id
        if @coupon
          #Coupon rules: Coupons are available for anyone, but only once. Coupons can expire, and are invalid after their expiry date. 
          #The can only have one of these discounts depending on what is set: If free-shipping is true, make shipping for the order 0.0. 
          #Discount percentage is assigned to the sub-total before shipping. Discount amount is assigned to the sub-total before shipping. 
          #Discount on Product is only assigned to the product referenced.
          if @coupon.free_shipping
            total -= shipping_cost
            shipping_cost = 0.0
          end

          if @coupon.discount_percentage
            discount += total*@coupon.discount_percentage/100

          elsif @coupon.discount_amount
            discount += @coupon.discount_amount
          end

          @order.coupon_id = @coupon.id
        end

        total = total - discount

        total = 0.0 if total < 0.0

        if @vouchers.length > 0
          # Voucher rules: Vouchers are only available to the customer with the same email address of the voucher. 
          # The purchase price is the initial price of the voucher. The redeemed is how much has been used. e.g. 
          # For $100 voucher, $70 has been redeemed, so the voucher is still valid with another $30 remaining. 
          # Once it gets to $0 it is invalid and is used.
          @vouchers.each do |vou|
            voucher_remain = vou.remaining

            if voucher_remain <= 0
              error_notify(Exception.new(t("voucher.has_been_used", {code: vou.code})))
              @error = t("voucher.has_been_used", {code: vou.code})
              return render_error
            end

            if voucher_remain <= total
              total -= voucher_remain

              vou.redeemed += voucher_remain
              vou.is_used = true
            else
              vou.redeemed += total
              total = 0.0
            end

            @order.voucher_ids << vou.id
          end
        end

        #@order.shipping_cost = shipping_cost

        unless @order.save
          @error = @order.errors.full_messages
          return render_error
        end

        @vouchers.each do |vou|
          vou.save
        end

        total = 0.0 if total < 0.0

        has_error = false
        ##Check total
        # Fetch Payment
        puts "#{@order.total}   #{total}"
        if params[:stripe_transaction_token].blank? #Paypal
          if @order.total == 0.0
            if @order.total != total
              OrderMailer.delay.potential_fraud_warning(@order, @order.total, @order.total, total)
            end
          else
            begin
              payment = Payment.find(@order.paypal_transaction_token)
              transactions = payment.transactions.first
              payment_amount = transactions.amount
              paypal_total = payment_amount.total.to_f

              if @order.total != total || @order.total != paypal_total
                OrderMailer.delay.potential_fraud_warning(@order, paypal_total, @order.total, total)
              end  
            rescue Exception => e
              has_error = true
              error_notify(Exception.new("Error when checking paypal after Order is created: #{e.message}"))
            end
          end

        else
          #stripe
          if @order.total == 0.0
            if @order.total != total
              OrderMailer.delay.potential_fraud_warning(@order, total, @order.total, total)
            end
          else
            begin
              charge = Stripe::Charge.retrieve(@order.stripe_transaction_token)

              stripe_total = charge.amount / 100

              if @order.total != total || @order.total.to_i != stripe_total
                OrderMailer.delay.potential_fraud_warning(@order, stripe_total, @order.total, total)
              end

            rescue Exception => e
              has_error = true
              error_notify(Exception.new("Error when checking stripe after Order is created: #{e.message}"))
            end
          end
        end

        begin
          OrderMailer.delay.notify_order(@order)

	  if @gift_vouchers.size == 0
            OrderMailer.delay.created(@order)
	  else
	    logger.debug "khanhdebuggiftmail"
            @gift_vouchers.each do |e|
              OrderMailer.delay.gift_certificates_vouchers_order(@order, e)
	    end
	  end
          Order.delay.upload_xml_photos(@order) unless has_error
          logger.debug "khanhdebug"
          logger.debug @gift_vouchers.size

          ## Send email to recipient
          @gift_vouchers.each do |e|
            OrderMailer.delay.gift_certificates_vouchers(@order, e)
          end

        rescue Exception => e
          has_error = true
          error_notify(Exception.new("Error when checking try to sending email after Order is created: #{e.message}"))
        end
      
      end

      # token, stripe_token, amount, name, email, phone
      def stripe_payment
        if params[:stripe_token].blank?
          @error = I18n.t('order.stripe_token_blank')
          render "api/v1/shared/error"
          return
        end

        begin
          if my_stripe_customer = StripeCustomer.where(:token => params[:stripe_token]).first
            my_stripe_customer.params = "#{my_stripe_customer.params} , #{params.to_s}"
            my_stripe_customer.save
          else
            stripe_customer = Stripe::Customer.create(
              :description => "Customer for Pocket Prints: #{params[:name]}, email: #{params[:email]}, phone: #{params[:phone]}",
              :card  => params[:stripe_token]
            )

            stripe_customer_attr = {token: params[:stripe_token], stripe_id: stripe_customer.id, 
              name: params[:name], email: params[:email], phone: params[:phone], customer_id: @customer.id,
              device_name: params[:device_name], os_version: params[:os_version], params: params.to_s
            }

            my_stripe_customer = StripeCustomer.create(stripe_customer_attr)

            #@customer.update_attributes({ name: params[:name], email: params[:email], phone: params[:phone] })
          end

          @charge = Stripe::Charge.create(
            :customer    => my_stripe_customer.stripe_id,
            :amount      => (params[:amount].to_f * 100).to_i,
            :description => "Payment for Pocket Prints order of Customer: #{params[:name]}, email: #{params[:email]}, phone: #{params[:phone]}",
            :currency    => "AUD"
          )

        rescue Exception => e
          Airbrake.notify_or_ignore(e) if defined?(Airbrake) && Rails.env.production?
          @error = e.message
          my_stripe_customer.update_attributes({error: @error}) if my_stripe_customer
          @error_code = ERROR_CODES[:stripe_paypal_error]
          
          render "api/v1/shared/error"
          return
        end
      end

      private

      def destroy_order
        @order.order_items.destroy_all
        @order.destroy

        if defined?(@gift_vouchers)
          @gift_vouchers.each do |vou|
            vou.destroy
          end
        end
      end

      def render_error
        #destroy_order

        render "api/v1/orders/create"
        return
      end

      def error_notify(exception)
        Airbrake.notify_or_ignore(exception) if defined?(Airbrake) && Rails.env.production?
        
        @order.error = exception.message
        @order.params = params.to_s
        @order.success = false

        @order.save(validate: false)

        OrderMailer.delay.notify_error(@order, exception.message, params)
      end
    end
  end
end
