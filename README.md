# Shiny Ruby SDK

## 安装
```bash
gem install shiny-sdk
```

## 使用
```ruby
require 'shiny-sdk'

shiny = Shiny.new('apikey', 'api_secret_key', 'api_host')

# 获取最新项目
shiny.recent

# 添加数据
shiny.add(spider_name, level, data, hash)
# 其中三项为必填，hash为选填。
# 不填写hash 默认把data MD5 一次做hash。
```
