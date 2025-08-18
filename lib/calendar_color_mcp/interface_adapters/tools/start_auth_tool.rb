require 'mcp'
require_relative 'base_tool'
require_relative '../../application/use_cases/authenticate_user_use_case'

module InterfaceAdapters
  class StartAuthTool < BaseTool
    description "Google Calendar認証を開始します"

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
            message: "認証プロセスを開始します",
            auth_url: result[:auth_url],
            instructions: result[:instructions]
          })
        rescue Application::AuthenticationError => e
          logger.error "Authentication error: #{e.message}"
          error_response("認証開始エラー: #{e.message}")
        rescue => e
          logger.error "Unexpected error occurred: #{e.message}"
          logger.debug "Error details: #{e.backtrace&.first(5)&.join(', ')}"
          error_response("認証開始時に予期しないエラーが発生しました")
        end
      end

      private

      def extract_oauth_service(context)
        server_context = context[:server_context]
        oauth_service = server_context&.dig(:oauth_service)

        oauth_service || raise(InterfaceAdapters::DependencyInjectionError, "oauth_service not found in server_context")
      end

      def extract_token_repository(context)
        server_context = context[:server_context]
        token_repository = server_context&.dig(:token_repository)

        token_repository || raise(InterfaceAdapters::DependencyInjectionError, "token_repository not found in server_context")
      end
    end
  end
end
