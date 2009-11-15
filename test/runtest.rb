#!/usr/bin/ruby -Ku -W2

Dir.chdir(File.dirname(__FILE__))
$LOAD_PATH.push("../lib")
$LOAD_PATH.push("../AmazonOrganizer")

require 'test/unit/autorunner'
require 'helper'

runner = Test::Unit::AutoRunner.new(true)
runner.run

