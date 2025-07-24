require 'google/apis/calendar_v3'
require 'googleauth'

module CalendarColorMCP
  class AuthManager
    SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY
    REDIRECT_URI = 'urn:ietf:wg:oauth:2.0:oob'  # OOB flow for CLI

    def initialize
      @user_manager = UserManager.new
    end

    def get_auth_url(user_id)
      client_id = Google::Auth::ClientId.new(
        ENV['GOOGLE_CLIENT_ID'],
        ENV['GOOGLE_CLIENT_SECRET']
      )
      
      authorizer = Google::Auth::WebUserAuthorizer.new(
        client_id, 
        [SCOPE], 
        Google::Auth::Stores::FileTokenStore.new(file: '/dev/null'),  # 一時的
        REDIRECT_URI
      )
      
      url = authorizer.get_authorization_url(login_hint: user_id)
      
      # 手動認証の説明を含むURL
      {
        url: url,
        instructions: [
          "1. 上記URLにアクセスしてください",
          "2. Googleアカウントでログインし、権限を許可してください", 
          "3. 表示された認証コードをコピーしてください",
          "4. 認証コード: [ここに認証コードを貼り付けて、以下のコマンドを実行]",
          "   echo 'AUTH_CODE=<認証コード>' >> .env",
          "   # その後、再度分析を実行してください"
        ].join("\n")
      }
    end

    def complete_auth(user_id, auth_code)
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
      
      credentials = authorizer.get_credentials_from_code(
        user_id: user_id,
        code: auth_code,
        scope: [SCOPE]
      )
      
      @user_manager.save_credentials(user_id, credentials)
      
      {
        success: true,
        message: "認証が完了しました",
        user_id: user_id
      }
    rescue => e
      {
        success: false,
        error: "認証に失敗しました: #{e.message}"
      }
    end
  end
end