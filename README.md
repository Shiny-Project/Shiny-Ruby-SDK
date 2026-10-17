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

## 测试

```bash
bundle install
bundle exec ruby -Itest test/shiny_sdk_test.rb
```

测试使用本地模拟请求，不连接真实服务。`test/fixtures/add_compatibility.json` 保存了修复前 `add()` 的 17 组行为基准，用于逐字节比对请求 JSON、签名和表单编码，并检查返回值及异常类型；`ShinyError` 的错误信息也会比对。
