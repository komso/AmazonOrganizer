require 'test/unit'
require 'rubygems'
require 'mocha'
require 'amazon_organizer'

class TC_AccountDatabaseTest < Test::Unit::TestCase
  def setup
    @db = AccountDatabase.new

    @server = "www.amazon.co.jp"
    @email = "email@dummy.com"
    @password = "password"
  end

  def str(string)
    [string, string.length]
  end
  
  def test_get_password
    @db.keychain.expects(:getPassword).with(@email).returns(@password)
    @db.get_password(@email)
  end


end



