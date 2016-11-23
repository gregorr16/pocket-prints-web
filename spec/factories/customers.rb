# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  
  factory :customer do
    token SecureRandom.urlsafe_base64(nil, false)
  end
end
