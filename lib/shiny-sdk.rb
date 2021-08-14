# Shiny Ruby SDK
require 'json'
require 'digest/md5'
require 'digest/sha1'
require 'net/http'
require 'uri'

class ShinyError < StandardError
  def initialize(message)
    super
  end
end

class Shiny
  def initialize(api_key, api_secret_key, api_host='https://shiny.kotori.moe')
    @API_KEY = api_key.freeze
    @API_SECRET_KEY = api_secret_key.freeze
    @API_HOST = api_host.freeze
  end

  # API 请求签名
  def sign(payload={})
    data = @API_KEY + @API_SECRET_KEY
    Hash[payload.sort].keys.each do |key|
      data += payload[key].to_s
    end
    data
  end


  # 计算md5
  def md5(text)
    Digest::MD5.hexdigest(text)
  end

  # 计算sha1
  def sha1(text)
    Digest::SHA1.hexdigest(text)
  end

  # 添加数据项
  def add(spider_name, level, data=nil, hash=false, channel: nil)
    if data.nil?
      data = {}
    end

    url = @API_HOST + '/Data/add'

    payload = {'api_key' => @API_KEY}

    event = {"level": level.to_i, "spiderName": spider_name} 

    # 如果没有手动指定Hash，将会把data做一次md5生成hash
    begin
      if hash
        event['hash'] = hash
      else
        event['hash'] = md5(data.to_json)
      end
    rescue
      raise ShinyError.new('Fail to generate hash.')
    end

    event['data'] = data

    event['channel'] = channel unless channel.nil?

    payload['sign'] = sha1(@API_KEY + @API_SECRET_KEY + event.to_json)

    payload["event"] = event.to_json

    response = Net::HTTP.post_form(URI.parse(url), payload)
    if response.code != '200'
      begin
        error = JSON.parse(response.body)
      rescue
        raise ShinyError.new("Network error: #{response.code}")
      end

      raise ShinyError.new("Shiny error: #{error['error']['info']} code=#{error['error']['code']}")
    else
      JSON.parse(response.body)
    end
  end

  # 添加多个事件
  def add_many(events)
    payload = {}
    url = @API_HOST + "/Data/add"
    events.each do |event|
      if event[:hash].nil?
        if event[:data].nil?
          if event[:data][:hash]
            event[:hash] = event[:data][:hash]
            event[:data].delete(:hash)
          else
            event[:hash] = md5(Hash[event[:data]].sort.to_json)
          end
        else
          raise ShinyError.new("Missing parameters.")
        end
        event[:level] = event[:level].to_i
      end
    end
    payload[:event] = events.to_json

    payload_sign = sign(payload)
      
    payload[:sign] = payload_sign
    payload[:api_key] = @API_KEY

    response = Net::HTTP.post_form(URI.parse(url), payload)
    if response.code != '200'
      begin
        error = JSON.parse(response.body)
      rescue
        raise ShinyError.new("Network error: #{response.code}")
      end
      
      raise ShinyError.new("Shiny error: #{error['error']['info']} code=#{error['error']['code']}")
    else
      JSON.parse(response.body)
    end
  end

  # 获取最新项目
  def recent(page=1)
    url = @API_HOST + "/Data/recent?page=#{page}"
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    response = http.start {|http| 
      http.request Net::HTTP::Get.new(uri.request_uri)
    }
    if response.code != '200'
      raise ShinyError.new("Network error: #{response.code}")
    else
      return JSON.parse(response.body)
    end
  end

  def get_jobs
    url = @API_HOST + "/Job/query?api_key=#{@API_KEY}&sign=#{sign}"
    uri = URI.parse(url)
    response = http.start {|http| 
      http.request Net::HTTP::Get.new(uri.request_uri)
    }
    if response.code != '200'
      raise ShinyError.new("Network error: #{response.code}")
    else
      return JSON.parse(response.body)
    end
  end

  def report(job_id, status)
    url = @API_HOST + "/Job/report"
    uri = URI.parse(url)
    payload = {
      "jobId": job_id,
      "status": status
    }
    payload_sign = sign(payload)
    response = Net::HTTP.post_form(URI.parse(url), payload)
    if response.code != '200'
      begin
        error = JSON.parse(response.body)
      rescue
        raise ShinyError.new("Network error: #{response.code}")
      end
      
      raise ShinyError.new("Shiny error: #{error['error']['info']} code=#{error['error']['code']}")
    else
      JSON.parse(response.body)
    end
  end
end