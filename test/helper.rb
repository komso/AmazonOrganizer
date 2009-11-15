require 'rubygems'
require 'mocha'
require 'amazon_organizer'
require 'ostruct'


module Helper
  extend Mocha::API
  # Unit Test need to set stub on App even when the test itself does not instantiate AppController.
  # This dummy tentative definition of App constant will help them stub behavior of App.
  $DUMMY_APP = OpenStruct.new(
                              :account_database => OpenStruct.new(:keychain => Object.new),
                              :log => stub_everything()
                              )
  Kernel.const_set(:App, $DUMMY_APP)
  
  def fixture_items(range)
    range.collect do |num|
      item = AmazonOrganizer::Item.new("#{num}", {:title => "item#{num}", :price => num})
      item.stubs(:fetch_attr)
      item.attr[:smallimage] = "#{num}.jpg"
      item
    end
  end
  
  def fixture_item_models(items)
    items.collect do |item|
      item_model = ItemModel.new
      item_model.copy_item(item)
      item_model
    end
  end
  
  def clear_app_const
    verbose = $VERBOSE
    $VERBOSE = nil
    Kernel.const_set(:App, $DUMMY_APP)  
    $VERBOSE = verbose
  end
  
end
