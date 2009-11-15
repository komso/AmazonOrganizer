require 'test/unit'
require 'rubygems'
require 'mocha'
require 'amazon_organizer'

class TC_AccountInfoTest < Test::Unit::TestCase
  def setup
    @info = AccountInfo.new
  end

  def test_account_name
    App.stubs(:config).returns({:account_name => "email@dummy.com"})
    assert_equal("email@dummy.com", @info.account_name)
  end

  def test_account_name2
    App.stubs(:config).returns({})
    assert_raises(AccountError, "account name is not specified") do 
      @info.account_name
    end

    App.stubs(:config).returns({:account_name => nil})
    assert_raises(AccountError, "account name is not specified") do 
      @info.account_name
    end
  end

  def test_password
    App.stubs(:config).returns({:account_name => "email@dummy.com"})
    App.account_database.stubs(:get_password => "password")
    assert_equal("password", @info.password)
  end

  def test_password2
    App.stubs(:config).returns({})
    App.account_database.stubs(:get_password => "password")
    assert_raises(AccountError, "account name is not specified") do
      assert_equal("password", @info.password)
    end
  end
end



