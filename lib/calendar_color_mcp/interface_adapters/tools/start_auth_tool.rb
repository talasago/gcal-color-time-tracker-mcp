require 'mcp'
require_relative 'base_tool'
require_relative '../../application/use_cases/authenticate_user_use_case'

module InterfaceAdapters
  class StartAuthTool < BaseTool
    description "Start Google Calendar authentication"

    input_schema(
      type: "object",
      properties: {},
      required: []
    )

    class << self
      def call(**context)
        logger.info "Starting authentication process"

        begin
          use_case = Application::AuthenticateUserUseCase.new(
            oauth_service: extract_oauth_service(context),
            token_repository: extract_token_repository(context)
          )
          result = use_case.start_authentication

          logger.info "Authentication URL generated successfully"
          logger.debug "Auth URL: #{result[:auth_url]}"

          success_response({
            message: "Starting authentication process",
            auth_url: result[:auth_url],
            instructions: result[:instructions]
          })
        rescue Application::AuthenticationError => e
          logger.error "Authentication error: #{e.message}"
          error_response("Authentication start error: #{e.message}")
        rescue => e
          logger.error "Unexpected error occurred: #{e.message}"
          logger.debug "Error details: #{e.backtrace&.first(5)&.join(', ')}"
          error_response("An unexpected error occurred during authentication start")
        end
      end
    end
  end
end
