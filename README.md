# Shiny Ruby SDK
Shiny 的 Ruby SDK，基于 Python 版构建。

## 安装
```bash
gem install shiny-sdk
```

## 使用
```ruby
require 'shiny-sdk'

shiny = Shiny.new('apikey', 'api_secret_key', 'api_host') # apikey 和 api_secret_key 必须填写，api_host 不填写会使用默认值。

# 获取最新的消息
shiny.recent(page) # page 选填，不填写默认为 1。

# 添加数据
shiny.add(spider_name:String, level:Integer, data:Hash, hash:String)
# 其中前三项为必填，hash为选填。
# 不填写hash 默认把data MD5 一次做hash。
```
