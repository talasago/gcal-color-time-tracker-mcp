# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'googleauth'
require 'singleton'

module Infrastructure
  class TokenRepository
    include Singleton
    include CalendarColorMCP::Loggable

    TOKEN_FILE = 'token.json'

    def initialize
      @config_service = ConfigurationService.instance
      @token_file_path = build_token_file_path
      # NOTE:なにこれ？
      @mutex = Mutex.new

      logger.debug "TokenRepository initialized"
      logger.debug "  Token file path: #{@token_file_path}"
      logger.debug "  Token file exists: #{File.exist?(@token_file_path)}"
    end

    def save_credentials(credentials)
      @mutex.synchronize do
        token_data = {
          access_token: credentials.access_token,
          refresh_token: credentials.refresh_token,
          expires_at: credentials.expires_at&.to_i,
          saved_at: Time.now.to_i
        }

        logger.debug "Starting token save to #{@token_file_path}"
        File.write(@token_file_path, token_data.to_json)
        logger.debug "Token file saved successfully"
      end
    rescue Errno::EACCES => e
      error_msg = "Token file write permission error: #{@token_file_path}\n" \
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
        client_id: @config_service.google_client_id,
        client_secret: @config_service.google_client_secret,
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

    def token_exist?
      !load_credentials.nil?
    rescue
      false
    end

    def clear_credentials
      @mutex.synchronize do
        File.delete(@token_file_path) if File.exist?(@token_file_path)
      end
    end

    def token_file_exists?
      File.exist?(@token_file_path)
    end

    private

    def build_token_file_path
      project_root = File.expand_path('../../../..', __FILE__)
      File.join(project_root, TOKEN_FILE)
    end
  end
end
