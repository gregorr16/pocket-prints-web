require 'spec_helper'

describe "Photo API" do
 
  describe "POST photo" do
    context "works" do
      before(:each) do
        Photo.destroy_all
        @customer = create :customer
        
      end

      it "and return the photo" do

        post 'api/v1/photo.json', {token: @customer.token, image: fixture_file_upload(Rails.root.join('spec', 'factories', 'test-photo.jpg'), 'image/png') }

        expect(Photo.all.length).to eql(1)
        expect(json["uid"]).to eql(Photo.first.id.to_s)

        photo = Photo.first
        expect(photo.success).to eq(true)
        expect(photo.error).to eq(nil)
      end

      it "return error if missing image" do

        post 'api/v1/photo.json', {token: @customer.token}

        photo = Photo.first

        expect(Photo.all.length).to eql(1)
        expect(json["uid"]).to eq(photo.id.to_s)

        expect(photo.success).to eq(false)
        expect(photo.error).to eq(I18n.t("photo.missing_image"))
      end
    end

    context "upload from URL" do
      before(:each) do
        Photo.destroy_all
        @customer = create :customer
        @sample_url = "https://encrypted-tbn1.gstatic.com/images?q=tbn:ANd9GcSr5FrtTVjnyObN0vtR2T5QVFa62uznDpSf-prygpLz_w5nFGmU"
      end

      it "return the created photo id when url is valid" do

        post 'api/v1/photo.json', {token: @customer.token, image: @sample_url }

        photo = Photo.first
        expect(Photo.all.length).to eql(1)
        expect(json["uid"]).to eql(photo.id.to_s)
        expect(photo.url).to eq(@sample_url)

        expect(photo.success).to eq(true)
        expect(photo.error).to eq(nil)
      end

      it "return error when url is in-valid" do

        post 'api/v1/photo.json', {token: @customer.token, image: "aaaaaaa"}

        expect(Photo.all.length).to eql(1)
        expect(json["error"]).to eq(nil)

        photo = Photo.first
        expect(json["uid"]).to eql(photo.id.to_s)

        expect(photo.success).to eq(false)
        expect(photo.error.include?(I18n.t("photo.invalid_url"))).to eq(true)
      end
    end
  end

end
