# Google Calendar 色別時間集計MCPサーバー（Rails API版）

## 要件

Googleカレンダーの色別時間集計を行うMCPサーバーをRails APIモードで実装してください。

### 機能要件

1. **色別時間集計**: 指定期間のカレンダーイベントを色毎に時間集計
1. **自然言語クエリ**: 「7月1日から7月7日まで、時間を集計して」といった形式に対応
1. **複数ユーザー対応**: データベースを使わずにローカルファイルで管理
1. **簡単な認証フロー**: 他のユーザーはGoogle Cloud Consoleを触らない

### 技術要件

- **Rails APIモード**でRESTful APIサーバーを構築
- **Google Calendar API**を使用（google-api-client gem）
- **OAuth 2.0**による認証
- **ファイルベース**でのトークン管理（データベース不要）
- **ローカルホスト**での運用

### 運用要件

- **管理者**: Google Cloud Console設定は一度だけ
- **他のユーザー**: 認証URLアクセスのみで使用開始
- **再認証頻度**: 可能な限り少なく（リフレッシュトークン活用）

## 実装内容

### 1. プロジェクト構成

```
calendar-mcp-server/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── auth_controller.rb
│   │   └── analysis_controller.rb
│   ├── services/
│   │   ├── google_calendar_service.rb
│   │   ├── time_analysis_service.rb
│   │   └── user_token_service.rb
│   └── models/
│       └── concerns/
├── config/
│   ├── routes.rb
│   ├── application.rb
│   └── environments/
├── lib/
│   └── tasks/
│       └── analysis.rake
├── Gemfile
├── .env.example
├── user_tokens/
└── README.md
```

### 2. Gemfile

```ruby
source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.0'

gem 'rails', '~> 7.0.0', '>= 7.0.4'
gem 'google-api-client'
gem 'dotenv-rails'
gem 'puma', '~> 5.0'
gem 'bootsnap', '>= 1.4.4', require: false
gem 'rack-cors'

group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'pry-rails'
end

group :development do
  gem 'listen', '~> 3.3'
  gem 'spring'
end
```

### 3. Rails設定

```ruby
# config/application.rb
require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'action_cable/railtie'
require 'rails/test_unit/railtie'

Bundler.require(*Rails.groups)

module CalendarMcpServer
  class Application < Rails::Application
    config.load_defaults 7.0
    config.api_only = true
    
    # CORS設定
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head]
      end
    end
  end
end
```

### 4. ルーティング

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # 認証関連
      get 'auth/:user_id', to: 'auth#authorize'
      get 'auth/callback', to: 'auth#callback'
      get 'status/:user_id', to: 'auth#status'
      
      # 分析関連
      post 'analysis/:user_id', to: 'analysis#create'
      get 'analysis/:user_id/:analysis_id', to: 'analysis#show'
    end
  end
  
  # 認証用のシンプルなルート
  get 'auth/:user_id', to: 'auth#authorize'
  get 'auth/callback', to: 'auth#callback'
end
```

### 5. コントローラー

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  rescue_from StandardError, with: :handle_error
  
  private
  
  def handle_error(error)
    Rails.logger.error "Error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    case error
    when Google::Apis::AuthorizationError
      render json: { 
        error: 'authorization_required',
        message: '認証が必要です',
        auth_url: "#{request.base_url}/auth/#{params[:user_id]}"
      }, status: :unauthorized
    when Google::Apis::ClientError
      render json: { 
        error: 'client_error',
        message: error.message 
      }, status: :bad_request
    else
      render json: { 
        error: 'internal_error',
        message: '内部エラーが発生しました' 
      }, status: :internal_server_error
    end
  end
end
```

```ruby
# app/controllers/auth_controller.rb
class AuthController < ApplicationController
  def authorize
    auth_url = GoogleCalendarService.new(params[:user_id]).authorization_url
    redirect_to auth_url, allow_other_host: true
  end

  def callback
    user_id = session[:user_id]
    return render json: { error: 'Invalid session' }, status: :bad_request unless user_id
    
    GoogleCalendarService.new(user_id).handle_callback(params[:code])
    render json: { 
      message: '認証が完了しました',
      user_id: user_id,
      status: 'authenticated'
    }
  end

  def status
    service = GoogleCalendarService.new(params[:user_id])
    authenticated = service.authenticated?
    
    render json: {
      user_id: params[:user_id],
      authenticated: authenticated,
      auth_url: authenticated ? nil : "#{request.base_url}/auth/#{params[:user_id]}"
    }
  end
end
```

```ruby
# app/controllers/analysis_controller.rb
class AnalysisController < ApplicationController
  def create
    start_date = Date.parse(params[:start_date])
    end_date = Date.parse(params[:end_date])
    
    service = TimeAnalysisService.new(params[:user_id])
    result = service.analyze_period(start_date, end_date)
    
    render json: {
      user_id: params[:user_id],
      period: {
        start_date: start_date,
        end_date: end_date
      },
      analysis: result
    }
  rescue Date::Error
    render json: { error: '日付形式が正しくありません (YYYY-MM-DD)' }, status: :bad_request
  end
end
```

### 6. サービスクラス

```ruby
# app/services/google_calendar_service.rb
class GoogleCalendarService
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY
  
  def initialize(user_id)
    @user_id = user_id
    @token_service = UserTokenService.new
    @client = Google::Apis::CalendarV3::CalendarService.new
  end

  def authorization_url
    client_id = Google::Auth::ClientId.new(
      ENV['GOOGLE_CLIENT_ID'],
      ENV['GOOGLE_CLIENT_SECRET']
    )
    
    token_store = Google::Auth::Stores::FileTokenStore.new(
      file: token_file_path
    )
    
    authorizer = Google::Auth::WebUserAuthorizer.new(
      client_id, [SCOPE], token_store, ENV['GOOGLE_REDIRECT_URI']
    )
    
    authorizer.get_authorization_url(login_hint: @user_id, state: @user_id)
  end

  def handle_callback(code)
    # OAuth認証完了処理
    client_id = Google::Auth::ClientId.new(
      ENV['GOOGLE_CLIENT_ID'],
      ENV['GOOGLE_CLIENT_SECRET']
    )
    
    token_store = Google::Auth::Stores::FileTokenStore.new(
      file: token_file_path
    )
    
    authorizer = Google::Auth::WebUserAuthorizer.new(
      client_id, [SCOPE], token_store, ENV['GOOGLE_REDIRECT_URI']
    )
    
    authorizer.get_credentials_from_code(
      user_id: @user_id,
      code: code,
      scope: [SCOPE]
    )
  end

  def authenticated?
    @token_service.token_exists?(@user_id)
  end

  def get_events(start_date, end_date)
    authorize_client
    
    @client.list_events(
      'primary',
      time_min: start_date.beginning_of_day.rfc3339,
      time_max: end_date.end_of_day.rfc3339,
      single_events: true,
      order_by: 'startTime'
    ).items
  end

  private

  def authorize_client
    credentials = @token_service.load_credentials(@user_id)
    @client.authorization = credentials
  end

  def token_file_path
    Rails.root.join('user_tokens', "#{@token_service.hash_user_id(@user_id)}.json")
  end
end
```

```ruby
# app/services/time_analysis_service.rb
class TimeAnalysisService
  COLOR_NAMES = {
    1 => '薄紫', 2 => '緑', 3 => '紫', 4 => '赤', 5 => '黄',
    6 => 'オレンジ', 7 => '水色', 8 => '灰色', 9 => '青', 
    10 => '濃い緑', 11 => '濃い赤'
  }.freeze

  def initialize(user_id)
    @user_id = user_id
    @calendar_service = GoogleCalendarService.new(user_id)
  end

  def analyze_period(start_date, end_date)
    events = @calendar_service.get_events(start_date, end_date)
    color_analysis = analyze_by_color(events)
    
    {
      total_events: events.count,
      period_days: (end_date - start_date).to_i + 1,
      color_breakdown: color_analysis,
      summary: generate_summary(color_analysis)
    }
  end

  private

  def analyze_by_color(events)
    color_data = {}
    
    events.each do |event|
      color_id = event.color_id&.to_i || 9  # デフォルトは青
      color_name = COLOR_NAMES[color_id] || "不明 (#{color_id})"
      
      color_data[color_name] ||= {
        total_hours: 0.0,
        event_count: 0,
        events: []
      }
      
      duration = calculate_event_duration(event)
      color_data[color_name][:total_hours] += duration
      color_data[color_name][:event_count] += 1
      color_data[color_name][:events] << {
        title: event.summary,
        duration: duration,
        start_time: event.start&.date_time || event.start&.date
      }
    end
    
    color_data
  end

  def calculate_event_duration(event)
    if event.start.date_time && event.end.date_time
      # 通常のイベント
      ((event.end.date_time - event.start.date_time) / 1.hour).round(2)
    elsif event.start.date && event.end.date
      # 終日イベント
      start_date = Date.parse(event.start.date)
      end_date = Date.parse(event.end.date)
      (end_date - start_date).to_i * 24.0
    else
      0.0
    end
  end

  def generate_summary(color_analysis)
    total_hours = color_analysis.values.sum { |data| data[:total_hours] }
    top_color = color_analysis.max_by { |_, data| data[:total_hours] }
    
    {
      total_hours: total_hours.round(2),
      most_used_color: top_color ? {
        name: top_color[0],
        hours: top_color[1][:total_hours].round(2),
        percentage: ((top_color[1][:total_hours] / total_hours) * 100).round(1)
      } : nil
    }
  end
end
```

```ruby
# app/services/user_token_service.rb
class UserTokenService
  def initialize
    @tokens_dir = Rails.root.join('user_tokens')
    FileUtils.mkdir_p(@tokens_dir) unless Dir.exist?(@tokens_dir)
  end

  def hash_user_id(user_id)
    Digest::SHA256.hexdigest(user_id.to_s)
  end

  def token_file_path(user_id)
    @tokens_dir.join("#{hash_user_id(user_id)}.json")
  end

  def token_exists?(user_id)
    File.exist?(token_file_path(user_id))
  end

  def save_token(user_id, token_data)
    File.write(token_file_path(user_id), token_data.to_json)
  end

  def load_token(user_id)
    return nil unless token_exists?(user_id)
    
    JSON.parse(File.read(token_file_path(user_id)))
  end

  def load_credentials(user_id)
    token_data = load_token(user_id)
    return nil unless token_data
    
    # Google認証情報を復元
    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      refresh_token: token_data['refresh_token'],
      access_token: token_data['access_token']
    )
    
    credentials.refresh! if credentials.expired?
    credentials
  end
end
```

### 7. Rakeタスク

```ruby
# lib/tasks/analysis.rake
namespace :analysis do
  desc "カレンダー分析を実行"
  task :run, [:user_id, :start_date, :end_date] => :environment do |task, args|
    user_id = args[:user_id]
    start_date = Date.parse(args[:start_date])
    end_date = Date.parse(args[:end_date])
    
    service = TimeAnalysisService.new(user_id)
    result = service.analyze_period(start_date, end_date)
    
    puts "📊 #{user_id} の色別時間集計結果:"
    puts "=" * 50
    puts
    
    result[:color_breakdown].each do |color_name, data|
      hours = data[:total_hours]
      minutes = ((hours % 1) * 60).round
      
      puts "🎨 #{color_name}:"
      puts "  時間: #{hours.to_i}時間#{minutes}分"
      puts "  イベント数: #{data[:event_count]}件"
      puts "  主なイベント: #{data[:events].first(3).map { |e| e[:title] }.join(', ')}"
      puts
    end
    
    puts "📈 サマリー:"
    puts "  総時間: #{result[:summary][:total_hours]}時間"
    puts "  総イベント数: #{result[:total_events]}件"
    if result[:summary][:most_used_color]
      most_used = result[:summary][:most_used_color]
      puts "  最も使用された色: #{most_used[:name]} (#{most_used[:hours]}時間、#{most_used[:percentage]}%)"
    end
  end
end
```

### 8. 環境設定

```ruby
# config/environments/development.rb
Rails.application.configure do
  config.cache_classes = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.active_support.deprecation = :log
  config.log_level = :debug
  
  # CORS設定
  config.hosts << "localhost"
  config.hosts << "127.0.0.1"
end
```

### 9. 使用方法

#### サーバー起動
```bash
# 依存関係インストール
bundle install

# 環境変数設定
cp .env.example .env
# .envファイルを編集

# サーバー起動
rails server -p 3000
```

#### API使用例
```bash
# 認証状態確認
curl http://localhost:3000/api/v1/status/tanaka

# 認証開始（ブラウザでアクセス）
http://localhost:3000/auth/tanaka

# 分析実行
curl -X POST http://localhost:3000/api/v1/analysis/tanaka \
  -H "Content-Type: application/json" \
  -d '{"start_date": "2024-07-01", "end_date": "2024-07-07"}'
```

#### CLIでの分析実行
```bash
bundle exec rake analysis:run[tanaka,2024-07-01,2024-07-07]
```

### 10. テスト

```ruby
# spec/services/time_analysis_service_spec.rb
require 'rails_helper'

RSpec.describe TimeAnalysisService do
  let(:user_id) { 'test_user' }
  let(:service) { described_class.new(user_id) }
  
  describe '#analyze_period' do
    it 'returns color analysis for given period' do
      # テストの実装
    end
  end
end
```

## 起動・運用方法

### 開発環境
```bash
# 初期設定
rails new calendar-mcp-server --api
cd calendar-mcp-server

# 依存関係追加
bundle add google-api-client dotenv-rails rack-cors

# サーバー起動
rails server

# 分析実行
bundle exec rake analysis:run[user_id,2024-07-01,2024-07-07]
```

### 本番環境
```bash
# 本番用設定
RAILS_ENV=production rails server -p 3000
```

## Rails APIモードの利点

1. **構造化されたコード**: MVC + サービス層で整理
2. **豊富なヘルパー**: ActiveSupportの便利機能
3. **テスト統合**: RSpec等のテストフレームワーク
4. **環境管理**: development/production環境の分離
5. **拡張性**: 将来的な機能追加が容易
6. **Rails慣習**: Railsの標準的な構成

完全に動作するRails API実装を作成してください。
