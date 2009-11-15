require 'rubygems'
require 'osx/cocoa'

class ItemModel < OSX::NSObject
  include OSX
  
  ACCESSORS = [:asin, :title, :price, :smallimage]

  kvc_accessor(*ACCESSORS)

  def copy_item(item)
    self.asin = item.asin
    self.title = item.title
    self.price = item.price
    if self.smallimage.nil?
      item.fetch_attr
      self.smallimage = item.smallimage
    end
  end

  def get_save_image
    Hash[*ACCESSORS.collect{|key| [key, self.send(key)]}.flatten]
  end

  def restore_from_save_image(save_image)
    ACCESSORS.each do |name|
      self.send(name.to_s + "=", save_image[name])
    end
  end

  # Defined primarily for UnitTest 
  def ==(other)
    ACCESSORS.each do |name|
      if self.send(name) != other.send(name)
        return false
      end
    end
    true
  end
end

