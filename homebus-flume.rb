#!/usr/bin/env ruby

require './options'
require './app'

flume_app_options = FlumeHomebusAppOptions.new

flume = FlumeHomebusApp.new flume_app_options.options
flume.run!
