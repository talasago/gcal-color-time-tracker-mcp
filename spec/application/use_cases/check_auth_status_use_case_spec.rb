require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/application/use_cases/check_auth_status_use_case'

RSpec.describe Application::CheckAuthStatusUseCase do
  let(:mock_auth_manager) { CalendarColorMCP::GoogleCalendarAuthManager.instance }
  let(:mock_token_manager) { CalendarColorMCP::TokenManager.instance }

  subject(:use_case) do
    Application::CheckAuthStatusUseCase.new(
      auth_manager: mock_auth_manager,
      token_manager: mock_token_manager
    )
  end

  describe '#execute' do
    context 'when user is authenticated' do
      before do
        allow(mock_token_manager).to receive(:token_exist?).and_return(true)
      end

      it 'should return authenticated status' do
        result = use_case.execute

        expect(result[:authenticated]).to be true
        expect(result[:message]).to eq("認証済み")
        expect(mock_token_manager).to have_received(:token_exist?)
      end
    end

    context 'when user is not authenticated' do
      before do
        allow(mock_token_manager).to receive(:token_exist?).and_return(false)
        allow(mock_auth_manager).to receive(:get_auth_url).and_return('https://auth.url')
      end

      it 'should return not authenticated status with auth URL' do
        result = use_case.execute

        expect(result[:authenticated]).to be false
        expect(result[:message]).to eq("認証が必要です")
        expect(result[:auth_url]).to eq('https://auth.url')
        expect(mock_token_manager).to have_received(:token_exist?)
        expect(mock_auth_manager).to have_received(:get_auth_url)
      end
    end
  end
end
