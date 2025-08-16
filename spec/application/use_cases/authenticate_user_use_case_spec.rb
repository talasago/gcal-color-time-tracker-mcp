require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/application/use_cases/authenticate_user_use_case'

RSpec.describe Application::AuthenticateUserUseCase do
  let(:mock_auth_manager) { CalendarColorMCP::GoogleCalendarAuthManager.instance }
  let(:mock_token_manager) { CalendarColorMCP::TokenManager.instance }

  subject(:use_case) do
    Application::AuthenticateUserUseCase.new(
      auth_manager: mock_auth_manager,
      token_manager: mock_token_manager
    )
  end

  describe '#start_authentication' do
    let(:auth_url) { 'https://accounts.google.com/o/oauth2/auth?...' }

    before do
      allow(mock_auth_manager).to receive(:get_auth_url).and_return(auth_url)
    end

    it 'should return authentication URL' do
      result = use_case.start_authentication

      expect(result).to eq(auth_url)
      expect(mock_auth_manager).to have_received(:get_auth_url)
    end
  end

  describe '#complete_authentication' do
    let(:auth_code) { 'valid_auth_code' }

    context 'when authentication is successful' do
      before do
        allow(mock_auth_manager).to receive(:complete_auth).with(auth_code)
          .and_return({ success: true, message: "Authentication completed" })
      end

      it 'should complete authentication successfully' do
        result = use_case.complete_authentication(auth_code)

        expect(result[:success]).to be true
        expect(mock_auth_manager).to have_received(:complete_auth).with(auth_code)
      end
    end

    context 'when authentication fails' do
      before do
        allow(mock_auth_manager).to receive(:complete_auth).with(auth_code)
          .and_return({ success: false, error: "Invalid code" })
      end

      it 'should raise AuthenticationRequiredError' do
        expect {
          use_case.complete_authentication(auth_code)
        }.to raise_error(Application::AuthenticationRequiredError, "Authentication failed: Invalid code")
      end
    end
  end
end
