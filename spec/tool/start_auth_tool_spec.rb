require 'spec_helper'
require_relative '../support/mcp_request_helpers'
require_relative '../support/mcp_shared_examples'
require 'uri'
require 'cgi'
require_relative '../../lib/calendar_color_mcp/tools/start_auth_tool'

RSpec.describe 'StartAuthTool', type: :request do
  include MCPRequestHelpers
  include MCPSharedHelpers

  include_examples 'BaseTool inheritance', CalendarColorMCP::StartAuthTool

  describe 'successful authentication start' do
    context 'when called with valid parameters' do
      before do
        ENV['GOOGLE_CLIENT_ID'] ||= 'test-client-id-12345.apps.googleusercontent.com'
      end

      let(:init_req) { initialize_request(0) }
      let(:start_auth_req) { start_auth_request(1) }
      let(:responses) { execute_mcp_requests([init_req, start_auth_req]) }
      let(:response) { responses[1] }
      let(:content) { parse_response_content(response) }
      let(:expected_id) { 1 }

      include_examples 'valid MCP protocol response'

      it 'should return successful response' do
        expect_success_response(content)
      end

      it 'should return valid OAuth URL' do
        expect(content).to have_key('auth_url')
        expect(content['auth_url']).to start_with('https://accounts.google.com/o/oauth2/auth')

        auth_url = content['auth_url']
        uri = URI.parse(auth_url)
        query_params = CGI.parse(uri.query)

        aggregate_failures do
          expect(uri.scheme).to eq('https')
          expect(uri.host).to eq('accounts.google.com')
          expect(uri.path).to eq('/o/oauth2/auth')

          expect(query_params['response_type']).to eq(['code'])
          expect(query_params['access_type']).to eq(['offline'])
          expect(query_params['prompt']).to eq(['consent'])
          expect(query_params['scope']).to include('https://www.googleapis.com/auth/calendar.readonly')
          expect(query_params['client_id']).to eq([ENV['GOOGLE_CLIENT_ID']])
          expect(query_params['redirect_uri']).to eq(['urn:ietf:wg:oauth:2.0:oob'])
        end
      end

      it 'should return proper authentication instructions' do
        aggregate_failures do
          expect(content).to have_key('instructions')
          expect(content['instructions']).to include('上記URLにアクセスしてください')
          expect(content['instructions']).to include('CompleteAuthTool')
          expect(content['instructions']).to include('認証コード')
        end
      end
    end
  end

  describe 'consistency across calls' do
    context 'when called multiple times' do
      let(:first_responses) { execute_mcp_requests([initialize_request(0), start_auth_request(1)]) }
      let(:second_responses) { execute_mcp_requests([initialize_request(0), start_auth_request(1)]) }
      let(:first_content) { parse_response_content(first_responses[1]) }
      let(:second_content) { parse_response_content(second_responses[1]) }

      it 'should return consistent success responses' do
        aggregate_failures do
          expect(first_content['success']).to be true
          expect(second_content['success']).to be true
        end
      end

      it 'should return identical auth URLs' do
        expect(first_content['auth_url']).to eq(second_content['auth_url'])
      end
    end
  end

  describe 'invalid parameter handling' do
    include_examples 'handles invalid parameters gracefully', 'start_auth_tool'
  end

end
