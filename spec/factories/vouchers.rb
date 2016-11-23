# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  
  factory :voucher do
    sequence(:code){|n|"voucher code #{n}"}
    expiry (Date.today + 3.days)
    purchase_price 4
    redeemed 1
    message "This is a message"
    email_address "abc@gmail.com"
    is_used false
  end
end
