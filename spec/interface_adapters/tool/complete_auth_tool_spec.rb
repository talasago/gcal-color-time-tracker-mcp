require 'spec_helper'
require_relative '../../support/mcp_request_helpers'
require_relative '../../support/mcp_shared_examples'
require_relative '../../support/mcp_shared_contexts'
require_relative '../../../lib/calendar_color_mcp/interface_adapters/tools/complete_auth_tool'
require_relative '../../../lib/calendar_color_mcp/application/errors'

RSpec.describe 'CompleteAuthTool', type: :request do
  include MCPRequestHelpers
  include MCPSharedHelpers

  describe 'complete_auth_tool execution' do
    context 'when auth code is valid (mocked)' do
      include_context 'authenticated user'

      before do
        allow(mock_auth_manager).to receive(:complete_auth).and_return({
          success: true,
          message: "Authentication completed successfully"
        })
      end

      it 'handles valid auth code' do

        # Call tool directly with mocked context
        response = InterfaceAdapters::CompleteAuthTool.call(
          auth_code: "valid_test_code",
          server_context: server_context
        )

        content = JSON.parse(response.content[0][:text])
        expect(content['success']).to be true
        expect(content['message']).to eq("Authentication completed successfully")
      end
    end

    context 'when auth code is invalid' do
      let(:mock_use_case) { instance_double(Application::AuthenticateUserUseCase) }
      let(:mock_oauth_service) { instance_double('MockOAuthService') }
      let(:mock_token_repository) { instance_double('MockTokenRepository') }
      let(:server_context) { { oauth_service: mock_oauth_service, token_repository: mock_token_repository } }

      before do
        allow(Application::AuthenticateUserUseCase).to receive(:new)
          .with(oauth_service: anything, token_repository: anything)
          .and_return(mock_use_case)

        allow(mock_use_case).to receive(:complete_authentication)
          .with("invalid_code_123")
          .and_raise(Application::AuthenticationError, "messages")
      end

      it 'handles invalid auth code' do
        response = InterfaceAdapters::CompleteAuthTool.call(
          auth_code: "invalid_code_123",
          server_context: server_context
        )

        content = JSON.parse(response.content[0][:text])
        expect(content['success']).to be false
        expect(content['error']).to eq('Authentication error: messages')
      end
    end

    context 'when auth code is empty' do
      # ツールレベルでの空文字バリデーション（arguments: {auth_code: \"\"}）
      it 'handles empty auth code' do
        init_req = initialize_request(0)
        complete_auth_req = complete_auth_request("", 1)
        responses = execute_mcp_requests([init_req, complete_auth_req])
        response = responses[1]
        content = parse_response_content(response)

        expect(content['success']).to be false
        # Specific error message defined in implementation
        expect(content['error']).to eq('Input error: Authorization code is required')
      end
    end
  end

  describe 'parameter validation' do
    # MCP protocol-level parameter absence (arguments: {})
    it 'handles missing auth_code parameter' do
      init_req = initialize_request(0)
      # Missing auth_code parameter
      invalid_req = {
        method: "tools/call",
        params: {
          name: "complete_auth_tool",
          arguments: {}
        },
        jsonrpc: "2.0",
        id: 1
      }
      responses = execute_mcp_requests([init_req, invalid_req])
      response = responses[1]

      # MCP protocol-level error (missing required parameter)
      expect(response).to have_key('error')
      expect(response['error']['message']).to eq('Internal error')
      expect(response['error']['data']).to include('auth_code')
    end
  end

  describe 'auth code format validation' do
    context 'when auth code has whitespace' do
      it 'handles whitespace in auth code' do
        init_req = initialize_request(0)
        complete_auth_req = complete_auth_request("  test_code  ", 1)
        responses = execute_mcp_requests([init_req, complete_auth_req])
        response = responses[1]
        content = parse_response_content(response)

        expect_success_response(content)
      end
    end
  end
end
