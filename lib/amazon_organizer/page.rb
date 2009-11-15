require 'iconv'

class AmazonOrganizer::Page
  # Take Mechanize::Form and clean up duplicated fields
  # This is made as a class method in order to allow UnitTest code to test it without instance of Page.
  def self.cleanup_form(form)
    return if form.nil?
    #FIXME: Making modification on member Array.
    # The intention is to remove two duplicated fields at the end of the form, which prevent from the form "saveForLater.1" 
    # working correctly.
    form.fields.pop
    form.fields.pop
  end

  def initialize(page)
    @page = page
    @active_items = []
    @saved_items = []
    @active_list_urls = []
    @saved_list_urls = []
    @form = nil
    parse
  end

  attr_reader :active_items, :saved_items
  attr_reader :active_list_urls, :saved_list_urls

  def parse_item(key)
    item_rows = @page.parser.xpath("//input[starts-with(@name, '#{key}')]/../..")
    item_rows.collect do |row|
      link_to_item = row.xpath("descendant::a[starts-with(@href, 'http://www.amazon.co.jp/exec/obidos/ASIN')]")
      url = link_to_item.xpath("@href").to_s
      asin = %r{/ASIN/([^/]+)/}.match(url)[1]
      title = Iconv.conv("UTF-8", "SJIS", link_to_item.xpath("text()").to_s)

      price_string = row.xpath("descendant::b[@class='price']/text()").to_s
      price = /\d+/.match(price_string.sub(",", ""))[0].to_i

      AmazonOrganizer::Item.new(asin, {:title => title, :price => price})
    end
  end

  def parse_link_to_list(key)
    @page.parser.xpath("//a[contains(@href, '#{key}')]/@href").collect {|node| node.to_s}
  end

  def parse
    @active_items += parse_item("saveForLater.")
    @saved_items += parse_item("moveToCart.s")
    @active_list_urls += parse_link_to_list("active=true")
    @saved_list_urls += parse_link_to_list("saved=true")
  end

  def form
    if @form.nil?
      @form = @page.forms.find{ |f| f.form_node['id'] == "cartViewForm" }
      self.class.cleanup_form(@form)
    end
    @form
  end

  def update(new_states)
    return if form.nil?

    updated = false

    @active_items.each_with_index do |item, index|
      case new_states[item.asin]
      when nil
        form["saveForLater.#{index+1}"] = "Save For Later"
        updated = true
      when :delete
        form["delete.#{index+1}"] = "Delete"
        updated = true
      when :saved
        form["saveForLater.#{index+1}"] = "Save For Later"
        updated = true
      end
    end

    @saved_items.each_with_index do |item, index|
      case new_states[item.asin]
      when nil
        # do nothing for unrecognized item
      when :delete
        form["delete.s#{index+1}"] = "Delete"
        updated = true
      when :active
        form["moveToCart.s#{index+1}"] = "Move to Cart"
        updated = true
      end
    end
    if updated
      form.submit 
    end
  end

end
