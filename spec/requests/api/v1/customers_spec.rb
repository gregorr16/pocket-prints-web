require 'spec_helper'

describe "Customers API" do
 
  describe "POST 'token.json'" do
    it "works" do
      Customer.destroy_all
      post 'api/v1/token', :format => :json
      
      #response[:token].should eql(Customer.last.token)
      expect(assigns(:customer).token).to eq(Customer.first.token)

      expect(response).to be_success

      expect(json["token"]).to eq(Customer.first.token)
    end
  end

end
