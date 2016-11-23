# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  
  factory :order do
    paypal_transaction_token "abcxyz"
    total 100
    shipping_cost 10
    name "ABC"
    email "abc@gmail.com"
    voucher_email "abc@gmail.com"
    # voucher_id
    # coupon_id
    coupon_discount 10
    phone "999999999"
    address "ABC DEEE"
    suburb "ee"
    state "ABC"
    postcode "555"
  end
end
