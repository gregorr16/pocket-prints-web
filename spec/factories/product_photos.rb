# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  
  factory :product_photo do
    photo {fixture_file_upload(Rails.root.join('spec', 'factories', 'test-photo.jpg'), 'image/png') }
    order "order"
  end
end
