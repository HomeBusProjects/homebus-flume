require 'uri'
require 'net/http'
require 'json'
require 'jwt'

class FlumeWater
  def initialize(client_id, client_secret, username, password)
    @client_id = client_id
    @client_secret = client_secret
    @username = username
    @password = password
  end

  def login!
    get_tokens

    @user_id = _get_user_from_token
  end
  
  def get_tokens
    url = URI("https://api.flumewater.com/oauth/token")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request["Accept"] = 'application/json'
    request["Content-Type"] = 'application/json'

    payload = {
      grant_type: 'password',
      client_id: @client_id,
      client_secret: @client_secret,
      username: @username,
      password: @password
    }

    request.body = payload.to_json

    response = http.request(request)
    data = JSON.parse response.read_body, symbolize_names: true

    if data[:success]
      @access_token = data[:data][0][:access_token]
      @refresh_token = data[:data][0][:refresh_token]
    end
  end

  def refresh_token
    url = URI("https://api.flumewater.com/oauth/token")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request["Accept"] = 'application/json'
    request["Content-Type"] = 'application/json'

    payload = {
      grant_type: 'refresh_token',
      client_id: @client_id,
      client_secret: @client_secret,
      refresh_token: @refresh_token
    }

    request.body = payload.to_json

    response = http.request(request)
    puts response.read_body

  end

  def get_devices
    url = URI("https://api.flumewater.com/users/#{@user_id}/devices")
    pp url

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(url)
    request["Accept"] = 'application/json'
    request['Authorization'] = "Bearer #{@access_token}"

    pp request['Authorization']


    response = http.request(request)
    puts response.read_body

    data = JSON.parse response.read_body, symbolize_names: true

    if data[:success]
      return data[:data].select{ |d| d[:bridge_id] }
    else
      raise 'API Failure' 
    end
  end

  def get_usage(device)
    url = URI("https://api.flumewater.com/users/#{@user_id}/devices/#{device}/query")
    pp url

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request["Content-type"] = 'application/json'
    request["Accept"] = 'application/json'
    request['Authorization'] = "Bearer #{@access_token}"

    pp request['Authorization']

    request.body = JSON.generate({
                                   queries: [
                                     {
                                       bucket: 'MIN',
                                       since_datetime: '2022-04-11 13:00:00',
                                       until_datetime: '2022-04-11 13:20:00',
                                       request_id: '1234'
                                     }
                                   ]
                                 })

    pp request.body

    response = http.request(request)
    puts response.read_body

    data = JSON.parse response.read_body, symbolize_names: true

    if data[:success]
      data
    else
      raise 'API Failure' 
    end
  end

  def _get_user_from_token
    decoded = JWT.decode @access_token, nil, false
    if decoded[0]["type"] == "USER" && decoded[0]["user_id"]
      @user_id = decoded[0]["user_id"]
    end
  end

  def _get_expiration_from_token
    decoded = JWT.decode @access_token, nil, false
    if decoded[0]["type"] == "USER" && decoded[0]["exp"]
      @access_expires_at = decoded[0]["exp"]
    end
  end
end
