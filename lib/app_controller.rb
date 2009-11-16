# -*- coding: utf-8 -*-
require 'rubygems'
require 'osx/cocoa'
require 'yaml'
require 'fileutils'
require 'logger'

class AppController < OSX::NSObject
  include OSX

  attr_accessor :config_path
  attr_reader :log
  attr_reader :cart
  attr_reader :account_database

##------------
## Initialize
##------------
  def initialize
    # make -W2 quite
    @config = nil
  end

  def awakeFromNib
    @config_path = "~/Library/Application Support/AmazonOrganizer/Config.yaml"
    Kernel.const_set(:App, self)
    @account_database = AccountDatabase.new
    @log = Logger.new(STDOUT)
  end

  # initializer called by Unit Test
  def test_initialize
    verbose = $VERBOSE
    $VERBOSE = nil  # to mask const_set warning
    awakeFromNib
    $VERBOSE = verbose
    @cart = AmazonCart.new
  end

##---------------
## Configuration
##---------------
  def load_config
    config_path = File.expand_path(@config_path)
    
    @config = YAML.load(File.read(config_path)) rescue {}
    @config = {} unless @config.kind_of?(Hash)
  end

  def save_config
    config_path = File.expand_path(@config_path)
    File.open(config_path, "w") do |file|
      file.print(@config.to_yaml)
    end
  end

  def config
    load_config if @config.nil?
    @config
  end

##--------------------
## Main Window / Menu 
##--------------------
  ib_action :reload
  ib_action :move_active_to_saved
  ib_action :move_saved_to_active
  ib_action :submit
  ib_action :terminate
  
  ib_outlet :application
  ib_outlet :cart

  def reload(sender)
    Thread.start do 
      @cart.reload
    end
  end

  def submit(sender)
    @cart.submit
  end

  def move_active_to_saved(sender)
    move(:saved, @cart.active_items)
  end

  def move_saved_to_active(sender)
    move(:active, @cart.saved_items)
  end

  def move(to, from_list)
    from_list.selectedObjects.to_a.each do |item|
      @cart.move_item(to, item)
    end
  end

  def terminate(sender)
    @cart.save_local_cache
    @application.terminate(sender)
  end
  
##----------------
## Account Dialog
##----------------
  ib_action :configure_account
  ib_action :set_account_info
  ib_action :close_account_dialog
  
  ib_outlet :main_window
  ib_outlet :account_dialog
  ib_outlet :account_email
  
  def get_accounts
    @account_database.get_accounts
  end

  def get_account_index(accounts)
    accounts.index(config[:account_name]) || 0
  end

  def configure_account(sender)
    accounts = get_accounts
    @account_email.addItemsWithObjectValues(accounts)
    if accounts.size > 0
      @account_email.selectItemAtIndex(get_account_index(accounts))
    end

    NSApp.beginSheet_modalForWindow_modalDelegate_didEndSelector_contextInfo_(@account_dialog, @main_window, self, "account_dialog_end", nil)
  end
  
  def set_account_info(sender)
    config[:account_name] = @account_email.stringValue.to_s
    save_config()
    NSApp.endSheet_(@account_dialog)
  end
  
  def close_account_dialog(sender)
    NSApp.endSheet_(@account_dialog)
  end

  def account_dialog_end(sheet, return_code, context_info)
    sheet.orderOut_(self)
  end

##-----------
## Utilities
##-----------
  # return an empty Alert 
  #   This should be used instead of creating NSAlert directly.
  #   This will give Unit Test a way to set stub on alert.
  def alert
    NSAlert.alloc.init
  end

##-----------------
## Method Wrappers
##-----------------
  # making all actions error handler 
  # FIXME : should be done automatically
  error_handler :reload
  error_handler :move_active_to_saved
  error_handler :move_saved_to_active
  error_handler :submit
  error_handler :terminate
  error_handler :configure_account
  error_handler :set_account_info
  error_handler :close_account_dialog
end

