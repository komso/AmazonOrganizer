require 'rubygems'
require 'mechanize'
require 'logger'

class AmazonOrganizer::Amazon
  URL_SIGN_IN = "https://www.amazon.co.jp/gp/sign-in.html"
  URL_SHOPPING_CART = "http://www.amazon.co.jp/gp/cart/view.html/ref=gno_cart"

  def initialize(list, account_info, logger=nil)
    @list = list
    @account_info = account_info
    @agent = WWW::Mechanize.new do
      |a| a.user_agent_alias = 'Mac Safari'
      a.log = logger if logger
    end
    @active_list_urls = []
    @signed_in = false
  end

  attr_reader :active_list_urls

  def signed_in?
    @signed_in
  end

  def auto_sign_in
    sign_in(@account_info.account_name, @account_info.password) if !@signed_in
  end

  def sign_in(account_name, password)
    @agent.get(URL_SIGN_IN)
    @agent.page.form_with(:name => "sign-in") do |form|
      form.email = account_name
      form.password = password
    end.submit
    @signed_in = true
  end

  def get(url)
    auto_sign_in
    AmazonOrganizer::Page.new(@agent.get(url))
  end

  def record_item(item, state, found)
    @list.add(item, state)
    found << item.asin
  end
  
  def record_items(page, found)
    page.active_items.each {|item| record_item(item, :active, found)}
    page.saved_items.each {|item| record_item(item, :saved, found)}
  end

  def reload
    cart = get(URL_SHOPPING_CART)
    result = []
    record_items(cart, result)
    (cart.active_list_urls + cart.saved_list_urls).each do |url|
      record_items(get(url), result)
    end
    result
  end

  def submit(new_states)
    # The order of update was choosen to 1) avoid missing any item and 
    # 2) reflect new_states of active items as close as possible

    # update saved lists first (in reverse order of the pages)
    cart = get(URL_SHOPPING_CART)
    (cart.saved_list_urls.reverse.collect{|url| get(url)} + [cart]).each do |page|
      page.update(new_states)
    end

    # refresh cart top page (to reflect items moved from saved lists)
    cart = get(URL_SHOPPING_CART)
    # update active lists first (in reverse order of the pages)
    (cart.active_list_urls.reverse.collect{|url| get(url)} + [cart]).each do |page|
      page.update(new_states)
    end
  end

end
