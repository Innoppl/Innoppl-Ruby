################################################################################
##File Name -  profile_image.rb  - Model File 
##Created by - Vimal 
##Created on - 01/04/2011
##Last Edited by - Chandramouli
##Last Edited for - Changed the attachment file Size
##Last Edited - 10/09/2011
##Purpose - The file is used for Profile Image upload using Paperclip Gem
## This file defines the Configuration for the image that the user upload via browser while registartion  
##################################################################################

class ProfileImage < Asset
  has_attached_file :attachment, 
                    :styles => { :very_mini => ['32x32>', :png], :mini => ['48x48>', :png], :small => ['110x110>', :png], :medium => ['120x104>', :png], :large => ['240x240>', :png], :extra_large => ['600x600>', :png], :venue_list => ['69x69>', :png], :profile_size => ['190x190>', :png] }, 
                    :url => "/assets/users/:id/:style/:basename.:extension",
                    :path => ":rails_root/public/assets/users/:id/:style/:basename.:extension",
                    :default_url => "/assets/users/missing_:style.png",
                    :convert_options => { :very_mini => Proc.new{self.convert_options(10)}, :mini => Proc.new{self.convert_options(10)}, :small => Proc.new{self.convert_options}, :medium => Proc.new{self.convert_options}, :large => Proc.new{self.convert_options}, :extra_large => Proc.new{self.convert_options}, :venue_list => Proc.new{self.convert_options}, :profile_size => Proc.new{self.convert_options}}
 
  def self.convert_options(px = 20)
    trans = ""
    trans << "-colorspace RGB"
    trans << " \\( +clone  -threshold -1 "
    trans << "-draw 'fill black polygon 0,0 0,#{px} #{px},0 fill white circle #{px},#{px} #{px},0' "
    trans << "\\( +clone -flip \\) -compose Multiply -composite "
    trans << "\\( +clone -flop \\) -compose Multiply -composite "
    trans << "\\) +matte -compose CopyOpacity -composite "
  end                    
  validates_attachment_content_type :attachment, :content_type => supported_content_types, :unless => "attachment.blank?"
  validates_attachment_size :attachment, :less_than => 200.kilobytes, :message => "Image size should be less than or equal to 200KB."
end
