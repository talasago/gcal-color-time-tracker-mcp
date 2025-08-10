require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'ostruct'
require 'cgi'
require 'singleton'
require_relative 'token_manager'

module CalendarColorMCP
  class GoogleCalendarAuthManager
    include Singleton
    SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY
    REDIRECT_URI = 'urn:ietf:wg:oauth:2.0:oob'  # OOB flow for CLI

    def initialize
      @token_manager = TokenManager.instance
    end

    def get_auth_url
      client_id = ENV['GOOGLE_CLIENT_ID']
      client_secret = ENV['GOOGLE_CLIENT_SECRET']

      # 必要な環境変数のチェック
      if client_id.nil? || client_id.empty?
        raise "GOOGLE_CLIENT_ID が設定されていません。.env ファイルを確認してください。"
      end

      if client_secret.nil? || client_secret.empty?
        raise "GOOGLE_CLIENT_SECRET が設定されていません。.env ファイルを確認してください。"
      end

      # OAuth2の認証URLを直接構築
      params = {
        'client_id' => client_id,
        'redirect_uri' => REDIRECT_URI,
        'scope' => SCOPE,
        'response_type' => 'code',
        'access_type' => 'offline',
        'prompt' => 'consent'
      }

      query_string = params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      "https://accounts.google.com/o/oauth2/auth?#{query_string}"
    end

    def get_auth_instructions
      [
          "1. 上記URLにアクセスしてください",
          "2. Googleアカウントでログインし、権限を許可してください",
          "3. 表示された認証コードをコピーしてください",
          "4. CompleteAuthTool を使用して認証コードを送信してください:",
          "   - ツール名: CompleteAuthTool",
          "   - パラメータ: auth_code = <認証コード>",
          "",
          "認証が完了すると、カレンダー分析が利用可能になります。"
      ].join("\n")
    end

    def complete_auth(auth_code)
      client_id = Google::Auth::ClientId.new(
        ENV['GOOGLE_CLIENT_ID'],
        ENV['GOOGLE_CLIENT_SECRET']
      )

      authorizer = Google::Auth::WebUserAuthorizer.new(
        client_id,
        [SCOPE],
        Google::Auth::Stores::FileTokenStore.new(file: '/dev/null'),
        REDIRECT_URI
      )

      # user_idは必要ないので、固定値を使用
      credentials = authorizer.get_credentials_from_code(
        user_id: 'default',
        code: auth_code,
        scope: [SCOPE]
      )

      @token_manager.save_credentials(credentials)

      {
        success: true,
        message: "認証が完了しました"
      }
    rescue => e
      {
        success: false,
        error: "認証に失敗しました: #{e.message}"
      }
    end

    def authenticated?
      @token_manager.authenticated?
    end

    def clear_auth
      @token_manager.clear_credentials
    end
  end
end
