require 'spec_helper'

describe "Products API" do
 
  describe "get index" do
    it "works" do
      product = create(:product)
      
      get 'api/v1/products', :format => :json
      
      expect(json[0]["type"]).to eql(product.type)
      expect(json[0]["size"]).to eql(product.size)
      expect(json[0]["description"]).to eql(product.description)
      expect(json[0]["price"]).to eql(product.price)
    end

    it "works & return blank array" do
      Product.destroy_all
      
      get 'api/v1/products', :format => :json
      expect(json.length).to eql(0)
      expect(assigns(:products).length).to eql(0)
    end
  end

  describe "post preflight" do
    context "works" do
      before(:each) do
        Coupon.destroy_all
        Voucher.destroy_all
        Product.destroy_all
        @customer = create :customer
        @product = create(:product)
        @coupon = create :coupon, product_id: @product.id
        @voucher = create :voucher
      end

      it "and return the coupon" do

        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: 1}], promotions: [{promotion_code: @coupon.code}]}
        
        expect(json["coupon"]["code"]).to eql(@coupon.code)
        expect(json["coupon"]["discount_percentage"]).to eql(@coupon.discount_percentage)
        expect(json["coupon"]["free_shipping"]).to eql(@coupon.free_shipping)
        expect(json["coupon"]["total"]).to eql(@product.total)
      end

      it "and return the voucher" do

        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: 1}], promotions: [{promotion_code: @voucher.code, voucher_email: @voucher.email_address}]}

        expect(json["vouchers"].length).to eql(1)
        expect(json["vouchers"][0]["code"]).to eql(@voucher.code)
        expect(json["vouchers"][0]["purchase_price"]).to eql(@voucher.purchase_price)
        expect(json["vouchers"][0]["redeemed"]).to eql(@voucher.redeemed)
        expect(json["vouchers"][0]["message"]).to eql(@voucher.message)
      end

      it "and return the total and discount amount when voucher has remain amount = 10 <= total" do
        quantity = 1
        @product.update_attribute(:price, 20)
        total = @product.price * quantity + @product.shipping
        discount = 10

        #voucher has remain amount = 10 <= total
        @voucher.update_attributes({purchase_price: 50, redeemed: 40})
        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity}], promotions: [{promotion_code: @voucher.code, voucher_email: @voucher.email_address}]}

        expect(json["shipping_cost"]).to eq(@product.shipping)
        expect(json["discount"]).to eq(discount)

        total = total > discount ? (total - discount) : 0

        expect(json["total"]).to eq(total)

      end

      it "and return the total and discount amount when voucher has remain amount = 500 > total" do
        quantity = 1
        @product.update_attribute(:price, 20)
        total = @product.price * quantity + @product.shipping
        discount = total

        #voucher has remain amount = 500 > total
        @voucher.update_attributes({purchase_price: 500, redeemed: 0})
        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity}], promotions: [{promotion_code: @voucher.code, voucher_email: @voucher.email_address}]}

        expect(json["shipping_cost"]).to eq(@product.shipping)
        expect(json["discount"]).to eq(discount)

        total = total > discount ? (total - discount) : 0

        expect(json["total"]).to eq(total)
      end

      it "and return the total and discount amount when coupon has free shipping & discount amount = 15" do
        quantity = 1
        @product.update_attribute(:price, 20)
        total = @product.price * quantity

        #coupon has free shipping & discount amount = 15
        @coupon.update_attributes({free_shipping: true, discount_amount: 15, discount_percentage: nil, discount_on_product: nil, product_id: nil})
        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity}], promotions: [{promotion_code: @coupon.code}]}

        shipping = @coupon.free_shipping ? 0 : @product.shipping
        expect(json["shipping_cost"]).to eq(shipping)

        discount = total > 15 ? 15 : total
        expect(json["discount"]).to eq(discount)

        total = total > discount ? (total - discount) : 0

        expect(json["total"]).to eq(total)
      end

      it "and return the total and discount amount coupon has discount on_product = 15" do
        quantity = 1
        @product.update_attribute(:price, 20)
        total = @product.price * quantity + @product.shipping

        #coupon has discount on_product = 15
        @coupon.update_attributes({free_shipping: false, discount_amount: nil, discount_percentage: nil, discount_on_product: 15, product_id: @product.id})
        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity}], promotions: [{promotion_code: @coupon.code}]}
        
        expect(json["shipping_cost"]).to eq(@product.shipping)

        discount = (@product.price * quantity) > (15 * quantity) ? (15 * quantity) : (@product.price * quantity)
        expect(json["discount"]).to eq(discount)

        total = total > discount ? (total - discount) : 0

        expect(json["total"]).to eq(total)
      end

      it "and return the total and discount amount when coupon has discount percentage = 10" do
        quantity = 1
        @product.update_attribute(:price, 20)
        total = @product.price * quantity + @product.shipping

        #coupon has discount percentage = 10
        @coupon.update_attributes({free_shipping: false, discount_amount: nil, discount_percentage: 10, discount_on_product: nil, product_id: nil})
        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity}], promotions: [{promotion_code: @coupon.code}]}

        expect(json["shipping_cost"]).to eq(@product.shipping)

        discount = total * @coupon.discount_percentage/100
        expect(json["discount"]).to eq(discount)

        total = total > discount ? (total - discount) : 0

        expect(json["total"]).to eq(total)
      end

      it "(1 product and order two photos) and return the total and discount amount when coupon has discount percentage = 10" do
        quantity1 = 1
        quantity2 = 2
        quantity = quantity1 + quantity2

        @product.update_attribute(:price, 20)
        total = @product.price * quantity + @product.shipping

        #coupon has discount percentage = 10
        @coupon.update_attributes({free_shipping: false, discount_amount: nil, discount_percentage: 10, discount_on_product: nil, product_id: nil})
        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity1}, {id: @product.id.to_s, quantity: quantity2}], promotions: [{promotion_code: @coupon.code}]}

        expect(json["shipping_cost"]).to eq(@product.shipping)

        discount = total * @coupon.discount_percentage/100
        expect(json["discount"]).to eq(discount)

        total = total > discount ? (total - discount) : 0

        expect(json["total"]).to eq(total)
      end

      it "(2 products) and return the total and discount amount when coupon has discount on product = 10" do
        quantity1 = 1
        quantity2 = 2

        @product.update_attributes({price: 20, shipping: 5})
        product2 = create :product, price: 30, shipping: 10

        max_shipping = @product.shipping > product2.shipping ? @product.shipping : product2.shipping

        product1_price = @product.price * quantity1

        total = product1_price + product2.price * quantity2

        if total < 100
          total += max_shipping
        else
          max_shipping = 0.0
        end

        #coupon has discount on product = 10
        @coupon.update_attributes({free_shipping: false, discount_amount: nil, discount_percentage: nil, discount_on_product: 0, product_id: @product.id})
        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity1}, {id: product2.id.to_s, quantity: quantity2}], promotions: [{promotion_code: @coupon.code}]}

        expect(json["shipping_cost"]).to eq(max_shipping)

        discount = (product1_price > @coupon.discount_on_product) ? @coupon.discount_on_product : product1_price
        expect(json["discount"]).to eq(discount)

        total = total > discount ? (total - discount) : 0

        expect(json["total"]).to eq(total)
      end


      it "(2 products) and return the total and discount amount when coupon has discount percentage = 10" do
        quantity1 = 1
        quantity2 = 2

        @product.update_attributes({price: 20, shipping: 5})
        product2 = create :product, price: 30, shipping: 10

        max_shipping = @product.shipping > product2.shipping ? @product.shipping : product2.shipping

        product1_price = @product.price * quantity1

        total = product1_price + product2.price * quantity2

        if total < 100
          total += max_shipping
        else
          max_shipping = 0.0
        end

        #coupon has discount percentage = 10
        @coupon.update_attributes({free_shipping: false, discount_amount: nil, discount_percentage: 10, discount_on_product: nil, product_id: nil})
        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity1}, {id: product2.id.to_s, quantity: quantity2}], promotions: [{promotion_code: @coupon.code}]}

        expect(json["shipping_cost"]).to eq(max_shipping)

        discount = total * @coupon.discount_percentage/100
        expect(json["discount"]).to eq(discount)

        total = total > discount ? (total - discount) : 0

        expect(json["total"]).to eq(total)
      end


      it "2 products: with one products has two photos" do
        quantity1 = 1
        quantity2 = 2
        quantity3 = 3

        @product.update_attributes({price: 20, shipping: 5})
        product2 = create :product, price: 30, shipping: 10

        max_shipping = @product.shipping > product2.shipping ? @product.shipping : product2.shipping

        product1_price = @product.price * (quantity1 + quantity3)

        total = product1_price + product2.price * quantity2

        if total < 100
          total += max_shipping
        else
          max_shipping = 0.0
        end

        #coupon has discount percentage = 10
        @coupon.update_attributes({free_shipping: false, discount_amount: nil, discount_percentage: 10, discount_on_product: nil, product_id: nil})
        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity1}, {id: @product.id.to_s, quantity: quantity3}, {id: product2.id.to_s, quantity: quantity2}], promotions: [{promotion_code: @coupon.code}]}

        expect(json["shipping_cost"]).to eq(max_shipping)

        discount = total * @coupon.discount_percentage/100
        expect(json["discount"]).to eq(discount)

        total = total > discount ? (total - discount) : 0

        expect(json["total"]).to eq(total)
      end

      it "with quantity set = 10, quantity = 5" do
        quantity = 5
        @product.update_attributes({price: 20, quantity_set: 10})

        new_quantity = (quantity / @product.quantity_set.to_f).ceil

        expect(new_quantity).to eq(1)
        total = @product.price * new_quantity + @product.shipping

        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity}]}

        expect(json["shipping_cost"]).to eq(@product.shipping)

        expect(json["total"]).to eq(total)
      end

      it "with quantity set = 10, quantity = 5 (product with many photos)" do
        quantity1 = 1
        quantity2 = 2
        quantity3 = 2
        quantity = quantity1 + quantity2 + quantity3
        @product.update_attributes({price: 20, quantity_set: 10})

        new_quantity = (quantity / @product.quantity_set.to_f).ceil

        expect(new_quantity).to eq(1)
        total = @product.price * new_quantity + @product.shipping

        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity1}, {id: @product.id.to_s, quantity: quantity2}, {id: @product.id.to_s, quantity: quantity3}]}

        expect(json["shipping_cost"]).to eq(@product.shipping)

        expect(json["total"]).to eq(total)
      end

      it "with quantity set = 10, quantity = 10" do
        quantity = 10
        @product.update_attributes({price: 20, quantity_set: 10})

        new_quantity = (quantity / @product.quantity_set.to_f).ceil

        expect(new_quantity).to eq(1)
        total = @product.price * new_quantity + @product.shipping

        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity}]}

        expect(json["shipping_cost"]).to eq(@product.shipping)

        expect(json["total"]).to eq(total)
      end

      it "with quantity set = 10, quantity = 11" do
        quantity = 11
        @product.update_attributes({price: 20, quantity_set: 10})

        new_quantity = (quantity / @product.quantity_set.to_f).ceil

        expect(new_quantity).to eq(2)
        total = @product.price * new_quantity + @product.shipping

        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity}]}

        expect(json["shipping_cost"]).to eq(@product.shipping)

        expect(json["total"]).to eq(total)
      end

      it "for Gift certificate with gift_value = 30" do
        quantity = 11
        @product.update_attributes({price: 20, quantity_set: 10})

        gift_value = 30

        total = gift_value * 1 + @product.shipping

        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity, recipient_name: "ABC", recipient_email: "abc@gmail.com", message: "ABC", gift_value: gift_value }]}

        expect(json["shipping_cost"]).to eq(@product.shipping)

        expect(json["total"]).to eq(total)
      end

      it "for Gift certificate with gift_value = 30 (+ a photo with the same product)" do
        quantity = 11
        quantity1 = 2
        @product.update_attributes({price: 20, quantity_set: 10})

        gift_value = 30

        total = (gift_value * 1 + @product.price * (quantity1/@product.quantity_set.to_f).ceil) 
        max_shipping = @product.shipping

        total += max_shipping if total < 100

        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity, recipient_name: "ABC", recipient_email: "abc@gmail.com", message: "ABC", gift_value: gift_value }, {id: @product.id.to_s, quantity: quantity1}]}

        expect(json["shipping_cost"]).to eq(max_shipping)
        
        expect(json["total"]).to eq(total)
      end

      it "for two Gift certificates with gift_value = 30 and 20" do
        quantity = 11
        @product.update_attributes({price: 20, quantity_set: 10})

        gift_value1 = 30
        gift_value2 = 20

        total = (gift_value1 + gift_value2) * 1 
        max_shipping = @product.shipping

        total += max_shipping if total < 100

        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity, recipient_name: "ABC", recipient_email: "abc@gmail.com", message: "ABC", gift_value: gift_value1 }, {id: @product.id.to_s, quantity: quantity, recipient_name: "ABC", recipient_email: "abc@gmail.com", message: "ABC", gift_value: gift_value2 }]}

        expect(json["shipping_cost"]).to eq(max_shipping)

        expect(json["total"]).to eq(total)
      end

      it "for Gift certificate with gift_value = 50, always set quantity = 1 and ignore quantity_set of product " do
        quantity = 11
        @product.update_attributes({price: 20, quantity_set: 10})

        gift_value = 50

        total = gift_value * 1 + @product.shipping

        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: quantity, recipient_name: "ABC", recipient_email: "abc@gmail.com", message: "ABC", gift_value: gift_value }]}

        expect(json["shipping_cost"]).to eq(@product.shipping)

        expect(json["total"]).to eq(total)
      end
    end


    context "errors" do
      before(:each) do
        Coupon.destroy_all
        Voucher.destroy_all
        Customer.destroy_all
        Product.destroy_all
        @customer = create :customer
        @product = create :product
        @coupon = create :coupon, product_id: @product.id
        @voucher = create :voucher
      end

      def get_used_expired_error(expired_vouchers, expired_coupons, used_promotions)
        expired_promotions = expired_vouchers + expired_coupons
        used_expired_promotions = expired_promotions + used_promotions

        error = ""
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

          error = error_msgs.join("; ")
        end

        error
      end

      it "token null" do

        post 'api/v1/preflight.json'

        expect(json["error"]).to eql(I18n.t('customer.null_or_invalid_token'))
      end

      it "invalid token" do

        post 'api/v1/preflight.json', {token: ''}

        expect(json["error"]).to eql(I18n.t('customer.null_or_invalid_token'))
      end

      it "product can_not_found" do

        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: 1, quantity: 10}]}

        expect(json["error"][0]).to eql(I18n.t('product.id_can_not_found', {:id => 1}))
      end

      # it "product not_visible" do
      #   @product.update_attribute(:visible, false)
      #   get 'api/v1/preflight.json', {token: @customer.token, product_id: @product.id.to_s}

      #   expect(json["error"]).to eql(I18n.t('product.not_visible'))
      # end

      it "discount can_not_found" do
        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: 1}], promotions: [{promotion_code: '2121'}]}

        expect(json["error"]).to eql(I18n.t('discount.can_not_found'))
      end

      #error: discount.expired
      it "coupon discount expired" do
        @coupon.update_attribute(:expiry, Date.today - 2.days)
        expired_coupons = [{promotion_code: @coupon.code, type: "Coupon", is_expired: true}]
        
        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: 1}], promotions: [{promotion_code: @coupon.code}]}

        error = get_used_expired_error([], expired_coupons, [])

        expect(json["error"]).to eql(error)
        expect(json["error_code"]).to eql(3)
        expect(json["used_expired_promotions"].length).to eql(1)

        expect(json["used_expired_promotions"].first["promotion_code"]).to eql(@coupon.code)
      end

      it "voucher discount expired" do
        @voucher.update_attribute(:expiry, Date.today.yesterday)
        expired_vouchers = [{promotion_code: @voucher.code, type: "Voucher", is_expired: true}]

        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: 1}], promotions: [{promotion_code: @voucher.code, voucher_email: @voucher.email_address}]}

        error = get_used_expired_error(expired_vouchers, [], [])

        expect(json["error"]).to eql(error)
        expect(json["error_code"]).to eql(3)
        expect(json["used_expired_promotions"].length).to eql(1)

        expect(json["used_expired_promotions"].first["promotion_code"]).to eql(@voucher.code)
      end

      it "voucher have_been_used" do
        @voucher.update_attributes(is_used: true, purchase_price: 10, redeemed: 10)
        used_promotions = [{promotion_code: @voucher.code, type: "Voucher", is_expired: false}]

        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: 1}], promotions: [{promotion_code: @voucher.code, voucher_email: @voucher.email_address}]}

        error = get_used_expired_error([], [], used_promotions)

        expect(json["error"]).to eql(error)
        expect(json["error_code"]).to eql(3)
        expect(json["used_expired_promotions"].length).to eql(1)

        expect(json["used_expired_promotions"].first["promotion_code"]).to eql(@voucher.code)
      end

      it "voucher have_been_used & products are blank" do
        @voucher.update_attributes(is_used: true, purchase_price: 10, redeemed: 10)
        used_promotions = [{promotion_code: @voucher.code, type: "Voucher", is_expired: false}]

        post 'api/v1/preflight.json', {token: @customer.token, products: [], promotions: [{promotion_code: @voucher.code, voucher_email: @voucher.email_address}]}

        error = get_used_expired_error([], [], used_promotions)

        expect(json["error"]).to eql(error)
        expect(json["error_code"]).to eql(3)
        expect(json["used_expired_promotions"].length).to eql(1)

        expect(json["used_expired_promotions"].first["promotion_code"]).to eql(@voucher.code)
      end

      it "one voucher have_been_used & one coupon is expired" do
        @voucher.update_attributes(is_used: true, purchase_price: 10, redeemed: 10)
        used_promotions = [{promotion_code: @voucher.code, type: "Voucher", is_expired: false}]

        @coupon.update_attribute(:expiry, Date.today - 2.days)
        expired_coupons = [{promotion_code: @coupon.code, type: "Coupon", is_expired: true}]
        
        post 'api/v1/preflight.json', {token: @customer.token, products: [], promotions: [{promotion_code: @voucher.code, voucher_email: @voucher.email_address}, {promotion_code: @coupon.code, voucher_email: ""}]}

        error = get_used_expired_error([], expired_coupons, used_promotions)

        expect(json["error"]).to eql(error)
        expect(json["error_code"]).to eql(3)
        expect(json["used_expired_promotions"].length).to eql(2)

        error_promotions_codes = json["used_expired_promotions"].map { |e| e["promotion_code"] }

        expect(error_promotions_codes.index(@voucher.code)).to_not eql(nil)

        expect(error_promotions_codes.index(@coupon.code)).to_not eql(nil)
      end

      it "two vouchers have_been_used & one coupon is expired" do
        @voucher.update_attributes(is_used: true, purchase_price: 10, redeemed: 10)

        @voucher2 = create :voucher
        @voucher2.update_attributes(is_used: true, purchase_price: 10, redeemed: 10)
        
        used_promotions = [{promotion_code: @voucher.code, type: "Voucher", is_expired: false}, {promotion_code: @voucher2.code, type: "Voucher", is_expired: false}]

        @coupon.update_attribute(:expiry, Date.today - 2.days)
        expired_coupons = [{promotion_code: @coupon.code, type: "Coupon", is_expired: true}]
        
        post 'api/v1/preflight.json', {token: @customer.token, products: [], promotions: [{promotion_code: @voucher.code, voucher_email: @voucher.email_address}, {promotion_code: @voucher2.code, voucher_email: @voucher2.email_address}, {promotion_code: @coupon.code, voucher_email: ""}]}

        error = get_used_expired_error([], expired_coupons, used_promotions)

        expect(json["error"]).to eql(error)
        expect(json["error_code"]).to eql(3)
        expect(json["used_expired_promotions"].length).to eql(3)

        error_promotions_codes = json["used_expired_promotions"].map { |e| e["promotion_code"] }

        expect(error_promotions_codes.index(@voucher.code)).to_not eql(nil)
        expect(error_promotions_codes.index(@voucher2.code)).to_not eql(nil)
        expect(error_promotions_codes.index(@coupon.code)).to_not eql(nil)
      end

      it "voucher email is invalid" do
        @voucher.update_attributes(is_used: true, purchase_price: 10, redeemed: 10)
        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: 1}], promotions: [{promotion_code: @voucher.code, voucher_email: ""}]}

        expect(json["error"]).to eql(I18n.t('voucher.email_invalid'))
      end

      it "duplicated_vouchers" do
        post 'api/v1/preflight.json', {token: @customer.token, products: [{id: @product.id.to_s, quantity: 1}], promotions: [{promotion_code: @voucher.code, voucher_email: @voucher.email_address}, {promotion_code: @voucher.code, voucher_email: @voucher.email_address}]}

        expect(json["error"]).to eql(I18n.t('discount.duplicated_vouchers'))
      end

    end
  end

end
