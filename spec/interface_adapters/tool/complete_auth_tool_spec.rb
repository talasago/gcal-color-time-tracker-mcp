require 'spec_helper'
require_relative '../../support/mcp_request_helpers'
require_relative '../../support/mcp_shared_examples'
require_relative '../../support/mcp_shared_contexts'
require_relative '../../../lib/calendar_color_mcp/interface_adapters/tools/complete_auth_tool'

RSpec.describe 'CompleteAuthTool', type: :request do
  include MCPRequestHelpers
  include MCPSharedHelpers

  include_examples 'BaseTool inheritance', InterfaceAdapters::CompleteAuthTool, {
    auth_code: "test_code"
  }

  describe 'complete_auth_tool execution' do
    context 'when auth code is valid (mocked)' do
      include_context 'authenticated user'

      before do
        allow(mock_auth_manager).to receive(:complete_auth).and_return({
          success: true,
          message: "認証が完了しました"
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
        expect(content['message']).to eq("認証が完了しました")
      end
    end

    context 'when auth code is invalid' do
      it 'handles invalid auth code' do
        # Use an obviously invalid auth code
        invalid_auth_code = "invalid_code_123"

        init_req = initialize_request(0)
        complete_auth_req = complete_auth_request(invalid_auth_code, 1)
        responses = execute_mcp_requests([init_req, complete_auth_req])
        response = responses[1]
        content = parse_response_content(response)

        expect(content['success']).to be false
        # Expected error patterns for invalid auth code
        expect(content['error']).to match(/Authentication.*failed|invalid_grant|Malformed/)
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
        expect(content['error']).to eq('入力エラー: 認証コードが入力されていません')
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
