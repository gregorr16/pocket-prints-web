module Api
  module V1
    class ProductsController < ApplicationController
      respond_to :json
      before_filter :token_required, only: [:preflight]

      ##
      # @response [
      #  product_id: {type, size, description, main_image_url, [images], price, shipping, requires_photo, width, height}
      #  ..
      # ]
      ##
      def index
        @products = Product.all.order_by([:order, :asc])
      end

      ##
      # Pre-flight - for the purpose of checking shipping, coupons & voucher
      # => Vouchers have a dollar amount and are tied to an email that the voucher is sent to (just to one person). 
      # => Coupons are sent out to multiple people and will have different condidtions such as discount on total order, 
      # => or discount on certain products or free shipping. Both coupons and vouchers expire.
      # @params: 
          # {
          #   promotions: [{promotion_code:abc, voucher_email: fdsfds},{promotion_code: ahdhd;  voucher_email: dajfgajs}],
          #   vourcher_email, (need when promotion is voucher)
          #   products: [
          #     {id: "product_id", quantity: 1, recipient_name, recipient_email, message, gift_value},
          #     {id: "product_id", quantity: 1, recipient_name, recipient_email, message, gift_value}
          #   ]
          # }
      #
      #  @response: voucher/coupon description, discount($), shipping cost, total
      #  @error = "Coupon or Voucher Code can not be found", "Coupon || Voucher has expired", 
      #          "Coupon || Voucher has already been used", "This discount does not apply to your order", 
      #          "Products are out of date"
      ##
      def preflight
        @coupon = nil
        @voucher = nil
        @promotion = nil

        @vouchers = []
        @promotions = []
        @vouchers_ids = []

        expired_vouchers = []
        expired_coupons = []
        used_promotions = []

        promotions_param = params[:promotions]
        unless promotions_param.blank?

          if promotions_param.is_a?(String)
            begin
              promotions_param = ActiveSupport::JSON.decode(promotions_param)
            rescue Exception => e
              @error = I18n.t('discount.in_valid')
              return render_error
            end
          end

          if !promotions_param.is_a?(Array)
            @error = I18n.t('discount.in_valid')
            return render_error
          end

          promotions_param.each do |promotion_hash|
            @promotion = Coupon.where(:code => promotion_hash["promotion_code"]).first
            
            if @coupon && @promotion
              @error = I18n.t('discount.two_coupons_not_allow')
              return render_error
            end

            if @promotion
              @coupon = @promotion

              if @promotion.expiry < Date.today
                expired_coupons << {promotion_code: @promotion.code, type: @promotion.class.to_s, is_expired: true}
              end
            else
              @promotion = Voucher.where(:code => promotion_hash["promotion_code"]).first
              if @voucher = @promotion
                if @voucher.email_address != promotion_hash["voucher_email"]
                  @error = I18n.t('voucher.email_invalid')
                  return render_error
                end

                if @vouchers_ids.index(@voucher.id)
                  @error = I18n.t('discount.duplicated_vouchers')
                  return render_error
                end

                if @promotion.expiry < Date.today
                  expired_vouchers << {promotion_code: @promotion.code, type: @promotion.class.to_s, is_expired: true}
                elsif @promotion.remaining <= 0
                  used_promotions << {promotion_code: @promotion.code, type: @promotion.class.to_s, is_expired: false}
                  #return render_error
                end

                @vouchers << @voucher
                @vouchers_ids << @voucher.id
              end
            end

            if @promotion.nil? && promotion_hash["promotion_code"].present?
              @error = I18n.t('discount.can_not_found')
              return render_error
            end
          end
        end

        expired_promotions = expired_vouchers + expired_coupons

        unless (expired_promotions.blank? && used_promotions.blank?)
          error_msgs = []
          unless expired_vouchers.blank?
            msg = "Voucher #{(expired_vouchers.map { |e| e[:promotion_code] }).join(', ')} #{expired_vouchers.length > 1 ? 'are' : 'is'} expired"
            error_msgs << msg
          end

          unless expired_coupons.blank?
            msg = "Coupon #{(expired_coupons.map { |e| e[:promotion_code] }).join(', ')} #{expired_coupons.length > 1 ? 'are' : 'is'} expired"
            error_msgs << msg
          end

          unless used_promotions.blank?
            msg = "Voucher #{(used_promotions.map { |e| e[:promotion_code] }).join(', ')} #{used_promotions.length > 1 ? 'are' : 'is'} used"
            error_msgs << msg
          end

          @error = error_msgs.join("; ")
          @used_expired_promotions = expired_promotions + used_promotions

          @error_code = 3
          return render_error
        end

        products = params[:products]
        if products.blank?
          render "api/v1/products/promotion"
          return
        end

        if products.is_a?(String)
          begin
            products = ActiveSupport::JSON.decode(products)
          rescue Exception => e
            @error = I18n.t('product.in_valid')
            return render_error
          end
        end

        if !products.is_a?(Array)
          @error = I18n.t('product.in_valid')
          return render_error
        end

        @total = 0.0
        @shipping_cost = 0.0
        max_shipping_cost = 0.0
        @discount = 0.0

        order_products = {}

        #collect products info
        products.each do |pro_hash|
          product = Product.where(:id => pro_hash["id"]).first
          quantity = pro_hash["quantity"].to_i

          if product
            hash_id = product.id.to_s
            if order_products[hash_id] && pro_hash["gift_value"].blank?

            else
              unless pro_hash["gift_value"].blank?
                hash_id = "gift_#{hash_id}"
              end

              unless order_products[hash_id]
                order_products[hash_id] = {
                  product: product,
                  quantity: 0,
                  price: 0,
                  unit_cost: 0,
                  photos: [],
                  quantity_base_on_set: 0,
                  is_gift: false
                }
              end
            end

            if pro_hash["gift_value"].blank?
              order_products[hash_id][:photos] << {
                photo: nil,
                quantity: quantity
              }

              unit_cost = product.price

              order_products[hash_id][:unit_cost] = unit_cost

              order_products[hash_id][:quantity] += quantity
            else
              quantity = 1
              begin
                unit_cost = pro_hash["gift_value"].to_f

                order_products[hash_id][:unit_cost] += unit_cost

                order_products[hash_id][:quantity_base_on_set] = 1
                order_products[hash_id][:quantity] = quantity
                order_products[hash_id][:is_gift] = true
              rescue Exception => e
                @error = I18n.t('voucher.gift_value_invalid')
                return render_error
              end
            end
          else
            @error = []
            @error << I18n.t('product.id_can_not_found', {:id => pro_hash[:id]}) unless product
            return render_error
          end
        end

        #calculate price of each product
        order_products.values.each do |pro|
          product = pro[:product]

          unless pro[:is_gift]
            if product.quantity_set >= 1
              pro[:quantity_base_on_set] = (pro[:quantity] / product.quantity_set.to_f).ceil
            else
              pro[:quantity_base_on_set] = pro[:quantity]
            end
          end

          product_price = pro[:unit_cost] * pro[:quantity_base_on_set]

          if pro[:unit_cost] && @coupon && @coupon.discount_on_product && @coupon.product_id == product.id
            product_discount = @coupon.discount_on_product * pro[:quantity_base_on_set]

            if product_price < product_discount
              @discount += product_price
            else
              @discount += product_discount
            end
          end

          @total += pro[:unit_cost] * pro[:quantity_base_on_set]

          max_shipping_cost = product.shipping if product.shipping > max_shipping_cost
        end

        # Calculate shipping cost
        @shipping_cost = max_shipping_cost if @total < 100
        @total += @shipping_cost

        #coupon coupon_id/voucher_id
        if @coupon
          #Coupon rules: Coupons are available for anyone, but only once. Coupons can expire, and are invalid after their expiry date. 
          #The can only have one of these discounts depending on what is set: If free-shipping is true, make shipping for the order 0.0. 
          #Discount percentage is assigned to the sub-total before shipping. Discount amount is assigned to the sub-total before shipping. 
          #Discount on Product is only assigned to the product referenced.
          if @coupon.free_shipping
            @total -= @shipping_cost
            @shipping_cost = 0.0
          end

          if @coupon.discount_percentage
            @discount += @total*@coupon.discount_percentage/100
          elsif @coupon.discount_amount
            @discount += @coupon.discount_amount
          end
        end

        @total = @total - @discount

        @total = 0.0 if @total < 0.0

        if @vouchers.length > 0
          # Voucher rules: Vouchers are only available to the customer with the same email address of the voucher. 
          # The purchase price is the initial price of the voucher. The redeemed is how much has been used. e.g. 
          # For $100 voucher, $70 has been redeemed, so the voucher is still valid with another $30 remaining. 
          # Once it gets to $0 it is invalid and is used.
          @vouchers.each do |vou|
            voucher_remain = vou.remaining

            if voucher_remain <= 0
              @error = t("voucher.has_been_used", {code: vou.code})
              return render_error
            end

            if voucher_remain <= @total
              @discount += voucher_remain
              @total -= voucher_remain
            else
              @discount += @total
              @total = 0.0
            end
          end
        end

        @total = 0.0 if @total < 0.0
      end

    end
  end
end
