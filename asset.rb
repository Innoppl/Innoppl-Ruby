################################################################################
##File Name -  asset.rb  - Model File
##Created by - Vimal Raj K 
##Created on - 02/04/2011
##Last Edited by - Chandramouli 
##Last Edited for - To Include new file extensions
##Last Edited - 08/09/2011
##Purpose - The file is used for Image upload using Paperclip Gem
##This file defines file type used by our application and sanitize the file name while uploading
##################################################################################

module Paperclip
  # Defines the geometry of an image.
  class Geometry
    # Uses ImageMagick to determing the dimensions of a file, passed in as either a
    # File or path.
    def self.from_file file
      file = file.path if file.respond_to? "path"
      geometry = begin
                   Paperclip.run("identify", "-format %wx%h :file", :file => "#{file}[0]")
                 rescue PaperclipCommandLineError
                   ""
                 end
      parse(geometry) || ""
              # NotIdentifiedByImageMagickError.new("Invalid image type.Supported types are jpeg/jpg/png")
    end
  end
end

class Asset < ActiveRecord::Base
  belongs_to :attachable, :polymorphic => true
  MIME_TYPES = { "eps"  => [ 'image/eps', 'image/x-eps', 'application/postscript', 'application/eps', 'application/x-eps' ],
                 "ai"   => [ 'application/illustrator' ],
                 "jpg"  => [ 'image/jpg', 'image/jpeg', 'image/pjpeg' ],
                 "jpeg" => [ 'image/jpeg', 'image/pjpeg' ],
                 "tif"  => ['image/tiff', 'image/x-tif', 'image/tiff', 'image/x-tiff', 'application/tif', 'application/x-tif', 'application/tiff', 'application/x-tiff'], 
                 "tiff" => [ 'image/tiff' ],
                 "png"  => [ 'image/png', 'image/x-png', 'application/png', 'application/x-png' ],
                 "pdf"  => [ 'application/pdf', 'application/x-pdf', 'application/acrobat', 'applications/vnd.pdf', 'text/pdf', 'text/x-pdf' ],
                 "gif"  => [ 'image/gif' ],
                 "bmp"  => [ 'image/bmp' ],
                 "psd"  => [ 'image/photoshop', 'image/x-photoshop', 'image/vnd.adobe.photoshop', 'image/psd', 'application/photoshop', 'application/psd', 'zz-application/zz-winassoc-psd'],
                 "dae"  => [ 'application/octet-stream', 'application/xml', 'model/x3d+binary', 'application/collada+xml', 'model/collada+xml' ]
  }
  
  before_save :sanitize_file_name
  
  def validate
    find_dimensions
  end
  
  def find_dimensions
    return unless self.errors.blank?
    temporary = attachment.queued_for_write[:original] 
    filename = temporary.path unless temporary.nil?
    filename = attachment.path if filename.blank?
    geometry = Paperclip::Geometry.from_file(filename)
    if !geometry.blank? && (geometry.width < 200 || geometry.height < 200)
      errors.add(:attachment, "The minimum image size is 200 x 200 px")
    end
  end
  
  def self.supported_content_types
    [ MIME_TYPES["jpg"], MIME_TYPES["jpeg"], MIME_TYPES["png"], MIME_TYPES["gif"] ].flatten
  end
  
  def get_polymorphic_record
    model = self.attachable_type.camelize == "VenuePhoto" ? "Venue" : self.attachable_type.camelize 
    model.constantize.where("id = ?",self.attachable_id).first
  end
  
  private
  def sanitize_file_name
    self.attachment.instance_write(:file_name,  attachment_file_name.gsub(/[^A-Za-z0-9\.\-]/, '_')) unless attachment_file_name.blank?
  end   
  
end
