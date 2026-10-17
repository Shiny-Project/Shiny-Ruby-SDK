require 'minitest/autorun'
require 'minitest/mock'
require_relative '../lib/shiny-sdk'

class ShinySDKTest < Minitest::Test
  Response = Struct.new(:code, :body)

  class HTTPStub
    attr_accessor :use_ssl
    attr_reader :requests

    def initialize(response)
      @response = response
      @requests = []
    end

    def start
      yield self
    end

    def request(request)
      @requests << request
      @response
    end
  end

  def setup
    @client = Shiny.new('test-api-key', 'test-secret', 'https://example.invalid')
    @response = Response.new('200', '{"ok":true}')
  end

  # Captured from the original add method at e2d6c32, before these fixes.
  # In particular, event JSON and form bodies are byte exact.
  JSON.parse(File.read(File.join(__dir__, 'fixtures', 'add_compatibility.json'), encoding: 'UTF-8')).each do |example|
    define_method("test_add_compatibility_#{example.fetch('name')}") do
      client = Shiny.new(*example.fetch('client_args'))
      args = example.fetch('args')
      if example['bad_data']
        bad_data = Object.new
        def bad_data.to_json(*)
          raise ArgumentError, 'cannot serialize'
        end
        args[2] = bad_data
      end
      response = Response.new(*example.fetch('response'))
      captured = nil
      post = lambda do |uri, payload|
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(payload)
        captured = { 'url' => uri.to_s, 'payload' => payload, 'body' => request.body }
        response
      end
      Net::HTTP.stub(:post_form, post) do
        invoke = lambda do
          if example.key?('channel')
            client.add(*args, channel: example['channel'])
          else
            client.add(*args)
          end
        end
        if example.key?('error')
          error = assert_raises(Object.const_get(example['error']['class']), &invoke)
          assert_equal example['error']['message'], error.message if example['error'].key?('message')
        else
          assert_equal example.fetch('result'), invoke.call
        end
      end
      assert_equal example.fetch('request'), captured unless example['request'].nil?
      assert_nil captured if example['request'].nil?
    end
  end

  def test_sign_hashes_sorted_values_without_mutating_payload
    payload = { status: 'done', jobId: 'job-1' }
    original = payload.dup
    assert_equal Digest::SHA1.hexdigest('test-api-keytest-secretjob-1done'), @client.sign(payload)
    assert_equal original, payload
    assert_equal @client.sign(payload), @client.sign(payload.to_a.reverse.to_h)
    refute_includes @client.sign(payload), 'test-secret'
  end

  def test_sign_without_parameters
    assert_equal Digest::SHA1.hexdigest('test-api-keytest-secret'), @client.sign
  end

  def test_add_many_generates_hash_and_normalizes_level
    events = [{ spiderName: 'test', level: '2', data: { b: 2, a: 1 } }]
    capture_post(-> { @client.add_many(events) }) do |uri, payload, result|
      assert_equal 'https://example.invalid/Data/add', uri.to_s
      assert_equal({ 'ok' => true }, result)
      event = JSON.parse(payload.fetch(:event)).first
      assert_equal 2, event.fetch('level')
      assert_equal({ 'b' => 2, 'a' => 1 }, event.fetch('data'))
      assert_equal Digest::MD5.hexdigest([['a', 1], ['b', 2]].to_json), event.fetch('hash')
      assert_equal Digest::SHA1.hexdigest('test-api-keytest-secret' + payload[:event]), payload[:sign]
      assert_equal 'test-api-key', payload[:api_key]
      refute_includes payload[:sign], 'test-secret'
    end
  end

  def test_add_many_uses_explicit_and_embedded_hashes
    events = [
      { spiderName: 'first', level: '1', data: { hash: 'ignored', message: 'one' }, hash: 'explicit' },
      { spiderName: 'second', level: '2', data: { hash: 'embedded', message: 'two' } }
    ]
    capture_post(-> { @client.add_many(events) }) do |_uri, payload, _result|
      first, second = JSON.parse(payload.fetch(:event))
      assert_equal 'explicit', first.fetch('hash')
      assert_equal 1, first.fetch('level')
      assert_equal 'ignored', first.fetch('data').fetch('hash')
      assert_equal 'embedded', second.fetch('hash')
      assert_equal 2, second.fetch('level')
      assert_equal({ 'message' => 'two' }, second.fetch('data'))
    end
  end

  def test_add_many_rejects_missing_data_before_sending
    [{ spiderName: 'test', level: 1 }, { spiderName: 'test', level: 1, data: nil }].each do |event|
      Net::HTTP.stub(:post_form, ->(*) { flunk 'must not send invalid events' }) do
        error = assert_raises(ShinyError) { @client.add_many([event]) }
        assert_equal 'Missing parameters.', error.message
      end
    end
  end

  def test_add_many_accepts_empty_data
    events = [{ spiderName: 'test', level: 1, data: {} }]
    capture_post(-> { @client.add_many(events) }) do |_uri, payload, _result|
      assert_equal({}, JSON.parse(payload.fetch(:event)).first.fetch('data'))
    end
  end

  def test_get_jobs_initializes_https_and_encodes_credentials
    client = Shiny.new('key+&=? 空', 'test-secret', 'https://example.invalid:8443/api')
    http = HTTPStub.new(Response.new('200', '[{"jobId":"job-1"}]'))
    factory = lambda do |host, port|
      assert_equal 'example.invalid', host
      assert_equal 8443, port
      http
    end
    Net::HTTP.stub(:new, factory) do
      assert_equal [{ 'jobId' => 'job-1' }], client.get_jobs
    end
    assert_equal true, http.use_ssl
    request = http.requests.fetch(0)
    assert_equal 'GET', request.method
    uri = URI.parse(request.path)
    assert_equal '/api/Job/query', uri.path
    assert_equal({ 'api_key' => 'key+&=? 空', 'sign' => Digest::SHA1.hexdigest('key+&=? 空test-secret') }, URI.decode_www_form(uri.query).to_h)
    refute_includes request.path, 'test-secret'
  end

  def test_get_jobs_supports_http
    client = Shiny.new('key', 'secret', 'http://example.invalid:8080')
    http = HTTPStub.new(@response)
    factory = lambda do |host, port|
      assert_equal ['example.invalid', 8080], [host, port]
      http
    end
    Net::HTTP.stub(:new, factory) do
      assert_equal({ 'ok' => true }, client.get_jobs)
    end
    refute http.use_ssl
  end

  def test_get_jobs_reports_http_errors
    http = HTTPStub.new(Response.new('503', 'unavailable'))
    Net::HTTP.stub(:new, http) do
      error = assert_raises(ShinyError) { @client.get_jobs }
      assert_equal 'Network error: 503', error.message
    end
  end

  def test_report_sends_authentication_and_returns_response
    capture_post(-> { @client.report('job-1', 'done') }) do |uri, payload, result|
      assert_equal 'https://example.invalid/Job/report', uri.to_s
      assert_equal({ 'ok' => true }, result)
      assert_equal 'job-1', payload.fetch(:jobId)
      assert_equal 'done', payload.fetch(:status)
      assert_equal 'test-api-key', payload.fetch(:api_key)
      assert_equal Digest::SHA1.hexdigest('test-api-keytest-secretjob-1done'), payload.fetch(:sign)
      refute_includes payload[:sign], 'test-secret'
    end
  end

  def test_post_methods_preserve_api_errors
    @response = Response.new('403', '{"error":{"info":"invalid signature","code":401}}')
    assert_post_errors 'Shiny error: invalid signature code=401'
  end

  def test_post_methods_preserve_non_json_http_errors
    @response = Response.new('502', '<html>Bad Gateway</html>')
    assert_post_errors 'Network error: 502'
  end

  private

  def capture_post(operation)
    captured = nil
    Net::HTTP.stub(:post_form, ->(uri, payload) { captured = [uri, payload]; @response }) do
      result = operation.call
      refute_nil captured
      yield(*captured, result)
    end
  end

  def assert_post_errors(message)
    operations = [
      -> { @client.add('test', 1, {}) },
      -> { @client.add_many([{ spiderName: 'test', level: 1, data: {}, hash: 'fixed' }]) },
      -> { @client.report('job-1', 'done') }
    ]
    Net::HTTP.stub(:post_form, @response) do
      operations.each do |operation|
        error = assert_raises(ShinyError, &operation)
        assert_equal message, error.message
      end
    end
  end
end
