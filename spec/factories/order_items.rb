# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  
  factory :order_item do
    quantity 1
    type "Type 1"
    size "ZZ"
    description "Product description"
    price 33
    shipping 11
    width 20
    height 40
  end
end
