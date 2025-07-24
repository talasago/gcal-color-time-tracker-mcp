require 'json'
require 'digest'
require 'fileutils'

module CalendarColorMCP
  class UserManager
    def initialize
      @tokens_dir = File.join(Dir.pwd, 'user_tokens')
      FileUtils.mkdir_p(@tokens_dir) unless Dir.exist?(@tokens_dir)
    end

    def authenticated?(user_id)
      token_file = token_file_path(user_id)
      File.exist?(token_file) && valid_token?(user_id)
    end

    def save_credentials(user_id, credentials)
      token_data = {
        access_token: credentials.access_token,
        refresh_token: credentials.refresh_token,
        expires_at: credentials.expires_at&.to_i,
        saved_at: Time.now.to_i
      }
      
      File.write(token_file_path(user_id), token_data.to_json)
    end

    def load_credentials(user_id)
      token_file = token_file_path(user_id)
      return nil unless File.exist?(token_file)
      
      token_data = JSON.parse(File.read(token_file))
      
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

    def list_users
      Dir.glob(File.join(@tokens_dir, '*.json')).map do |file|
        basename = File.basename(file, '.json')
        # ハッシュ化されたユーザーIDから元のIDは復元できないため、
        # ファイル名をそのまま返す（実際の運用では別途管理が必要）
        basename
      end
    end

    def last_auth_time(user_id)
      token_file = token_file_path(user_id)
      return nil unless File.exist?(token_file)
      
      token_data = JSON.parse(File.read(token_file))
      Time.at(token_data['saved_at']).strftime('%Y-%m-%d %H:%M:%S') if token_data['saved_at']
    rescue
      nil
    end

    private

    def token_file_path(user_id)
      hashed_id = hash_user_id(user_id)
      File.join(@tokens_dir, "#{hashed_id}.json")
    end

    def hash_user_id(user_id)
      Digest::SHA256.hexdigest(user_id.to_s)
    end

    def valid_token?(user_id)
      credentials = load_credentials(user_id)
      return false unless credentials
      
      # 基本的な有効性チェック
      credentials.access_token && credentials.refresh_token
    rescue
      false
    end
  end
end