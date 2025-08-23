require 'rspec'
require 'rspec-parameterized'
require_relative '../lib/calendar_color_mcp/logger_manager'
require_relative '../lib/calendar_color_mcp/server'

RSpec.configure do |config|
  # テスト環境でのログ抑制用環境変数を設定
  config.before(:suite) do
    ENV['RSPEC_RUNNING'] = 'true'
    # テスト用のデフォルト環境変数を設定（.envファイルなしでも動作）
    ENV['GOOGLE_CLIENT_ID'] ||= 'test-client-id-default'
    ENV['GOOGLE_CLIENT_SECRET'] ||= 'test-client-secret-default'
  end
  
  config.after(:suite) do
    ENV.delete('RSPEC_RUNNING')
  end
  
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
