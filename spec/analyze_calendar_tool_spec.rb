require 'spec_helper'
require_relative '../lib/calendar_color_mcp/tools/analyze_calendar_tool'
require_relative '../lib/calendar_color_mcp/user_manager'
require_relative '../lib/calendar_color_mcp/auth_manager'

RSpec.describe CalendarColorMCP::AnalyzeCalendarTool do
  let(:user_manager) { CalendarColorMCP::UserManager.new }
  let(:auth_manager) { CalendarColorMCP::AuthManager.new }
  let(:server_context) { { user_manager: user_manager, auth_manager: auth_manager } }

  describe '.call' do
    it 'should return authentication required when user is not authenticated' do
      response = CalendarColorMCP::AnalyzeCalendarTool.call(
        user_id: 'test_user',
        start_date: '2024-01-01',
        end_date: '2024-01-31',
        server_context: server_context
      )

      expect(response).to be_a(MCP::Tool::Response)
      content = JSON.parse(response.content.first[:text])
      expect(content['success']).to be false
      expect(content['error']).to eq '認証が必要です'
      expect(content['auth_url']).to be_a(Hash)
    end
  end
end