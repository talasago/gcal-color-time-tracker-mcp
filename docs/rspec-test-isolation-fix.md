# RSpecテスト間の状態干渉問題と修正方法

## 問題の概要

`complete_auth_tool_spec.rb`のテストが個別実行時と全体実行時で異なるエラーメッセージを返し、テストが失敗していました。

### 症状
- **個別実行**: `invalid_grant` エラー（認証コードの問題）
- **全体実行**: `
` エラー（クライアント設定の問題）

## 根本原因

### ConfigurationServiceのSingletonキャッシュ問題

1. **ConfigurationService**は`Singleton`パターンで実装
2. 環境変数を`@google_client_id ||= ENV.fetch('GOOGLE_CLIENT_ID')`でインスタンス変数にキャッシュ
3. **テスト実行順序の影響**:
   - 全体実行時、先行するテスト（例：`configuration_service_spec.rb`）で環境変数が設定されConfigurationServiceが初期化
   - そのテスト終了後、環境変数は復元されるが**Singletonインスタンスは残存**
   - `complete_auth_tool_spec.rb`実行時、環境変数は未設定だがConfigurationServiceは古いキャッシュを保持
4. **結果**: Google API呼び出し時に`invalid_client`エラー（個別実行では`invalid_grant`）

## 修正方法（方法2: 局所修正）

`spec/interface_adapters/tool/complete_auth_tool_spec.rb`に以下の修正を実装:

### 1. 必要なrequireを追加

```ruby
require_relative '../../../lib/calendar_color_mcp/infrastructure/services/configuration_service'
```

### 2. 環境変数とSingletonの管理

```ruby
around do |example|
  # 環境変数を一時的に保存・復元
  original_client_id = ENV['GOOGLE_CLIENT_ID']
  original_client_secret = ENV['GOOGLE_CLIENT_SECRET']
  
  # ConfigurationServiceのSingletonインスタンスを事前にリセット
  Infrastructure::ConfigurationService.instance_variable_set(:@singleton__instance__, nil)
  
  # テスト用の環境変数を設定
  ENV['GOOGLE_CLIENT_ID'] = 'test_client_id'
  ENV['GOOGLE_CLIENT_SECRET'] = 'test_client_secret'

  example.run

  ENV['GOOGLE_CLIENT_ID'] = original_client_id
  ENV['GOOGLE_CLIENT_SECRET'] = original_client_secret
end

# ConfigurationServiceのSingletonインスタンスとキャッシュをテスト間でリセット
after do
  # Singletonインスタンスをリセット
  Infrastructure::ConfigurationService.instance_variable_set(:@singleton__instance__, nil)
  
  # インスタンスが存在する場合、キャッシュされた値もクリア
  if Infrastructure::ConfigurationService.instance_variable_get(:@singleton__instance__)
    instance = Infrastructure::ConfigurationService.instance_variable_get(:@singleton__instance__)
    instance.instance_variable_set(:@google_client_id, nil) if instance
    instance.instance_variable_set(:@google_client_secret, nil) if instance
  end
end
```

### 3. モック化による一貫したエラーレスポンス

```ruby
context 'when auth code is invalid' do
  include_context 'authenticated user'

  before do
    # モックでinvalid_grantエラーを発生させる
    allow(mock_oauth_service).to receive(:exchange_code_for_token)
      .and_raise(Infrastructure::ExternalServiceError, 
                "Authorization failed.  Server message:\n{\n  \"error\": \"invalid_grant\",\n  \"error_description\": \"Malformed auth code.\"\n}")
  end

  it 'handles invalid auth code' do
    # Call tool directly with mocked context
    response = InterfaceAdapters::CompleteAuthTool.call(
      auth_code: "invalid_code_123",
      server_context: server_context
    )

    content = JSON.parse(response.content[0][:text])
    expect(content['success']).to be false
    # Expected error patterns for invalid auth code - now consistent with mock
    puts "DEBUG: Error message content: #{content['error'].inspect}"
    expect(content['error']).to match(/認証エラー:.*invalid_grant/m)
  end
end
```

## 修正結果

- **個別実行**: ✅ 成功
- **全体実行**: ✅ 成功（0 failures, 22 pending）

## 代替解決方法（方法1: グローバル修正）

より根本的な解決として、`spec_helper.rb`にグローバルなSingletonリセット処理を追加することも可能:

```ruby
RSpec.configure do |config|
  config.after(:each) do
    # ConfigurationServiceのSingletonをグローバルにリセット
    Infrastructure::ConfigurationService.instance_variable_set(:@singleton__instance__, nil)
  end
end
```

## 学習ポイント

1. **Singletonパターンの注意点**: テスト間で状態が保持されるため、明示的なリセットが必要
2. **環境変数のテスト間干渉**: 先行するテストの環境変数設定が後続テストに影響する
3. **モック活用の重要性**: 外部APIに依存しない一貫したテスト環境の構築
4. **テスト実行順序への配慮**: 個別実行と全体実行で一貫した結果が得られるテスト設計

## 適用すべき他のテストファイル

同様の問題が発生する可能性がある他のテストファイル:
- `start_auth_tool_spec.rb`
- `check_auth_status_tool_spec.rb`
- その他ConfigurationServiceを使用するテスト

これらのファイルでも同様の環境変数管理とSingletonリセット処理の実装を検討。
