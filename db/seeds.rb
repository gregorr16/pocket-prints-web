# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

#Create default product 1 -> 5
products = Array.new(5)
products.each_with_index{ |product, i|
  product =  Product.new({type: "type_#{i+1}", size: "size_#{i+1}",
    description: "description_#{i+1}", main_image: "image_#{i+1}",
    price: i+1, shipping: i+1,
    requires_photo: (i+1)/2 == 1, width: i+1, height: i+1})
  product.save!
  products[i] = product
}

#Create default customer
random_token = SecureRandom.urlsafe_base64(nil, false)
customer = Customer.create({token: random_token})

#Create default coupon of product 1 -> 3
coupons =  Array.new(3)
coupons.each_with_index{ |coupon, i|
  coupon = products[i].build_coupon({
      code: "coupon_#{i+1}",
      expiry: 2.days.ago + (i+1).days,
      free_shipping: (i+1)/2 == 1,
      discount_percentage: 30,
      discount_amount: (i+1)*10,
      is_used: (i+1)/2 == 1
    })
  coupon.save!
  coupons[i] = coupon
}

#Create default voucher of product 1
voucher = products[0].build_voucher({
    code: "voucher_1",
    expiry: Date.today,
    purchase_price: 50,
    redeemed: 1,
    message: "first voucher",
    email_address: "example@example.com",
    is_used: false
  })
voucher.save!