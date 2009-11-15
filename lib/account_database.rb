require 'osx/cocoa'

OSX::require_framework 'Security'
if(!Object.const_defined?(:Test))
  OSX::load_bridge_support_file(OSX::NSBundle.mainBundle.pathForResource_ofType("Security", "bridgesupport"))
else
  OSX::load_bridge_support_file(File.dirname(__FILE__) + "/../AmazonOrganizer/English.lproj/Security.bridgesupport")
end

class AccountDatabase
  include OSX

  def initialize
    @keychain = Keychain.alloc.init(nil)
  end

  SERVER = "www.amazon.co.jp"

  attr_reader :keychain

  def get_password(account_name)
    @keychain.getPassword(account_name).to_s
  end

  def get_accounts
    @keychain.getAccounts.collect do |item|
      item.to_s
    end
  end
end
