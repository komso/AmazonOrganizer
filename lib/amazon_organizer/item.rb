require 'rubygems'
require 'net/http'

class AmazonOrganizer::Item
  def initialize(asin, attr)
    @asin = asin
    @attr = attr
    @attr_loaded = false
  end
  attr_reader :asin

  # FIXME : centralize http access (to make it easier to support proxy)
  def fetch_attr
    return if @attr_loaded
    response = nil
    Net::HTTP.start("www.amazon.co.jp") do |http|
      response = http.get("/gp/aw/d.html?a=#{@asin}")
    end
    page = Nokogiri::HTML.parse(response.body, nil, "SJIS")
    @attr[:smallimage] = page.xpath("//img[contains(@src, '.jpg')]/@src").to_s
    
    @attr_loaded = true
  end

  def attr
    @attr
  end

  # define other accessors
  [:title, :smallimage, :price].each do |name|
    define_method(name) { @attr[name] }
  end
end
