# coding: utf-8
require 'homebus'

require 'net/http'
require 'json'

require 'jwt'

require 'dotenv'

require 'date'

class FlumeHomebusApp < Homebus::App
  DDC_WATER_FLOW = 'org.homebus.experimental.water-flow'

  def initialize(options)
    @options = options
    super
  end

  def update_interval
    60
  end

  def setup!
    Dotenv.load('.env')

    @auth_token = ENV['FLUME_AUTH_TOKEN']
    @flume_user_id = ENV['FLUME_USER_ID']
    @flume_device_id = ENV['FLUME_DEVICE_ID']

    @client_id = ENV['FLUME_CLIENT_ID']
    @client_secret = ENV['FLUME_CLIENT_SECRET']

    @username = ENV['FLUME_USERNAME']
    @password = ENV['FLUME_PASSWORD']

    @device = Homebus::Device.new name: 'Flume water meter',
                                  manufacturer: 'Flume',
                                  model: '',
                                  serial_number: @flume_device_id
  end

  def _gpm_to_lps(gallons_per_minute)
    gallons_per_minute * 0.0630901964
  end

  def _login
    url = 'https://api.flumewater.com/oauth/token'

    begin
      uri = URI(url)
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      req = Net::HTTP::Post.new(uri.path)
      req['Content-Type'] = 'application/json'
      req.body = JSON.generate({
                                 grant_type: 'password',
                                 client_id: @client_id,
                                 client_secret: @client_secret,
                                 username: @username,
                                 password: @password
                               })

      results = https.request(req)

      response = JSON.parse results.body, symbolize_names: true
    rescue => e
      puts e
      puts 'login fail'
      return nil
    end

    unless response[:success] && response[:data]
      return nil
    end

    @auth_token = response[:data][0][:access_token]
    @refresh_token = response[:data][0][:refresh_token]
  end

  def _token_expired?
    decoded_token = JWT.decode @auth_token, nil, false

    return decoded_token[0]["exp"] < Time.now.to_i
  end

  def _refresh_token
    url = 'https://api.flumewater.com/oauth/token'    

    begin
      uri = URI(url)
      http = Net::HTTP.new(uri.host)
      http.body = JSON.generate({ grant_type: 'refresh_token',
                                  refresh_token: @refresh_token,
                                  client_id: @client_id,
                                  client_secret: @client_secret
                                })

      http.headers['Content-type'] = 'application/json'

      results = http.post(uri)
      response = JSON.parse results, symbolize_names: true
    rescue
      return nil
    end

    unless response[:success] && response[:data][:active]
      return nil
    end

    @auth_token = ''
  end

  def _get_token
    if @refresh_token
      _refresh_token
    else
      _login
    end
  end

  def _get_usage
    if _token_expired?
      _get_token
    end

    url = "https://api.flumewater.com/users/#{@flume_user_id}/devices/#{@flume_device_id}/query?limit=2000&offset=0&sort_field=id&sort_direction=DESC"

    begin
      uri = URI(url)
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      req = Net::HTTP::Post.new(uri.path)
      req['Authorization'] = "Bearer #{@auth_token}"
      req['Content-Type'] = 'application/json'

      one_minute_ago = (Time.now - 60).to_datetime
      since = DateTime.new(one_minute_ago.year, one_minute_ago.month, one_minute_ago.day, one_minute_ago.hour, one_minute_ago.minute, 0)

      req_id = Time.now.to_s

      query = {
        queries: [
          {
            bucket: 'MIN',
            request_id: req_id,
            since_datetime: since.to_time.to_s.sub(/\s+\S*$/, ''),
          }
        ]
      }

      req.body = JSON.generate(query)
      results = https.request(req)
      
      response = JSON.parse results.body, symbolize_names: true
    rescue => e
      puts "flume api failed"
      pp e

      return nil
    end

    unless response[:success] && response[:data]
      puts 'bad response'
      return nil
    end

    # this is really fragile and needs to be rewritten
    return _gpm_to_lps(response[:data][0][req_id.to_sym][0][:value])
  end

    # https://api.flumewater.com/users/FLUME_USER_ID/devices/FLUME_DEVICE_ID/budgets?limit=2000&offset=0&sort_field=id&sort_direction=DESC
    # {
    #    "success": true,
    #    "code": 602,
    #    "message": "Request OK",
    #    "http_code": 200,
    #    "http_message": "OK",
    #    "detailed": null,
    #    "data": [
    #        {
    #            "id": 52096,
    #            "name": "Monthly Budget",
    #            "type": "MONTHLY",
    #            "value": 15100,
    #            "thresholds": [
    #                13590,
    #                15100
    #            ],
    #            "actual": 17.5863356
    #        }
    #    ],
    #    "count": 1,
    #    "pagination": null
    # }


    # https://api.flumewater.com/users/49804/devices/6782463004464397610/query/active?limit=2000&offset=0&sort_field=id&sort_direction=DESC

    #{
    #    "success": true,
    #    "code": 602,
    #    "message": "Request OK",
    #    "http_code": 200,
    #    "http_message": "OK",
    #    "detailed": null,
    #    "data": [
    #        {
    #            "active": true,
    #            "datetime": "2021-09-18 21:17:00"
    #        }
    #    ],
    #    "count": 1,
    #    "pagination": null
    #}

  def work!
    response = _get_usage

    if response
      if @options[:verbose]
        pp response
      end

      if @options[:verbose]
        pp payload
      end

      payload = {
        interval: 60,
        flow: response
      }

      @device.publish! DDC_WATER_FLOW, payload
    else
      puts 'no response from flume'
    end

    sleep update_interval
  end

  def name
    'Homebus Flume water meter publisher'
  end

  def publishes
    [ DDC_WATER_FLOW ]
  end

  def devices
    [ @device ]
  end
end
