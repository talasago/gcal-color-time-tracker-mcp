require 'json'
require 'fileutils'
require 'googleauth'
require 'singleton'
require_relative 'loggable'

module CalendarColorMCP
  class TokenManager
    include Singleton
    include Loggable

    TOKEN_FILE = 'token.json'

    def initialize
      project_root = File.expand_path('../../..', __FILE__)
      @token_file_path = File.join(project_root, TOKEN_FILE)

      logger.debug "TokenManager初期化"
      logger.debug "  現在のディレクトリ: #{Dir.pwd}"
      logger.debug "  プロジェクトルート: #{project_root}"
      logger.debug "  トークンファイルパス: #{@token_file_path}"
      logger.debug "  ディレクトリの書き込み権限: #{File.writable?(project_root)}"
      logger.debug "  トークンファイル存在: #{File.exist?(@token_file_path)}"
    end

    def token_exist?
      !load_credentials.nil?
    rescue
      false
    end

    def save_credentials(credentials)
      token_data = {
        access_token: credentials.access_token,
        refresh_token: credentials.refresh_token,
        expires_at: credentials.expires_at&.to_i,
        saved_at: Time.now.to_i
      }

      logger.debug "トークン保存を開始"
      logger.debug "  現在のディレクトリ: #{Dir.pwd}"
      logger.debug "  トークンファイルパス: #{@token_file_path}"
      logger.debug "  ディレクトリの書き込み権限: #{File.writable?(File.dirname(@token_file_path))}"

      File.write(@token_file_path, token_data.to_json)
      logger.debug "トークンファイルを保存しました"
    rescue Errno::EACCES => e
      error_msg = "トークンファイルの書き込み権限エラー: #{@token_file_path}\n" \
                  "現在のディレクトリ: #{Dir.pwd}\n" \
                  "エラー詳細: #{e.message}"
      logger.debug error_msg
      raise error_msg
    rescue => e
      error_msg = "トークンファイルの保存エラー: #{e.message
      }\n" \
                  "ファイルパス: #{@token_file_path}"
      logger.debug error_msg
      raise error_msg
    end

    def load_credentials
      return nil unless File.exist?(@token_file_path)

      begin
        token_data = JSON.parse(File.read(@token_file_path))
      rescue JSON::ParserError => e
        logger.debug "トークンファイルが破損しています: #{e.message}"
        return nil
      rescue Errno::EACCES, Errno::ENOENT => e
        raise "トークンファイルへのアクセスに失敗しました: #{e.message}"
      end

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
    rescue KeyError => e
      logger.debug "トークンファイルに必要なキーがありません: #{e.message}"
      nil
    end

    def clear_credentials
      File.delete(@token_file_path) if File.exist?(@token_file_path)
    end
  end
end
