require 'test/unit'
require 'yaml'

class TC_ItemModelTest < Test::Unit::TestCase
  include Helper

  def setup
    @items = fixture_items(0..3)
    @item_models = fixture_item_models(@items)
  end

  def test_item_model_equal
    item_model = ItemModel.new
    item_model.asin = "0"
    item_model.title = "item0"
    item_model.price = 0
    item_model.smallimage = "0.jpg"
    assert(item_model == @item_models[0])
    assert(@item_models[0] == item_model)
  end

  def test_item_initialize
    item_model = ItemModel.new
    item_model.copy_item(@items[0])
    [:asin, :title, :price, :smallimage].each do |name|
      assert_equal(item_model.send(name), @items[0].send(name))
    end
  end

  def test_item_save_image
    assert_equal({:price=>0, :smallimage=>"0.jpg", :asin=>"0", :title=>"item0"}, 
                 @item_models[0].get_save_image)
  end

  def test_item_save_image2
    item_model = ItemModel.new
    save_image = {:price=>0, :smallimage=>"0.jpg", :asin=>"0", :title=>"item0"}
    item_model.restore_from_save_image(save_image)
    
    [:asin, :title, :price, :smallimage].each do |name|
      assert_equal(item_model.send(name), save_image[name])
    end
  end
end
