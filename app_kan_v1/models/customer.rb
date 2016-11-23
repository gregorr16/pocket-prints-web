class Customer
  include Mongoid::Document
  include Mongoid::Timestamps

  field :token

  field :name, type: String
  field :email, type: String
  field :phone, type: String

  field :device_name, type: String
  field :os_version, type: String

  field :infos, type: Array, default: []

  field :params, type: String

  has_many :orders
  has_many :photos

  has_many :stripe_customers

  validates_presence_of :token
end

