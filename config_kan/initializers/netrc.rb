class Netrc
  def self.default_path
    if WINDOWS && !CYGWIN
      File.join(ENV['USERPROFILE'].gsub("\\","/"), "_netrc")
    else
      File.join("/home/ubuntu", ".netrc")
    end
  end
end
