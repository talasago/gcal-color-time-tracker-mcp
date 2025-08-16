require_relative '../errors'
require_relative '../../errors'
require_relative '../../token_manager'
require_relative '../../google_calendar_auth_manager'

module Application
  class CheckAuthStatusUseCase
    def initialize(
      auth_manager: CalendarColorMCP::GoogleCalendarAuthManager.instance,
      token_manager: CalendarColorMCP::TokenManager.instance
    )
      @auth_manager = auth_manager
      @token_manager = token_manager
    end
    
    def execute
      if @token_manager.token_exist?
        {
          authenticated: true,
          message: "認証済み"
        }
      else
        {
          authenticated: false,
          message: "認証が必要です",
          auth_url: @auth_manager.get_auth_url
        }
      end
    end
  end
end