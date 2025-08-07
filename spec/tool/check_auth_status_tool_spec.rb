require 'spec_helper'
require_relative '../../lib/calendar_color_mcp/tools/check_auth_status_tool'

RSpec.describe 'CheckAuthStatusTool', type: :request do
  include MCPRequestHelpers
  include MCPSharedHelpers

  describe 'check_auth_status_tool execution' do
    let(:init_req) { initialize_request(0) }
    let(:auth_check_req) { check_auth_status_request(1) }
    let(:responses) { execute_mcp_requests([init_req, auth_check_req]) }
    let(:response) { responses[1] }
    let(:content) { parse_response_content(response) }
    let(:expected_id) { 1 }

    include_examples 'valid MCP protocol response'

    it 'should return authentication status with required fields' do
      aggregate_failures do
        expect(content).to have_key('authenticated')
        expect([true, false]).to include(content['authenticated'])
        expect(content).to have_key('message')
        expect(content['message']).to be_a(String)
        expect(content['message']).not_to be_empty
      end
    end

    it 'should maintain consistent behavior across multiple calls' do
      init_req2 = initialize_request(0)
      auth_check_req2 = check_auth_status_request(1)
      second_responses = execute_mcp_requests([init_req2, auth_check_req2])
      second_response = second_responses[1]
      second_content = JSON.parse(second_response['result']['content'][0]['text'])

      aggregate_failures do
        expect(content['authenticated']).to eq(second_content['authenticated'])
        expect(content['message']).to eq(second_content['message'])
      end
    end
  end

  describe 'CheckAuthStatusTool unit tests' do
    let(:mock_auth_manager) do
      instance_double('CalendarColorMCP::SimpleAuthManager').tap do |mock|
        allow(mock).to receive(:authenticated?).and_return(is_authenticated)
        allow(mock).to receive(:get_auth_url).and_return(auth_url) if defined?(auth_url)
      end
    end

    let(:server_context) { { auth_manager: mock_auth_manager } }

    context 'when user is authenticated' do
      let(:is_authenticated) { true }

      it 'should provide authenticated user information' do
        response = CalendarColorMCP::CheckAuthStatusTool.call(server_context: server_context)
        content = JSON.parse(response.content[0][:text])

        aggregate_failures do
          expect(content['success']).to be true
          expect(content['authenticated']).to be true
          expect(content['message']).to eq('認証済みです')
          expect(content).not_to have_key('auth_url')
        end
      end
    end

    context 'when user is not authenticated' do
      let(:is_authenticated) { false }
      let(:auth_url) { 'https://accounts.google.com/oauth2/auth?client_id=...' }

      it 'should provide authentication required message' do
        response = CalendarColorMCP::CheckAuthStatusTool.call(server_context: server_context)
        content = JSON.parse(response.content[0][:text])

        aggregate_failures do
          expect(content['success']).to be true
          expect(content['authenticated']).to be false
          expect(content['message']).to eq('認証が必要です')
          expect(content).to have_key('auth_url')
          expect(content['auth_url']).to start_with('https://accounts.google.com/oauth2/auth')
        end
      end
    end

    include_examples 'handles missing auth manager', CalendarColorMCP::CheckAuthStatusTool
  end

  describe 'response format validation' do
    it 'maintains consistent response structure regardless of auth state' do
      init_req = initialize_request(0)
      auth_check_req = check_auth_status_request(1)
      responses = execute_mcp_requests([init_req, auth_check_req])
      response = responses[1]
      content = JSON.parse(response['result']['content'][0]['text'])

      required_fields = ['authenticated', 'message']
      required_fields.each do |field|
        expect(content).to have_key(field), "Missing required field: #{field}"
      end

      expect([true, false]).to include(content['authenticated'])
      expect(content['message']).to be_a(String)
      expect(content['message']).not_to be_empty
    end
  end

  describe 'invalid parameter handling' do
    include_examples 'handles invalid parameters gracefully', 'check_auth_status_tool'
  end
end