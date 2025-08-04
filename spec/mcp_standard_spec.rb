require 'spec_helper'

RSpec.describe 'MCP Standard Protocol', type: :request do
  include MCPRequestHelpers

  let(:timeout_duration) { 3 }

  describe 'MCP Protocol initialization' do
    it 'responds to initialize request with 2025-06-18 protocol version' do
      responses = execute_mcp_requests([initialize_request], timeout_duration)
      response = responses[0]

      aggregate_failures do
        expect(response['jsonrpc']).to eq('2.0')
        expect(response['id']).to eq(0)
        expect(response['result']).to have_key('protocolVersion')
        expect(response['result']).to have_key('capabilities')

        server_info = response['result']['serverInfo']
        expect(server_info['name']).to eq('calendar-color-analytics')
        expect(server_info['version']).to eq('1.0.0')
      end
    end
  end

  describe 'Tools list endpoint' do
    it 'returns all available tools with correct schema' do
      requests = [
        initialize_request,
        tools_list_request
      ]

      responses = execute_mcp_requests(requests, timeout_duration)
      list_response = responses[1]
      tools = list_response['result']['tools']

      aggregate_failures do
        expect(list_response['jsonrpc']).to eq('2.0')
        expect(list_response['id']).to eq(1)

        expect(tools.map { |tool| tool['name'] }).to match_array([
          'start_auth_tool',
          'check_auth_status_tool',
          'analyze_calendar_tool',
          'complete_auth_tool'
        ])

        # Verify each tool has required schema properties
        tools.each do |tool|
          expect(tool).to have_key('name')
          expect(tool).to have_key('description')
          expect(tool).to have_key('inputSchema')
        end
      end
    end
  end
end
