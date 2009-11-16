require 'test/unit'

require 'rubygems'
require 'mocha'
require 'amazon_organizer'
require 'yaml'

class TC_AmazonCartTest < Test::Unit::TestCase
  include Helper

  def setup
    @items = fixture_items(0..3)
    @item_models = fixture_item_models(@items)
    @cart = AmazonCart.new
    @cart.test_initialize
    App.account_database.keychain.stubs(:getPassword)
  end

  def array_values(nsarray)
    nsarray.collect do |i|
      i.asin
    end
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

  def test_add
    @cart.add(@items[0], :active)
    assert_equal(["0"], array_values(@cart.active_items_model))
    assert_equal([], array_values(@cart.saved_items_model))
    @cart.add(@items[1], :saved)

    assert_equal(["0"], array_values(@cart.active_items_model))
    assert_equal(["1"], array_values(@cart.saved_items_model))
  end

  def test_save_image
    @cart.active_items.addObject(@item_models[0])
    @cart.active_items.addObject(@item_models[1])
    @cart.saved_items.addObject(@item_models[2])
    @cart.saved_items.addObject(@item_models[3])
    save_image = @cart.get_save_image
    assert_equal(%w(item0 item1), save_image[:active_items].collect{|i| i[:title]})
    assert_equal(%w(item2 item3), save_image[:saved_items].collect{|i| i[:title]})
  end

  # FIXME : move this to test_item_model.rb (when it is created)
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

  def test_restore_items_from_save_image
    save_image = [
      {:price=>0, :smallimage=>"0.jpg", :asin=>"0", :title=>"item0"},
      {:price=>1, :smallimage=>"1.jpg", :asin=>"1", :title=>"item1"} 
    ]   
    @cart.restore_items_from_save_image(:active, save_image)
    assert_equal(%w(item0 item1), @cart.active_items_model.collect{|i| i.title})
  end

  def test_restore_from_save_image
    save_image = {
      :active_items => [
                        {:price=>0, :smallimage=>"0.jpg", :asin=>"0", :title=>"item0"},
                        {:price=>1, :smallimage=>"1.jpg", :asin=>"1", :title=>"item1"} ,
                       ],
      :saved_items => [
                        {:price=>2, :smallimage=>"2.jpg", :asin=>"2", :title=>"item2"},
                        {:price=>3, :smallimage=>"3.jpg", :asin=>"3", :title=>"item3"},
                       ]
    }
    @cart.restore_from_save_image(save_image)
    assert_equal(%w(item0 item1), @cart.active_items_model.collect{|i| i.title})
    assert_equal(%w(item2 item3), @cart.saved_items_model.collect{|i| i.title})
  end

  def test_item_model_yaml
    item = ItemModel.new
    item.asin = "ASIN-dummy"
    item.title = "title-dummy"
    item.price = "0"
    item.smallimage = "smallimage-dummy"
  end

  def clear_list_and_hash
    # reset state
    @cart.active_items.removeObjects(@cart.active_items_model.to_a)
    @cart.saved_items.removeObjects(@cart.saved_items_model.to_a)
    @cart.items.clear
  end

  def move_test_helper(active, saved, expected)
    yield
    assert_equal(active, array_values(@cart.active_items_model))
    assert_equal(saved, array_values(@cart.saved_items_model))

    expected_hash = {}
    expected.each do |index, state|
      asin = "#{index}"
      expected_hash[asin] = [state, @item_models[index]]
    end
    assert_equal(expected_hash, @cart.items)
  end

  def test_move_item
    move_test_helper(["0"], [], {0 => :active}) do 
      @cart.move_item(:active, @item_models[0])
    end
    move_test_helper(["0", "1"], ["2", "3"], {0 => :active, 1 => :active, 2 => :saved, 3 => :saved}) do 
      @cart.move_item(:active, @item_models[1])
      @cart.move_item(:saved, @item_models[2])
      @cart.move_item(:saved, @item_models[3])
    end
    move_test_helper(["1"], ["2", "3", "0"], {0 => :saved, 1 => :active, 2 => :saved, 3 => :saved}) do 
      @cart.move_item(:saved, @item_models[0])
    end
    move_test_helper(["1", "3"], ["2", "0"], {0 => :saved, 1 => :active, 2 => :saved, 3 => :active}) do 
      @cart.move_item(:active, @item_models[3])
    end
    move_test_helper(["3"], ["2", "0"], {0 => :saved, 2 => :saved, 3 => :active}) do 
      @cart.move_item(nil, @item_models[1])
    end
    move_test_helper(["3"], ["2"], {2 => :saved, 3 => :active}) do 
      @cart.move_item(nil, @item_models[0])
    end
    assert_raise ArgumentError do
      @cart.move_item(nil, @item_models[0])
    end
    assert_raise ArgumentError do
      item = ItemModel.new
      item.asin = nil
      item.title = "title-dummy"
      item.price = "0"
      item.smallimage = "smallimage-dummy"
      @cart.move_item(nil, item)
    end
    assert_raise NameError do
      @cart.move_item(:dummy, @item_models[2])
    end
  end

  # add_item and delete_item are thin wrapper of move_item. tested only lightly
  def test_add_delete
    move_test_helper(["0"], [], {0 => :active}) do 
      @cart.add_item(:active, @item_models[0])
    end
    move_test_helper([], [], {}) do 
      @cart.delete_item(@item_models[0])
    end
  end

  def test_add_to_update
    @cart.add_item(:active, @item_models[0])    
    @cart.add_item(:saved, @item_models[1])    
    item1 = stub(:asin => "1", :title => "item1", :price => 1, :smallimage => "1.jpg")
    move_test_helper(["0", "1"], [], {0 => :active, 1 => :active}) do 
      @cart.add(item1, :active)
    end
    move_test_helper(["0", "1"], ["2"], {0 => :active, 1 => :active, 2 => :saved}) do 
      @cart.add(@items[2], :saved)
    end
  end

  def test_state_to_save
    testcase = {"0" => :saved, "1" => :active, "2" => :saved, "3" => :active}
    testcase.each do |index_string, state|
      @cart.add_item(state, @item_models[index_string.to_i])
    end
    assert_equal(testcase, @cart.get_state_to_save)
  end

  def test_fetch
    dummy_amazon = Object.new
    dummy_amazon.instance_variable_set(:@list, @cart)
    dummy_amazon.instance_variable_set(:@items, @items)
    def dummy_amazon.reload(list)
      @local_items = list.sort
      @list.add(@items[0], :active)
      @list.add(@items[1], :saved)
      return ["3"]
    end
    @cart.instance_variable_set(:@amazon, dummy_amazon)
    @cart.add_item(:active, @item_models[0])    
    @cart.add_item(:saved, @item_models[3])    
    move_test_helper(["0"], ["1"], {0 => :active, 1 => :saved}) do 
      @cart.reload.join
    end
    assert_equal(["0", "3"], dummy_amazon.instance_variable_get(:@local_items))
  end

end
