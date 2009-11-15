require 'test/unit'
require 'rubygems'
require 'osx/cocoa'
require 'fileutils'
require 'amazon_organizer'

class TC_KeychainTest < Test::Unit::TestCase
  def setup
    keychain_path = File.dirname(__FILE__) + "/keychain_for_test.keychain"
    if FileTest.exists?(keychain_path)
      FileUtils.rm(keychain_path)
    end
    @keychain = OSX::Keychain.alloc.initWithNewKeychain(keychain_path)
    @keychain.add_internet_password("https://www.amazon.co.jp/", "email@dummy.com", "password")
    @keychain.add_internet_password("https://www.amazon.co.jp:8080/", "test@dummy.com", "password")
  end

  def teardown
    @keychain.cleanup
  end

  def ruby(ref)
    case ref
    when OSX::NSArray
      ref.to_ary.collect {|item| ruby(item)}
    when OSX::NSString
      ref.to_s
    end
  end

  def test_bad_add_internet_password
    # These should not crash (at least)
    @keychain.add_internet_password("https://www.amazon.co.jp/", nil, "password")
    @keychain.add_internet_password("https://www.amazon.co.jp/", "email@dummy.com", nil)

    assert_raises(URI::InvalidURIError) {
      @keychain.add_internet_password(nil, "email@dummy.com", "password")
    }
  end

  def test_get_password
    assert_equal("password", ruby(@keychain.getPassword("email@dummy.com")))
    assert_equal(nil, ruby(@keychain.getPassword(nil)))
  end

  def test_get_accounts
    assert_equal(%w[email@dummy.com test@dummy.com], ruby(@keychain.getAccounts).sort)
  end

  def test_set_password
    @keychain.setPassword_Password("email@dummy.com", "newpass")
    assert_equal("newpass", ruby(@keychain.getPassword("email@dummy.com")))
    @keychain.setPassword_Password("email@dummy.com", nil)
    assert_equal("newpass", ruby(@keychain.getPassword("email@dummy.com")))
    @keychain.setPassword_Password(nil, "foo") # this should not cause BUS Error

    assert_equal("password", ruby(@keychain.getPassword("test@dummy.com")))
    @keychain.setPassword_Password("test@dummy.com", "lalala")
    assert_equal("lalala", ruby(@keychain.getPassword("test@dummy.com")))
    @keychain.setPassword_Password("test@dummy.com", nil)
    assert_equal("lalala", ruby(@keychain.getPassword("test@dummy.com")))
  end

  def test_add_or_update
    assert_equal("password", ruby(@keychain.getPassword("email@dummy.com")))
    @keychain.add_or_update_account("email@dummy.com", "newpass")
    assert_equal("newpass", ruby(@keychain.getPassword("email@dummy.com")))

    @keychain.add_or_update_account("new@dummy.com", "weak_password!")
    assert_equal(%w[email@dummy.com new@dummy.com test@dummy.com], ruby(@keychain.getAccounts).sort)
    assert_equal("weak_password!", ruby(@keychain.getPassword("new@dummy.com")))
  end

end
