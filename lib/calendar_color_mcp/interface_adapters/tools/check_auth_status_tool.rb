require 'mcp'
require_relative 'base_tool'
require_relative '../../application/use_cases/authenticate_user_use_case'

module InterfaceAdapters
  class CheckAuthStatusTool < BaseTool
    description "認証状態を確認します"

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

          response_data = {
            authenticated: result[:authenticated],
            token_file_exists: result[:token_file_exists],
            message: build_status_message(result),
            status_message: build_status_message(result)
          }

          # FIXME:use caseで出来ないのか知りたい。
          response_data[:auth_url] = oauth_service.generate_auth_url unless result[:authenticated]

          success_response(response_data)
        rescue Application::AuthenticationError => e
          logger.error "Authentication error: #{e.message}"
          error_response("認証状態確認エラー: #{e.message}")
        rescue => e
          logger.error "Unexpected error occurred: #{e.message}"
          logger.debug "Error details: #{e.backtrace&.first(5)&.join(', ')}"
          error_response("認証状態確認時に予期しないエラーが発生しました")
        end
      end

      private

      def build_status_message(result)
        if result[:authenticated]
          "認証済みです"
        else
          "認証が必要です。start_authを実行してください"
        end
      end

    end
  end
end
