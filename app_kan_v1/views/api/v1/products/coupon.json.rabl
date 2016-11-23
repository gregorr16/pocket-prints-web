object @coupon
attributes :code, :discount_percentage, :discount_amount, :expiry, :free_shipping, :discount_on_product
node(:total) { |coupon| coupon.product.try(:total) }