require 'test/unit'
require 'rubygems'
require 'mocha'
require 'amazon_organizer'
require 'uri'
require 'yaml'
require 'net/http'
require 'ostruct'

class DummyForm
  include Mocha::API
  def initialize(form_node, url)
    @form_node, @url = form_node, url
    @fields = {}
    # pop for AmazonOrganizer::Page.cleanup_form (tentative implementation uses it)
    def @fields.pop; end
  end
  attr_reader :form_node, :url, :fields

  def []=(key, value)
    @fields[key] = value
  end

  def submit
    TC_AmazonTest.submit_form(self)
  end
end

class DummyAgent
  include Mocha::API
  
  def initialize(testcase)
    @testcase_path = File.dirname(__FILE__) + "/" + testcase
    @page = nil
  end

  attr_reader :page
  attr_accessor :user_agent_alias, :log

  def saved_html(url)
    case url
    when AmazonOrganizer::Amazon::URL_SHOPPING_CART
      "gno_cart.html"
    when /number=(\d+)&active=true/
      "active-#$1.html"
    when /number=(\d+)&saved=true/
      "saved-#$1.html"
    else
      nil
    end
  end

  def make_dummy_forms(parser, url)
    parser.search("form").collect do |f|
      DummyForm.new(f, url)
    end
  end

  def get_html(url)
    html_file = saved_html(url)
    if(html_file)
      File.readlines(@testcase_path + "/" + html_file).join
    else
      "<html></html>"
    end
  end

  def get(url)
    parser = Nokogiri::HTML.parse(get_html(url), nil, "SJIS")
    @page = stub(:parser => parser, :forms => make_dummy_forms(parser, url), 
                 :form_with => stub_everything)
  end
end

class TC_AmazonTest < Test::Unit::TestCase
  
  @@submitted_forms = []

  def TC_AmazonTest.submit_form(form)
    @@submitted_forms << form
  end

  def setup
    @@submitted_forms.clear
    @agent = nil
    @list = []
    def @list.add(item, state); self << [item, state]; end
    OSX.stubs(:SecKeychainFindInternetPassword).returns([0, 5, "dummy", nil])
    @items = nil
  end

  def setup_amazon_stub(testcase)
    @agent = DummyAgent.new(testcase)
    WWW::Mechanize.expects(:new).yields(@agent).returns(@agent)
  end

  def setup_expected_items(testcase)
    @items = YAML.load(File.read("#{testcase}/items.yaml"))
  end

  def saved_list_url(num)
    "/gp/cart/view.html?ie=UTF8&ref=ord_cart%5Fshr&number=#{num}&saved=true"
  end

  def active_list_url(num)
    "/gp/cart/view.html?ie=UTF8&ref=ord_cart%5Fshr&number=#{num}&active=true"
  end

  def test_dummy
    agent = DummyAgent.new("testcase/01")
    assert_equal("gno_cart.html", agent.saved_html(AmazonOrganizer::Amazon::URL_SHOPPING_CART))
    assert_equal("active-1.html", agent.saved_html(active_list_url(1)))
    assert_equal("saved-1.html", agent.saved_html(saved_list_url(1)))
    assert_nil(agent.saved_html(AmazonOrganizer::Amazon::URL_SIGN_IN))
  end
  
  def setup_amazon(testcase)
    setup_amazon_stub(testcase)
    setup_expected_items(testcase)
    account_info = OpenStruct.new(:account_name => "foo", :password => "bar")
    AmazonOrganizer::Amazon.new(@list, account_info)
  end

  def test_sign_in
    amazon = setup_amazon("testcase/01")
    assert(! amazon.signed_in?)
    amazon.sign_in("foo", "bar")
    assert(amazon.signed_in?)
  end

  def test_auto_sign_in
    amazon = setup_amazon("testcase/01")    
    assert(! amazon.signed_in?)
    amazon.auto_sign_in
    assert(amazon.signed_in?)
    @agent.stubs(:get).never
    amazon.auto_sign_in
  end

  def test_auto_sign_in_by_get
    amazon = setup_amazon("testcase/01")    
    assert(! amazon.signed_in?)
    amazon.get(AmazonOrganizer::Amazon::URL_SHOPPING_CART)
    assert(amazon.signed_in?)
  end

  # Check specified logger is passed to Mechanize::Agent
  def test_log
    setup_amazon_stub("testcase/01")
    logger = Object.new
    amazon = AmazonOrganizer::Amazon.new(@list, nil, logger)
    assert_equal(logger, @agent.log)
  end

  def item_hash_list(list)
    list.collect do |item|
      hash = item.attr.dup
      hash[:asin] = item.asin
      hash
    end
  end

  def check_items(html_file_name, page)
    assert_equal(@items[html_file_name][:active_items], item_hash_list(page.active_items))
    assert_equal(@items[html_file_name][:saved_items], item_hash_list(page.saved_items))
  end

  def test_tobuynow
    amazon = setup_amazon("testcase/01")
    page = amazon.get(AmazonOrganizer::Amazon::URL_SHOPPING_CART)
    check_items("gno_cart.html", page)
  end

  def test_empty_tobuynow
    amazon = setup_amazon("testcase/02")
    page = amazon.get(AmazonOrganizer::Amazon::URL_SHOPPING_CART)
    check_items("gno_cart.html", page)
  end

  def test_active_urls
    amazon = setup_amazon("testcase/03")
    page = amazon.get(AmazonOrganizer::Amazon::URL_SHOPPING_CART)
    check_items("gno_cart.html", page)
    assert_equal([active_list_url(1), active_list_url(2)], page.active_list_urls)
  end

  def test_active_list
    amazon = setup_amazon("testcase/03")
    page = amazon.get(AmazonOrganizer::Amazon::URL_SHOPPING_CART)
    page2 = amazon.get(page.active_list_urls[0])
    check_items("active-1.html", page2)
  end

  def test_savedforlater
    amazon = setup_amazon("testcase/04")
    page = amazon.get(AmazonOrganizer::Amazon::URL_SHOPPING_CART)
    check_items("gno_cart.html", page)
    assert_equal([saved_list_url(1), saved_list_url(2)], page.saved_list_urls)
  end

  def test_saved_list
    amazon = setup_amazon("testcase/04")
    page = amazon.get(AmazonOrganizer::Amazon::URL_SHOPPING_CART)
    page2 = amazon.get(page.saved_list_urls[0])
    check_items("saved-1.html", page2)
  end

  def test_cleanup_form
    agent = DummyAgent.new("testcase/03")
    url = "http://www.amazon.co.jp/gp/cart/view.html?ie=UTF8&ref=ord_cart_shr&number=1&active=true"
    html = agent.get_html(url)
    response = {'content-type' => "text/html"}

    page = WWW::Mechanize::Page.new(URI.parse(url), response, html, nil, stub(:html_parser => Nokogiri::HTML))
    form = page.forms.find {|f| f.form_node['id'] == 'cartViewForm'}
    AmazonOrganizer::Page.cleanup_form(form)
    expected = %w(
                  itemID.1
                  quantity.1
                  itemID.2
                  quantity.2
                  itemID.3
                  quantity.3
                  itemID.4
                  quantity.4
                  itemID.5
                  quantity.5
                  itemID.6
                  quantity.6
                  itemID.7
                  quantity.7
                  itemID.8
                  quantity.8
                  itemID.9
                  quantity.9
                  itemID.10
                  quantity.10
                  activeItemCount
                  itemCount
                  isToBeGiftWrappedPrevious.cart
               )
    assert_equal(expected, form.fields.collect { |filed| filed.name })
  end

  def test_cleanup_form2
    assert_nothing_raised do
      AmazonOrganizer::Page.cleanup_form(nil)      
    end
  end
    

  def test_item
    expected = {
      :smallimage=>"http://ecx.images-amazon.com/images/I/513JW1MX18L._SL75_.jpg", 
      :title=>"Great Beer Guide: The World's 500 Best Beers",
      :price=>1559
    }

    response = stub(:body => 
                    '<html><head></head><body>
                        <img src="http://ecx.images-amazon.com/images/I/513JW1MX18L._SL75_.jpg">
                    </body></html>')
    http = stub(:get => response)
    Net::HTTP.stubs(:start).yields(http)

    item = AmazonOrganizer::Item.new("0751308137", {:title => expected[:title], :price => expected[:price]})
    item.fetch_attr
    assert_equal(expected, item.attr)
  end

  def test_item2
    assert_nothing_raised do 
      expected = {
        :smallimage=>"", 
        :title=>"Great Beer Guide: The World's 500 Best Beers",
        :price=>0
      }
      response = stub(:body => 
                      '<html><head></head><body>
                      </body></html>')
      http = stub(:get => response)
      Net::HTTP.stubs(:start).yields(http)
      
      item = AmazonOrganizer::Item.new("0751308137", {:title => expected[:title], :price => expected[:price]})
      item.fetch_attr
      assert_equal(expected, item.attr)
    end
  end

  def test_update_tobuynow
    amazon = setup_amazon("testcase/04")
    page = amazon.get(AmazonOrganizer::Amazon::URL_SHOPPING_CART)
    new_states = {}
    page.active_items.each{|i| new_states[i.asin] = :active}
    asins = page.active_items.collect{ |i| i.asin }
    new_states[asins[0]] = :saved
    new_states[asins[1]] = :delete
    new_states[asins[3]] = :saved
    new_states[asins[4]] = :delete
    page.update(new_states)

    expected_fields = {
      "delete.2"=>"Delete",
      "saveForLater.1"=>"Save For Later",
      "delete.5"=>"Delete",
      "saveForLater.4"=>"Save For Later"
    }
    assert_equal(expected_fields, @@submitted_forms.first.fields)
  end

  def test_update_tobuynow2
    amazon = setup_amazon("testcase/04")
    page = amazon.get(AmazonOrganizer::Amazon::URL_SHOPPING_CART)
    page2 = amazon.get(page.active_list_urls.first)
    new_states = {}
    page2.active_items.each{|i| new_states[i.asin] = :active}
    asins = page2.active_items.collect{ |i| i.asin }
    new_states[asins[0]] = :saved
    new_states[asins[1]] = :delete
    new_states[asins[3]] = :saved
    new_states[asins[4]] = :delete
    page2.update(new_states)

    expected_fields = {
      "delete.2"=>"Delete",
      "saveForLater.1"=>"Save For Later",
      "delete.5"=>"Delete",
      "saveForLater.4"=>"Save For Later"
    }
    assert_equal(expected_fields, @@submitted_forms.first.fields)
  end

  def test_update_savedforlater
    amazon = setup_amazon("testcase/04")
    page = amazon.get(AmazonOrganizer::Amazon::URL_SHOPPING_CART)
    new_states = {}
    page.active_items.each{|i| new_states[i.asin] = :active}
    asins = page.saved_items.collect{ |i| i.asin }
    new_states[asins[0]] = :active
    new_states[asins[1]] = :delete
    new_states[asins[3]] = :active
    new_states[asins[4]] = :delete
    page.update(new_states)

    expected_fields = {
      "delete.s2"=>"Delete",
      "moveToCart.s1"=>"Move to Cart",
      "delete.s5"=>"Delete",
      "moveToCart.s4"=>"Move to Cart"
    }
    assert_equal(expected_fields, @@submitted_forms.first.fields)
  end

  def test_update_savedforlater2
    amazon = setup_amazon("testcase/04")
    page = amazon.get(AmazonOrganizer::Amazon::URL_SHOPPING_CART)
    page2 = amazon.get(page.saved_list_urls[0])

    new_states = {}
    page2.active_items.each{|i| new_states[i.asin] = :active}
    asins = page2.saved_items.collect{ |i| i.asin }
    new_states[asins[0]] = :active
    new_states[asins[1]] = :delete
    new_states[asins[3]] = :active
    new_states[asins[4]] = :delete
    page2.update(new_states)

    expected_fields = {
      "delete.s2"=>"Delete",
      "moveToCart.s1"=>"Move to Cart",
      "delete.s5"=>"Delete",
      "moveToCart.s4"=>"Move to Cart"
    }
    assert_equal(expected_fields, @@submitted_forms.first.fields)
  end

  def initialize_test_new_states(agent, page)
    result = {}
    pages = [page]
    pages += page.active_list_urls.collect{|url| agent.get(url)}
    pages += page.saved_list_urls.collect{|url| agent.get(url)}
    pages.each do |page|
      page.active_items.collect { |item| result[item.asin] = :active }
      page.saved_items.collect { |item| result[item.asin] = :saved }
    end
    result
  end

  def test_update_cart
    amazon = setup_amazon("testcase/04")
    page = amazon.get(AmazonOrganizer::Amazon::URL_SHOPPING_CART)
    new_states = initialize_test_new_states(amazon, page)
    new_states["4627845618"] = :delete   # gno_cart 1st of active
    new_states["4894714426"] = :delete   # gno_cart 1st of saved
    new_states["4873113563"] = :delete   # active-1 1st
    new_states["4274066428"] = :delete   # active-2 1st
    new_states["4627841426"] = :delete   # saved-1 1st
    new_states["4797347376"] = :delete   # saved-1 1st

    amazon.update(new_states)
    expected_form_submissions = [
                                 [saved_list_url(2), {"delete.s1"=>"Delete"}],
                                 [saved_list_url(1), {"delete.s1"=>"Delete"}],
                                 [AmazonOrganizer::Amazon::URL_SHOPPING_CART, 
                                                {"delete.s1"=>"Delete", "delete.1"=>"Delete"}],
                                 [active_list_url(2), {"delete.1"=>"Delete"}],
                                 [active_list_url(1), {"delete.1"=>"Delete"}],
                                 [AmazonOrganizer::Amazon::URL_SHOPPING_CART,
                                                {"delete.s1"=>"Delete", "delete.1"=>"Delete"}],
                                ]
    assert_equal(expected_form_submissions, 
                 @@submitted_forms.collect{|form| [form. url, form.fields]})

  end

  # test avoidance of redundant form submit
  def test_update_cart2 
    amazon = setup_amazon("testcase/04")
    page = amazon.get(AmazonOrganizer::Amazon::URL_SHOPPING_CART)
    new_states = initialize_test_new_states(amazon, page)
    new_states["4873113563"] = :delete   # active-1 1st
    new_states["4627841426"] = :delete   # saved-1 1st

    amazon.update(new_states)
    expected_form_submissions = [
                                 [saved_list_url(1), {"delete.s1"=>"Delete"}],
                                 [active_list_url(1), {"delete.1"=>"Delete"}],
                                ]
    assert_equal(expected_form_submissions, 
                 @@submitted_forms.collect{|form| [form. url, form.fields]})

  end

  def test_cart_fetch
    amazon = setup_amazon("testcase/04")
    local_items = %w(
                  AAA
                  4627845618
                  BBB
                  4894711370
                  CCC
                  )
    not_found = amazon.fetch(local_items)
    expected = %w(
                  4627845618:active
                  4894711370:active
                  4777513327:active
                  4777514625:active
                  433902399X:active
                  4894717212:active
                  4894717239:active
                  4777511340:active
                  4274066436:active
                  4274064611:active
                  4894714426:saved
                  4627847718:saved
                  4274200345:saved
                  4627843216:saved
                  4254121458:saved
                  4627844115:saved
                  4873113776:saved
                  4789836959:saved
                  4320120779:saved
                  4798021180:saved
                  4873113563:active
                  4839931496:active
                  4798019437:active
                  4798119881:active
                  4797340045:active
                  4894712857:active
                  4798114723:active
                  4777512924:active
                  479811801X:active
                  4797352604:active
                  4274066428:active
                  4822234304:active
                  4863540221:active
                  4873113679:active
                  4873113946:active
                  4797336617:active
                  4627841426:saved
                  4777513432:saved
                  4274065782:saved
                  4563015741:saved
                  4877831789:saved
                  4797344377:saved
                  4777510328:saved
                  4797346809:saved
                  4048673610:saved
                  493900791X:saved
                  4797347376:saved
                  4877832068:saved
                  4797341874:saved
                  4939007375:saved
                  4939007359:saved
                )
    assert_equal(expected, @list.collect{|pair| pair[0].asin + ":" + pair[1].to_s})
    assert_equal(%w(AAA BBB CCC), not_found.sort)
  end
end

                  
