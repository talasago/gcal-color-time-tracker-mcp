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

      logger.debug "TokenManager initialized"
      logger.debug "  Current directory: #{Dir.pwd}"
      logger.debug "  Project root: #{project_root}"
      logger.debug "  Token file path: #{@token_file_path}"
      logger.debug "  Directory writable: #{File.writable?(project_root)}"
      logger.debug "  Token file exists: #{File.exist?(@token_file_path)}"
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

      logger.debug "Starting token save"
      logger.debug "  Current directory: #{Dir.pwd}"
      logger.debug "  Token file path: #{@token_file_path}"
      logger.debug "  Directory writable: #{File.writable?(File.dirname(@token_file_path))}"

      File.write(@token_file_path, token_data.to_json)
      logger.debug "Token file saved successfully"
    rescue Errno::EACCES => e
      error_msg = "Token file write permission error: #{@token_file_path}\n" \
                  "Current directory: #{Dir.pwd}\n" \
                  "Error details: #{e.message}"
      logger.error error_msg
      raise error_msg
    rescue => e
      error_msg = "Token file save error: #{e.message}\n" \
                  "File path: #{@token_file_path}"
      logger.error error_msg
      raise error_msg
    end

    def load_credentials
      return nil unless File.exist?(@token_file_path)

      begin
        token_data = JSON.parse(File.read(@token_file_path))
      rescue JSON::ParserError => e
        logger.debug "Token file corrupted: #{e.message}"
        return nil
      rescue Errno::EACCES, Errno::ENOENT => e
        raise "Failed to access token file: #{e.message}"
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
      logger.debug "Token file missing required keys: #{e.message}"
      nil
    end

    def clear_credentials
      File.delete(@token_file_path) if File.exist?(@token_file_path)
    end
  end
end
