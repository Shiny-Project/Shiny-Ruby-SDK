require 'json'
require 'net/http'
require 'digest/md5'
require 'digest/sha1'
require 'rest-client'

class ShinyError < StandardError
  def initialize(message)
    super
  end
end

class Shiny
  def initialize(api_key, api_secret_key, api_host)
    @API_KEY = api_key
    @API_SECRET_KEY = api_secret_key
    @API_HOST = api_host
  end

  def add(spider_name, level, data=nil, hash=false)
    # 添加数据项
    if data.nil?
      data = {}
    end

    url = @API_HOST + '/Data/add'

    payload = {'api_key' => @API_KEY}

    event = {"level": level, "spiderName": spider_name} 

    # 如果没有手动指定Hash，将会把data做一次md5生成hash
    begin
      if hash
        event['hash'] = hash
      else
        event['hash'] = Digest::MD5.hexdigest(data.to_json)
      end
    rescue
      raise ShinyError.new('Fail to generate hash.')
    end

    event['data'] = data  

    payload['sign'] = Digest::SHA1.hexdigest(@API_KEY + @API_SECRET_KEY + event.to_json)

    payload["event"] = event.to_json

    begin
      response = RestClient.post(url, payload)
      return JSON.parser(response.body)
    rescue => e
      raise ShinyError.new('Network error:' + e.to_s)
    end
  end

  def recent
    # 获取最新项目
    url = @API_HOST + '/Data/recent'
    begin
      response = RestClient.get(url)
      return JSON.parse(response.body)
    rescue => e
      raise ShinyError.new('Network error:' + e.to_s)
    end
  end
end