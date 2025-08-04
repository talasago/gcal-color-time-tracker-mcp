require 'json'
require 'fileutils'
require 'googleauth'

module CalendarColorMCP
  class TokenManager
    TOKEN_FILE = 'token.json'

    def initialize
      project_root = File.expand_path('../../..', __FILE__)
      @token_file_path = File.join(project_root, TOKEN_FILE)

      if ENV['DEBUG'] == 'true'
        STDERR.puts "デバッグ: TokenManager初期化"
        STDERR.puts "  現在のディレクトリ: #{Dir.pwd}"
        STDERR.puts "  プロジェクトルート: #{project_root}"
        STDERR.puts "  トークンファイルパス: #{@token_file_path}"
        STDERR.puts "  ディレクトリの書き込み権限: #{File.writable?(project_root)}"
        STDERR.puts "  トークンファイル存在: #{File.exist?(@token_file_path)}"
      end
    end

    def authenticated?
      File.exist?(@token_file_path) && valid_token?
    end

    def save_credentials(credentials)
      token_data = {
        access_token: credentials.access_token,
        refresh_token: credentials.refresh_token,
        expires_at: credentials.expires_at&.to_i,
        saved_at: Time.now.to_i
      }

      if ENV['DEBUG'] == 'true'
        STDERR.puts "デバッグ: トークン保存を開始"
        STDERR.puts "  現在のディレクトリ: #{Dir.pwd}"
        STDERR.puts "  トークンファイルパス: #{@token_file_path}"
        STDERR.puts "  ディレクトリの書き込み権限: #{File.writable?(File.dirname(@token_file_path))}"
      end

      File.write(@token_file_path, token_data.to_json)
      STDERR.puts "デバッグ: トークンファイルを保存しました" if ENV['DEBUG'] == 'true'
    rescue Errno::EACCES => e
      error_msg = "トークンファイルの書き込み権限エラー: #{@token_file_path}\n" \
                  "現在のディレクトリ: #{Dir.pwd}\n" \
                  "エラー詳細: #{e.message}"
      puts error_msg
      raise error_msg
    rescue => e
      error_msg = "トークンファイルの保存エラー: #{e.message}\n" \
                  "ファイルパス: #{@token_file_path}"
      puts error_msg
      raise error_msg
    end

    def load_credentials
      return nil unless File.exist?(@token_file_path)

      token_data = JSON.parse(File.read(@token_file_path))

      credentials = Google::Auth::UserRefreshCredentials.new(
        client_id: ENV['GOOGLE_CLIENT_ID'],
        client_secret: ENV['GOOGLE_CLIENT_SECRET'],
        refresh_token: token_data['refresh_token'],
        access_token: token_data['access_token']
      )

      if token_data['expires_at']
        credentials.expires_at = Time.at(token_data['expires_at'])
      end

      credentials
    rescue JSON::ParserError, KeyError => e
      puts "トークンファイルの読み込みエラー: #{e.message}"
      nil
    end

    def last_auth_time
      return nil unless File.exist?(@token_file_path)

      token_data = JSON.parse(File.read(@token_file_path))
      Time.at(token_data['saved_at']).strftime('%Y-%m-%d %H:%M:%S') if token_data['saved_at']
    rescue
      nil
    end

    def clear_credentials
      File.delete(@token_file_path) if File.exist?(@token_file_path)
    end

    private

    def valid_token?
      credentials = load_credentials
      return false unless credentials

      # 基本的な有効性チェック
      credentials.access_token && credentials.refresh_token
    rescue
      false
    end
  end
end
