class String
  # Generates a string of n length made up of a-z0-9 chars.
	def self.generate_key(type = :all, length = 255)
		if type == :all
			chars = ('a'..'z').to_a + (0..9).to_a
		elsif type == :number
			chars = (0..9).to_a
		else
			chars = ('a'..'z').to_a
		end
		
		chars_length = chars.length
		key = []
		1.upto(length) {|i| key << chars.fetch(rand(chars_length))}
		key.join
	end

	##
	# Check String end with str or not
	##
	def end_with(str)
		begin
			i = self.length - str.length
			self[i..self.length] == str
		rescue Exception => e
			false
		end
	end
end