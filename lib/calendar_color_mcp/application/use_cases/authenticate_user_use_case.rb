require_relative '../errors'
require_relative '../../infrastructure/services/google_oauth_service'
require_relative '../../infrastructure/repositories/token_repository'

module Application
  class AuthenticateUserUseCase
    def initialize(
      oauth_service: Infrastructure::GoogleOAuthService.new,
      token_repository: Infrastructure::TokenRepository.instance
    )
      @oauth_service = oauth_service
      @token_repository = token_repository
    end

    def start_authentication
      auth_url = @oauth_service.generate_auth_url
      instructions = "上記URLにアクセスしてください。認証後、認証コードを取得し、CompleteAuthToolで認証を完了してください。"

      {
        auth_url: auth_url,
        instructions: instructions
      }
    rescue Infrastructure::ExternalServiceError => e
      raise Application::AuthenticationError, "認証開始に失敗しました: #{e.message}"
    rescue => e
      raise Application::AuthenticationError, "認証開始に失敗しました: #{e.message}"
    end

    def complete_authentication(auth_code)
      validate_auth_code(auth_code)

      credentials = @oauth_service.exchange_code_for_token(auth_code)
      @token_repository.save_credentials(credentials)

      {
        success: true,
        message: "認証が完了しました"
      }
    rescue Application::ValidationError => e
      raise e
    rescue Infrastructure::ExternalServiceError => e
      raise Application::AuthenticationError, "認証完了に失敗しました: #{e.message}"
    rescue => e
      raise Application::AuthenticationError, "認証完了に失敗しました: #{e.message}"
    end

    def check_authentication_status
      {
        authenticated: @token_repository.token_exist?,
        token_file_exists: @token_repository.token_file_exists?
      }
    end

    private

    def validate_auth_code(auth_code)
      if auth_code.nil? || auth_code.to_s.strip.empty?
        raise Application::ValidationError, "認証コードが入力されていません"
      end
    end
  end
end
