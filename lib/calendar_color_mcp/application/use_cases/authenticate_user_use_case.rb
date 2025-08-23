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
      instructions = "Please access the above URL. After authentication, obtain the authorization code and complete the authentication with CompleteAuthTool."

      {
        auth_url: auth_url,
        instructions: instructions
      }
    rescue Infrastructure::ExternalServiceError => e
      raise Application::AuthenticationError, "Failed to start authentication: #{e.message}"
    rescue => e
      raise Application::AuthenticationError, "Failed to start authentication: #{e.message}"
    end

    def complete_authentication(auth_code)
      validate_auth_code(auth_code)

      credentials = @oauth_service.exchange_code_for_token(auth_code)
      @token_repository.save_credentials(credentials)

      {
        success: true,
        message: "Authentication completed successfully"
      }
    rescue Application::ValidationError => e
      raise e
    rescue Infrastructure::ExternalServiceError => e
      raise Application::AuthenticationError, "Failed to complete authentication: #{e.message}"
    rescue => e
      raise Application::AuthenticationError, "Failed to complete authentication: #{e.message}"
    end

    def check_authentication_status
      authenticated = @token_repository.token_exist?
      token_file_exists = @token_repository.token_file_exists?
      
      {
        authenticated: authenticated,
        token_file_exists: token_file_exists,
        message: build_status_message(authenticated),
        auth_url: authenticated ? nil : @oauth_service.generate_auth_url
      }
    rescue Infrastructure::ExternalServiceError => e
      raise Application::AuthenticationError, "Failed to check authentication status: #{e.message}"
    rescue => e
      raise Application::AuthenticationError, "Failed to check authentication status: #{e.message}"
    end

    private

    def validate_auth_code(auth_code)
      if auth_code.nil? || auth_code.to_s.strip.empty?
        raise Application::ValidationError, "Authorization code is required"
      end
    end

    def build_status_message(authenticated)
      if authenticated
        "Authenticated"
      else
        "Authentication required. Please run start_auth"
      end
    end
  end
end
