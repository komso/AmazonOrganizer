module ErrorHandler
  # Wrap method by error handling code. 
  #   Mainly intended for wraping action.
  #   Other method can be wrapped as well but it must have arity 1.
  #   (With variable number of arguments in define_method block, RubyCocoa pass
  #   0 argument, which causes ArgumentError because action has arity 1.)
  def error_handler(name)
    alias_method "_original_method_#{name}", name
    define_method(name) { |sender|
      begin
        send("_original_method_#{name}", sender)
      rescue Exception
        $!.report
      end
    }
  end
end

class Module
  include ErrorHandler
end

# wrap thread with error handler
class << Thread
  alias_method :_original_start, :start
  alias_method :_original_new, :new
  alias_method :_original_fork, :fork

  def start(*args, &blk)
    send(:_original_start, *args) do |*args2|
      begin
        blk.call(*args2)
      rescue Exception
        $!.report
      end
    end
  end
  alias_method :new, :start
  alias_method :fork, :start
end

class Exception
  def report
    App.log.error(self)
    show_alert
  end

  def show_alert;end
end

class AppError < Exception
  attr_accessor :informative_text
  attr_accessor :button_titles

  def show_alert
    alert = App.alert
    alert.messageText = message || ""
    alert.informativeText = informative_text || ""
    (button_titles || default_button_titles).each do |title|
      alert.addButtonWithTitle(title)
    end
    alert.runModal()
    whats_next
  end

  def default_button_titles
    %w(OK)
  end

  def whats_next
  end
end

class AccountError < AppError
  NO_ACCOUNT_MESSAGE = "Account name is not specified."

  CONFIGURE_ACCOUNT_INFO = "Please specify your amazon account information in Account Setting window."

  def whats_next
    App.configure_account(App)
  end
end

