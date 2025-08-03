require 'spec_helper'
require_relative '../lib/calendar_color_mcp/google_calendar_client'
require_relative '../lib/calendar_color_mcp/user_manager'

RSpec.describe CalendarColorMCP::GoogleCalendarClient do
  describe 'initialization' do
    it 'should load without errors' do
      expect {
        require_relative '../lib/calendar_color_mcp/google_calendar_client'
      }.not_to raise_error
    end

    it 'should instantiate with valid user_id when no credentials exist' do
      expect {
        CalendarColorMCP::GoogleCalendarClient.new('test_user')
      }.to raise_error(Google::Apis::AuthorizationError, "認証情報が見つかりません")
    end
  end
end