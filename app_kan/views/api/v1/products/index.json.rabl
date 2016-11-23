collection @products, :root => false, :object_root => false
node(:uid) {|product| product.id.to_s}
attributes :code, :type, :size, :description, :price, :shipping, :requires_photo, :order, :quantity_set
node(:main_image) {|product| product.iphone4_url}
node(:width) {|product| product.width || 0}
node(:height) {|product| product.height || 0}

child :product_photos, :root => "images", :object_root => false do
	attributes :order
	node(:image) {|product_photo| product_photo.iphone4_url}
end
