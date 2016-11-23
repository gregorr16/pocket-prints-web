# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  
  factory :photo do    
    photo_info 'Photo Info'
    image {fixture_file_upload(Rails.root.join('spec', 'factories', 'test-photo.jpg'), 'image/png') }
    checksum ''
  end
end
