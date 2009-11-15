require 'test/unit'

require 'rubygems'
require 'mocha'
require 'amazon_organizer'
require 'yaml'


class TC_AppControllerTest < Test::Unit::TestCase
  include Helper

  def setup
    @items = fixture_items(0..3)
    @item_models = fixture_item_models(@items)
    @app = AppController.new
    @app.test_initialize

    @app.config_path = "Config.yaml" 
    @cart = @app.cart
    @cart.test_initialize
  end

  def teardown
    clear_app_const
  end

  def array_values(nsarray)
    nsarray.collect do |i|
      i.asin
    end
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

  def index_set(array)
    indexes = OSX::NSMutableIndexSet.indexSet
    array.each do |i|
      indexes.addIndex(i)
    end
    indexes
  end

  # test implementation of move item action 
  def test_move
    (0..3).each { |i| @cart.add_item(:active, @item_models[i]) }

    @cart.active_items.setSelectionIndexes(index_set([0, 2]))
    move_test_helper(["1", "3"], ["0", "2"], {0 => :saved, 1 => :active, 2 => :saved, 3 => :active}) do 
      @app.move(:saved, @cart.active_items)
    end

    @cart.active_items.setSelectionIndexes(index_set([0]))
    @cart.saved_items.setSelectionIndexes(index_set([]))
    move_test_helper(["3"], ["0", "2", "1"], {0 => :saved, 1 => :saved, 2 => :saved, 3 => :active}) do 
      # argument is dummy
      @app.move_active_to_saved(nil)
    end
    @cart.active_items.setSelectionIndexes(index_set([]))
    @cart.saved_items.setSelectionIndexes(index_set([1, 2]))
    move_test_helper(["3", "2", "1"], ["0"], {0 => :saved, 1 => :active, 2 => :active, 3 => :active}) do 
      # argument is dummy
      @app.move_saved_to_active(nil)
    end
  end

  def test_load_configuration
    assert_equal({:account_name => "test@dummy.com"}, @app.config)
  end

  def test_load_configuration2
    @app.config_path = "NON_EXISTENT_FILE.yaml"
    assert_nothing_raised do 
      assert_equal({}, App.config)
    end
  end

  def test_load_configuration3
    @app.config_path = "BrokenConfig.yaml"
    assert_nothing_raised do 
      assert_equal({}, App.config)
    end
  end

  def test_save_configuration
    @app.config_path = "output.yaml"
    App.config[:account_name] = "test@dummy.com"
    App.save_config
    assert_equal(App.config, YAML.load(File.read("output.yaml")))
  end

##
## account
##
  def ns(str_ary)
    result = OSX::NSMutableArray.arrayWithCapacity(str_ary.length)
    str_ary.each do |item|
      result.addObject(OSX::NSString.alloc.initWithString(item))
    end
  end

  def test_get_accounts_and_index
    accounts = %w[foo bar zot]
    @app.account_database.keychain.stubs(:getAccounts).returns(ns(accounts))
    app_accounts = @app.get_accounts
    assert_equal(accounts, app_accounts)

    App.stubs(:config).returns({})
    assert_equal(0, @app.get_account_index(app_accounts))

    App.stubs(:config).returns({:account_name => "foo"})
    assert_equal(0, @app.get_account_index(app_accounts))

    App.stubs(:config).returns({:account_name => "bar"})
    assert_equal(1, @app.get_account_index(app_accounts))
  end

end
