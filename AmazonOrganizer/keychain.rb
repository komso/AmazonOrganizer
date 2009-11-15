require 'rubygems'
require 'osx/cocoa'
require 'uri'

class OSX::Keychain
  include OSX
  PROTOCOLS = {
    "https" => {:type => KSecProtocolTypeHTTPS, :standard_port => 443},
    "http" => {:type => KSecProtocolTypeHTTP, :standard_port => 80},
  }

  AMAZON_URI = "https://www.amazon.co.jp/"


  def add_internet_password(uri, account, password)
    uri = URI.parse(uri)

    addInternetPassword_Server_Port_Path_Account_Password(PROTOCOLS[uri.scheme][:type],
                                                          uri.host,
                                                          port(uri),
                                                          filter_path(uri.path),
                                                          account,
                                                          password)
  end

  def add_or_update_account(account, password)
    if getAccounts.to_a.include?(account)
      setPassword_Password(account, password)
    else
      add_internet_password(AMAZON_URI, account, password)
    end
  end

  private

  def filter_path(path)
    return path == "/" ? "" : path
  end

  def port(uri)
    return PROTOCOLS[uri.scheme][:standard_port] == uri.port ? 0 : uri.port
  end
end

