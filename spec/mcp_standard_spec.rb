require 'spec_helper'
require 'json'
require 'open3'

RSpec.describe 'MCP Standard Protocol', type: :integration do
  let(:server_command) { './bin/calendar-color-mcp' }
  let(:timeout_duration) { 3 }

  describe 'MCP Protocol initialization' do
    it 'responds to initialize request with 2025-06-18 protocol version' do
      request = {
        method: "initialize",
        params: {
          protocolVersion: "2025-06-18",
          capabilities: {},
          clientInfo: {
            name: "claude-ai",
            version: "0.1.0"
          }
        },
        jsonrpc: "2.0",
        id: 0
      }.to_json

      stdout, stderr, status = Open3.capture3(
        "echo '#{request}' | timeout #{timeout_duration} #{server_command}"
      )

      # Handle JSON parsing with detailed error info for test debugging
      # server execution may produce unexpected output that needs investigation
      begin
        response = JSON.parse(stdout.strip)
      rescue JSON::ParserError => e
        puts "stdout: #{stdout}"
        puts "stderr: #{stderr}"
        raise "Failed to parse JSON response: #{e.message}"
      end

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
      # Initialize first
      init_request = {
        method: "initialize",
        params: {
          protocolVersion: "2025-06-18",
          capabilities: {},
          clientInfo: {
            name: "claude-ai",
            version: "0.1.0"
          }
        },
        jsonrpc: "2.0",
        id: 0
      }.to_json

      # Then list tools
      list_request = {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/list",
        params: {}
      }.to_json

      requests_sequence = [init_request, list_request].join("\n")

      stdout, stderr, status = Open3.capture3(
        "echo '#{requests_sequence}' | timeout #{timeout_duration} #{server_command}"
      )

      # Handle JSON parsing with detailed error info for test debugging
      # server execution may produce unexpected output that needs investigation
      begin
        responses = stdout.strip.split("\n").map { |line| JSON.parse(line) }
      rescue JSON::ParserError => e
        puts "stdout: #{stdout}"
        puts "stderr: #{stderr}"
        raise "Failed to parse JSON responses: #{e.message}"
      end

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
