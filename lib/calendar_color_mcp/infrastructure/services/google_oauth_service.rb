# frozen_string_literal: true

require 'signet/oauth_2/client'
require 'google/apis/calendar_v3'
require 'cgi'

module Infrastructure
  class GoogleOAuthService
    include CalendarColorMCP::Loggable

    SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY
    REDIRECT_URI = 'urn:ietf:wg:oauth:2.0:oob'  # OOB flow for CLI

    # NOTE:引数必要かな？
    def initialize(config_service: ConfigurationService.instance)
      @config_service = config_service
      @oauth_client = build_oauth_client
    end

    def generate_auth_url
      # FIXME:必要な設定のチェックはinfraの他のクラスで任せる
      if @config_service.google_client_id.nil? || @config_service.google_client_id.empty?
        logger.error "Google client ID not set in configuration"
        raise Infrastructure::ConfigurationError, "Google client ID not set in configuration"
      end

      params = {
        'client_id' => @config_service.google_client_id,
        'redirect_uri' => REDIRECT_URI,
        'scope' => SCOPE,
        'response_type' => 'code',
        'access_type' => 'offline',
        'prompt' => 'consent'
      }

      query_string = params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      "https://accounts.google.com/o/oauth2/auth?#{query_string}"
    rescue => e
      raise Infrastructure::ExternalServiceError, "OAuth URL生成に失敗しました: #{e.message}"
    end

    def exchange_code_for_token(auth_code)
      @oauth_client.code = auth_code
      @oauth_client.fetch_access_token!
      @oauth_client
    rescue => e
      raise Infrastructure::ExternalServiceError, "トークン交換に失敗しました: #{e.message}"
    end

    private

    def build_oauth_client
      Signet::OAuth2::Client.new(
        client_id: @config_service.google_client_id,
        client_secret: @config_service.google_client_secret,
        authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
        token_credential_uri: 'https://oauth2.googleapis.com/token',
        redirect_uri: 'urn:ietf:wg:oauth:2.0:oob'
      )
    end
  end
end
