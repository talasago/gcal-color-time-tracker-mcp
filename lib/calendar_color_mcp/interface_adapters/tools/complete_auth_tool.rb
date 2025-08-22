require 'mcp'
require_relative 'base_tool'
require_relative '../../application/use_cases/authenticate_user_use_case'
require_relative '../../application/errors'

module InterfaceAdapters
  class CompleteAuthTool < BaseTool
    description "Google認証コードを使用して認証を完了します"

    input_schema(
      type: "object",
      properties: {
        auth_code: {
          type: "string",
          description: "Googleから取得した認証コード"
        }
      },
      required: ["auth_code"]
    )

    class << self
      def call(auth_code:, **context)
        logger.info "Completing authentication with provided code"
        logger.debug "Auth code provided: #{auth_code ? 'yes' : 'no'}"

        begin
          use_case = Application::AuthenticateUserUseCase.new(
            oauth_service: extract_oauth_service(context),
            token_repository: extract_token_repository(context)
          )
          result = use_case.complete_authentication(auth_code&.strip)

          logger.info "Authentication completed successfully"
          success_response(result)
        rescue Application::ValidationError => e
          logger.error "Validation error: #{e.message}"
          error_response("入力エラー: #{e.message}")
        rescue Application::AuthenticationError => e
          logger.error "Authentication error: #{e.message}"
          error_response("認証エラー: #{e.message}")
        rescue => e
          logger.error "Unexpected error occurred: #{e.message}"
          logger.debug "Error details: #{e.backtrace&.first(5)&.join(', ')}"
          error_response("認証完了時に予期しないエラーが発生しました")
        end
      end
    end
  end
end
