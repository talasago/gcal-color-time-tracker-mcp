require 'mcp'
require_relative 'base_tool'
require_relative '../../application/use_cases/authenticate_user_use_case'

module InterfaceAdapters
  class CheckAuthStatusTool < BaseTool
    description "Check authentication status"

    input_schema(
      type: "object",
      properties: {},
      required: []
    )

    class << self
      def call(**context)
        logger.info "Checking authentication status"

        begin
          oauth_service = extract_oauth_service(context)
          use_case = Application::AuthenticateUserUseCase.new(
            oauth_service: oauth_service,
            token_repository: extract_token_repository(context)
          )
          result = use_case.check_authentication_status

          logger.debug "Authentication status: #{result[:authenticated] ? 'authenticated' : 'not authenticated'}"

          success_response(result)
        rescue Application::AuthenticationError => e
          logger.error "Authentication error: #{e.message}"
          error_response("Authentication status check error: #{e.message}")
        rescue => e
          logger.error "Unexpected error occurred: #{e.message}"
          logger.debug "Error details: #{e.backtrace&.first(5)&.join(', ')}"
          error_response("An unexpected error occurred during authentication status check")
        end
      end
    end
  end
end
