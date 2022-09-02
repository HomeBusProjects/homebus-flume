require 'homebus/options'

require 'homebus-flume/version'

class HomebusFlume::Options < Homebus::Options
  def app_options(op)
  end

  def banner
    'HomeBus Flume publisher'
  end

  def version
    HomebusFlume::VERSION
  end

  def name
    'homebus-flume'
  end
end
