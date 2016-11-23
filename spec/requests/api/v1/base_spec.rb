require 'spec_helper'

describe "Base API" do
 
  describe "Require token" do
    context "works" do
      it "for order.json" do

        post 'api/v1/order.json'

        expect(json["error"]).to eql(I18n.t('customer.null_or_invalid_token'))
      end

      it "for preflight.json" do

        post 'api/v1/preflight.json'

        expect(json["error"]).to eql(I18n.t('customer.null_or_invalid_token'))
      end

      it "for photo.json" do

        post 'api/v1/photo.json'

        expect(json["error"]).to eql(I18n.t('customer.null_or_invalid_token'))
      end


      it "not need for products.json" do

        get 'api/v1/products.json'

        expect(json.length).to eq(Product.all.length)
      end
    end
  end

end
