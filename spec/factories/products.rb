# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  
  factory :product do
    type "Type 1"
    size "ZZ"
    description "Product description"
    main_image {fixture_file_upload(Rails.root.join('spec', 'factories', 'test-photo.jpg'), 'image/png') }
    price 33
    shipping 11
    requires_photo true
    width 20
    height 40
    visible true
    order 0
    quantity_set 0
  end
end
