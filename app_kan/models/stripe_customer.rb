class StripeCustomer
  include Mongoid::Document
  include Mongoid::Timestamps

  field :token, type: String
  field :stripe_id, type: String

  field :name, type: String
  field :email, type: String
  field :phone, type: String

  field :device_name, type: String
  field :os_version, type: String

  field :params, type: String

  field :error, type: String

  belongs_to :customer
end

