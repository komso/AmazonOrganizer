require 'rubygems'
require 'osx/cocoa'

class ItemView < OSX::NSCollectionViewItem
  include OSX

  def awakeFromNib
    set_price_font_size
  end

  def set_price_font_size
    price_label = view.viewWithTag(2)
    font = price_label.cell.font
    price_label.cell.font = NSFont.fontWithName_size_(font.fontName, NSFont.smallSystemFontSize * 0.9)
  end

  def setSelected(flag)
    [1, 2].each do |i|
      view.viewWithTag(i).setDrawsBackground(flag == 1)
    end
    super_setSelected(flag)
  end
end

__END__
    title.setBackgroundColor(flag ? NSColor.blueColor : NSColor.whiteColor)
#    title.setDrawsBackground(flag)


