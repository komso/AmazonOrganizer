require 'test/unit'

class TC_ExceptionTest < Test::Unit::TestCase

  def setup
    @message = AccountError::NO_ACCOUNT_MESSAGE
    @info = AccountError::CONFIGURE_ACCOUNT_INFO
    App.stubs(:configure_account)
  end

  def test_message
    err = AccountError.new(@message)
    assert_equal(@message, err.message)
    err.informative_text = @info
    assert_equal(@info, err.informative_text)
  end

  def test_whats_next
    App.expects(:configure_account).with(App)
    err = AccountError.new(@message)
    err.whats_next
  end

  def set_account_error_expectation
    alert = stub()
    App.stubs(:alert).returns(alert)
    alert.expects(:messageText=).with(@message)
    alert.expects(:informativeText=).with(@info)
    alert.expects(:addButtonWithTitle).with("OK")
    alert.expects(:runModal)
    App.expects(:configure_account)
  end

  def test_show_alert
    set_account_error_expectation
    err = AccountError.new(@message)
    err.informative_text = @info
    err.show_alert
  end

  # Should be OK to call show_alert on any Excetion
  def test_show_alert2
    err = RuntimeError.new
    assert_nothing_raised do 
      err.show_alert
    end
  end

  class Sample
    def initialize(foo)
      @foo = foo
    end

    def hello_world(sender)
      raise sender if sender.is_a?(Exception)
      sender + @foo
    end
    error_handler :hello_world
  end

  def test_hello
    s = Sample.new(" world!")
    # check wrapped method's functionality
    assert_equal("hello world!", s.hello_world("hello"))

    # check error handling behavior
    set_account_error_expectation
    err = AccountError.new(@message)
    err.informative_text = @info
    assert_nothing_raised {
      s.hello_world(err)
    }
  end
end
