require 'spec_helper'
require 'uri'
require 'cgi'
require_relative '../../lib/calendar_color_mcp/tools/start_auth_tool'

RSpec.describe 'StartAuthTool', type: :request do
  include MCPRequestHelpers
  include MCPSharedHelpers

  describe 'start_auth_tool execution' do
    let(:init_req) { initialize_request(0) }
    let(:start_auth_req) { start_auth_request(1) }
    let(:responses) { execute_mcp_requests([init_req, start_auth_req]) }
    let(:response) { responses[1] }
    let(:content) { parse_response_content(response) }
    let(:expected_id) { 1 }

    include_examples 'valid MCP protocol response'

    it 'should return successful response with valid OAuth URL and instructions' do
      aggregate_failures do
        expect_success_response(content)
        expect(content).to have_key('auth_url')
        expect(content['auth_url']).to start_with('https://accounts.google.com/o/oauth2/auth')
        expect(content).to have_key('instructions')
        expect(content['instructions']).to be_a(String)
        expect(content['instructions']).to include('上記URLにアクセスしてください')
        expect(content['instructions']).to include('CompleteAuthTool')
        expect(content['instructions']).to include('認証コード')
        
        auth_url = content['auth_url']
        uri = URI.parse(auth_url)
        query_params = CGI.parse(uri.query)

        expect(uri.scheme).to eq('https')
        expect(uri.host).to eq('accounts.google.com')
        expect(uri.path).to eq('/o/oauth2/auth')

        expect(query_params['response_type']).to eq(['code'])
        expect(query_params['access_type']).to eq(['offline'])
        expect(query_params['prompt']).to eq(['consent'])
        expect(query_params['scope']).to include('https://www.googleapis.com/auth/calendar.readonly')
        expect(query_params['client_id']).not_to be_empty
        expect(query_params['redirect_uri']).to eq(['urn:ietf:wg:oauth:2.0:oob'])
      end
    end

    it 'should handle multiple consecutive calls gracefully' do
      init_req1 = initialize_request(0)
      start_auth_req1 = start_auth_request(1)
      first_responses = execute_mcp_requests([init_req1, start_auth_req1])
      first_response = first_responses[1]

      init_req2 = initialize_request(0)
      start_auth_req2 = start_auth_request(1)
      second_responses = execute_mcp_requests([init_req2, start_auth_req2])
      second_response = second_responses[1]

      first_content = JSON.parse(first_response['result']['content'][0]['text'])
      second_content = JSON.parse(second_response['result']['content'][0]['text'])

      aggregate_failures do
        expect(first_content['success']).to be true
        expect(second_content['success']).to be true
        expect(first_content['auth_url']).to eq(second_content['auth_url'])
      end
    end
  end

  describe 'invalid parameter handling' do
    include_examples 'handles invalid parameters gracefully', 'start_auth_tool'
  end

  describe 'error handling' do
    include_examples 'handles missing auth manager', CalendarColorMCP::StartAuthTool
  end
end
