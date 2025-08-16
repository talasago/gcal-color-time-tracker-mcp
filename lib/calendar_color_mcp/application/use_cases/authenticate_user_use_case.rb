require_relative '../errors'
require_relative '../../errors'
require_relative '../../token_manager'
require_relative '../../google_calendar_auth_manager'

module Application
  class AuthenticateUserUseCase
    def initialize(
      auth_manager: CalendarColorMCP::GoogleCalendarAuthManager.instance,
      token_manager: CalendarColorMCP::TokenManager.instance
    )
      @auth_manager = auth_manager
      @token_manager = token_manager
    end
    
    def start_authentication
      @auth_manager.get_auth_url
    end
    
    def complete_authentication(auth_code)
      result = @auth_manager.complete_auth(auth_code)
      unless result[:success]
        raise Application::AuthenticationRequiredError, "Authentication failed: #{result[:error]}"
      end
      result
    end
  end
end