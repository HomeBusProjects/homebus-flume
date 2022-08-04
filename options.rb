require 'homebus/options'

class FlumeHomebusAppOptions < Homebus::Options
  def app_options(op)
  end

  def banner
    'HomeBus Flume publisher'
  end

  def version
    '0.0.1'
  end

  def name
    'homebus-flume'
  end
end
