# This class provid account information (a pair of account_name and password)
# to AmazonOrganizer#Amazon. Amazon#auto_signin will use this information

# AccountInfo will ask configuguration and password information to other object
# and may raise exception which is not handled by AmazonOrganizer#Amazon.

class AccountInfo

  def account_name
    if App.config[:account_name].nil?
      err = AccountError.new(AccountError::NO_ACCOUNT_MESSAGE)
      err.informative_text = AccountError::CONFIGURE_ACCOUNT_INFO
      raise(err)
    end
    
    App.config[:account_name]
  end

  def password
    App.account_database.get_password(account_name)
  end
end
