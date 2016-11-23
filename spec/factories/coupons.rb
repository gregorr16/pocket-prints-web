# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  
  factory :coupon do
    sequence(:code){|n|"coupon code #{n}"}
    expiry (Date.today + 3.days)
    free_shipping false
    discount_percentage 30
    discount_amount 30
    discount_on_product 20
  end
end
