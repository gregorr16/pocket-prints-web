require 'spec_helper'

describe "Order API" do
 
  describe "POST order" do
    context "works" do
      before(:each) do
        Order.destroy_all
        OrderItem.destroy_all
        Coupon.destroy_all
        Voucher.destroy_all
        Photo.destroy_all
        Product.destroy_all

        @customer = create :customer
        @product = create :product
        @coupon = create :coupon, product_id: @product.id
        @voucher = create :voucher
        @order = build :order
        @photo = create :photo
      end

      it "return error if order invalid" do

        post 'api/v1/order.json', {token: @customer.token}

        expect(Order.all.length).to eql(1)

        ord = Order.first
        expect(ord.success).to eq(false)
        expect(ord.error.index("Error when validate order:")).to eql(0)

        expect(json["result"]).to eq("success")
      end

      it "return error if coupon/voucher is not found" do
        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: "dsfsd"}]

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(Order.all.length).to eql(1)

        ord = Order.first
        expect(ord.success).to eq(false)
        expect(ord.error).to eq(I18n.t('discount.can_not_found'))

        expect(json["result"]).to eq("success")
      end

      it "return error if coupon discount expired" do
        @coupon.update_attribute(:expiry, Date.today - 2.days)
        
        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: @coupon.code}]

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(Order.all.length).to eql(1)

        ord = Order.first
        expect(ord.success).to eq(false)
        expect(ord.error).to eq(I18n.t('discount.expired'))

        expect(json["result"]).to eq("success")
      end

      it "return success if all order and order items are valid" do
        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: @coupon.code}]
        order_params[:products] = []
        order_params[:products] << {id: @product.id.to_s, quantity: 1, image_id: @photo.id.to_s, frame: true}

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(Order.all.length).to eql(1)

        ord = Order.first
        expect(ord.success).to eq(true) #need update when app go live

        expect(json["result"]).to eq("success")
      end

      it "return error if product is not found" do
        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: @coupon.code}]
        order_params[:products] = []
        order_params[:products] << {id: "id", quantity: 1, image_id: @photo.id.to_s, frame: true}

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(Order.all.length).to eql(1)

        ord = Order.first
        expect(ord.success).to eq(false)
        expect(ord.error).to eq("Product || Photo is not found: #{I18n.t('product.id_can_not_found', {:id => "id"})}")

        expect(json["result"]).to eq("success")
      end

      it "return error if product is blank" do
        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: @coupon.code}]
        order_params[:products] = "[\n\n]"

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(Order.all.length).to eql(1)

        ord = Order.first
        expect(ord.success).to eq(false)
        expect(ord.error).to eq("Products are blank")

        expect(json["result"]).to eq("success")
      end

      it "return error if photo is not found" do
        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: @coupon.code}]
        order_params[:products] = []
        order_params[:products] << {id: @product.id.to_s, quantity: 1, image_id: "id", frame: true}

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(Order.all.length).to eql(1)

        ord = Order.first
        expect(ord.success).to eq(false)
        expect(ord.error).to eq("Product || Photo is not found: #{I18n.t('photo.id_can_not_found', {:id => "id"})}")

        expect(json["result"]).to eq("success")
      end

      it "return error if product, photo are not found" do
        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: @coupon.code}]
        order_params[:products] = []
        order_params[:products] << {id: "id", quantity: 1, image_id: "id", frame: true}

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(Order.all.length).to eql(1)

        ord = Order.first
        expect(ord.success).to eq(false)
        expect(ord.error).to eq("Product || Photo is not found: #{[I18n.t('product.id_can_not_found', {:id => 'id'}), I18n.t('photo.id_can_not_found', {:id => 'id'})].join(', ')}")

        expect(json["result"]).to eq("success")
      end

      it "return error when duplicated_vouchers" do
        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: @voucher.code, voucher_email: @voucher.email_address}, {promotion_code: @voucher.code, voucher_email: @voucher.email_address}]
        order_params[:products] = []
        order_params[:products] << {id: @product.id.to_s, quantity: 1, image_id: @photo.id, frame: true}

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(Order.all.length).to eql(1)

        ord = Order.first
        expect(ord.success).to eq(false)
        expect(ord.error).to eq(I18n.t('discount.duplicated_vouchers'))

        expect(json["result"]).to eq("success")
      end


      it "return success and shipping_cost is auto calculated" do
        order_params = @order.attributes.except('id', '_id')
        order_params[:products] = []
        order_params[:products] << {id: @product.id.to_s, quantity: 1, image_id: @photo.id.to_s, frame: true}

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(json["error"]).to be_nil
        expect(Order.all.length).to eq(1)
        expect(OrderItem.all.length).to eq(1)

        order = Order.first
        
        expect(order.shipping_cost).to eq(@order.shipping_cost)
        expect(order.order_items.length).to eq(1)

        expect(order.success).to eq(true)  #failed paypal

        expect(json["result"]).to eq("success")
      end

      it "return success and the total is discounted base on coupon: free_shipping" do
        @coupon.update_attribute(:free_shipping, true)

        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: @coupon.code}]
        order_params[:products] = []
        order_params[:products] << {id: @product.id.to_s, quantity: 1, image_id: @photo.id.to_s, frame: true}

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(json["error"]).to be_nil
        expect(Order.all.length).to eq(1)
        expect(OrderItem.all.length).to eq(1)
        
        order = Order.first
        
        expect(order.shipping_cost).to eq(@order.shipping_cost)
        expect(order.order_items.length).to eq(1)

        expect(order.success).to eq(true) #failed paypal

        expect(json["result"]).to eq("success")
      end

      it "return success and the total is discounted base on coupon: Discount Percentage" do
        @coupon.update_attribute(:discount_percentage, 20)

        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: @coupon.code}]
        order_params[:products] = []
        order_params[:products] << {id: @product.id.to_s, quantity: 1, image_id: @photo.id.to_s, frame: true}

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)
        
        order = Order.first

        expect(order.total).to eq(@order.total)

        expect(order.success).to eq(true)

        expect(json["result"]).to eq("success")
      end

      it "return success and the total is discounted base on coupon: Discount Amount" do
        @coupon.update_attributes({discount_amount: 20, discount_percentage: nil})

        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: @coupon.code}]
        order_params[:products] = []
        order_params[:products] << {id: @product.id.to_s, quantity: 1, image_id: @photo.id.to_s, frame: true}

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        order = Order.first

        expect(order.total).to eq(@order.total)

        expect(order.success).to eq(true)
        #expect(order.error.index("Error when checking paypal after Order is created: ")).to eq(0)

        expect(json["result"]).to eq("success")
      end


      it "return error if the voucher is used" do
        @voucher.update_attributes({purchase_price: 20, redeemed: 20, is_used: true})

        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: @voucher.code, voucher_email: @voucher.email_address}]
        order_params[:products] = []
        order_params[:products] << {id: @product.id.to_s, quantity: 1, image_id: @photo.id.to_s, frame: false}

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(Order.all.length).to eq(1)

        order = Order.first
        expect(order.success).to eq(false)
        expect(order.error).to eq(I18n.t("voucher.has_been_used", {code: @voucher.code}))

        expect(json["result"]).to eq("success")
      end

      it "return error if the voucher is used & products are blank" do
        @voucher.update_attributes({purchase_price: 20, redeemed: 20, is_used: true})

        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: @voucher.code, voucher_email: @voucher.email_address}]
        order_params[:products] = []

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(Order.all.length).to eq(1)

        order = Order.first
        expect(order.success).to eq(false)
        expect(order.error).to eq(I18n.t("voucher.has_been_used", {code: @voucher.code}))

        expect(json["result"]).to eq("success")
      end

      it "return error if the voucher email is invalid" do
        @voucher.update_attributes({purchase_price: 20, redeemed: 20, is_used: true})

        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: @voucher.code, voucher_email: ""}]
        order_params[:products] = []
        order_params[:products] << {id: @product.id.to_s, quantity: 1, image_id: @photo.id.to_s, frame: true}

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(Order.all.length).to eq(1)

        order = Order.first
        expect(order.success).to eq(false)
        expect(order.error).to eq(I18n.t("voucher.email_invalid"))

        expect(json["result"]).to eq("success")
      end

      it "return success and total is discount if has valid voucher " do
        @product.update_attributes({price: 10, quantity_set: 2, shipping: 0})
        @voucher.update_attributes({purchase_price: 20, redeemed: 0, is_used: false})

        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: @voucher.code, voucher_email: @voucher.email_address}]
        order_params[:products] = []
        order_params[:products] << {id: @product.id.to_s, quantity: 1, image_id: @photo.id.to_s, frame: true}

        total = 10

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(Order.all.length).to eq(1)

        order = Order.first
        if @voucher.remaining <= total
          expect(order.total).to eq(@order.total)

          expect(@voucher.reload.is_used).to eq(true)
          expect(@voucher.remaining).to eq(0)
        else
          expect(order.total).to eq(@order.total)

          old_voucher_remaining = @voucher.remaining

          expect(@voucher.reload.remaining).to eq(old_voucher_remaining - total)
        end
        
        expect(@voucher.order_ids.index(order.id)).to eq(0)

        expect(order.voucher_ids.index(@voucher.id)).to eq(0)

        expect(order.success).to eq(true)

        expect(json["result"]).to eq("success")
      end

      it "with two photos & it return success and total is discount if has valid voucher " do
        @product.update_attributes({price: 10, quantity_set: 2, shipping: 0})
        @voucher.update_attributes({purchase_price: 20, redeemed: 0, is_used: false})
        total = 10

        order_params = @order.attributes.except('id', '_id')
        order_params[:promotions] = [{promotion_code: @voucher.code, voucher_email: @voucher.email_address}]
        order_params[:products] = []
        order_params[:products] << {id: @product.id.to_s, quantity: 1, image_id: @photo.id.to_s, frame: true}
        order_params[:products] << {id: @product.id.to_s, quantity: 1, image_id: @photo.id.to_s, frame: true}

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(Order.all.length).to eq(1)

        order = Order.first
        expect(order.total).to eq(@order.total)
        
        if @voucher.remaining <= total

          expect(@voucher.reload.is_used).to eq(true)
          expect(@voucher.remaining).to eq(0)
        else
          old_voucher_remaining = @voucher.remaining

          @voucher.reload
          expect(@voucher.redeemed).to eq(total)
          expect(@voucher.is_used).to eq(false)
          expect(@voucher.remaining).to eq(old_voucher_remaining - total)
        end
        
        expect(@voucher.order_ids.index(order.id)).to eq(0)

        expect(order.voucher_ids.index(@voucher.id)).to eq(0)

        expect(order.success).to eq(true)

        expect(json["result"]).to eq("success")
      end

      it "return success when total < voucher" do
        @product.update_attributes({price: 50, quantity_set: 1})
        @voucher.update_attributes({purchase_price: 110, redeemed: 0, is_used: false})
        @voucher.reload

        order_params = @order.attributes.except('id', '_id', 'total')
        order_params[:total] = 0.0
        order_params[:promotions] = [{promotion_code: @voucher.code, voucher_email: @voucher.email_address}]
        order_params[:products] = []
        order_params[:products] << {id: @product.id.to_s, quantity: 1, image_id: @photo.id.to_s, frame: true}

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(Order.all.length).to eq(1)

        @product.reload

        total = @product.price + @product.shipping

        order = Order.first
        if @voucher.remaining <= total
          expect(order.total).to eq(order_params[:total])

          expect(@voucher.reload.is_used).to eq(true)
          expect(@voucher.remaining).to eq(0)
        else
          expect(order.total).to eq(order_params[:total])

          @voucher.reload

          expect(@voucher.redeemed).to eq(total)
          expect(@voucher.remaining).to_not eq(0)
        end
        
      end

      it "Create gift vouchers" do
        Voucher.destroy_all
        gift_value = 100

        order_params = @order.attributes.except('id', '_id')
        order_params[:products] = []
        order_params[:products] << {id: @product.id.to_s, quantity: 1, frame: true,
          recipient_name: "Long Vuong", recipient_email: "lienptb@elarion.com", message: "The gift certificates", gift_value: gift_value}

        post 'api/v1/order.json', {token: @customer.token}.merge!(order_params)

        expect(Order.all.length).to eq(1)

        order = Order.first
        
        expect(Voucher.count).to eq(1)

        voucher = Voucher.first

        expect(voucher.email_address).to eq("lienptb@elarion.com")
        expect(voucher.message).to eq("The gift certificates")
        expect(voucher.purchase_price).to eq(gift_value)

        order_item = order.order_items.first

        expect(order_item.gift_value).to eq(gift_value)
        expect(order_item.price).to eq(gift_value)
      end
    end
  end

end
