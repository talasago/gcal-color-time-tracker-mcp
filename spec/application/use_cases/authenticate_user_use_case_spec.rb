require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/application/use_cases/authenticate_user_use_case'

RSpec.describe Application::AuthenticateUserUseCase do
  let(:mock_oauth_service) { instance_double(Infrastructure::GoogleOAuthService) }
  let(:mock_token_repository) { instance_double(Infrastructure::TokenRepository) }

  subject(:use_case) do
    Application::AuthenticateUserUseCase.new(
      oauth_service: mock_oauth_service,
      token_repository: mock_token_repository
    )
  end

  describe '#start_authentication' do
    let(:auth_url) { 'https://accounts.google.com/o/oauth2/auth?...' }

    before do
      allow(mock_oauth_service).to receive(:generate_auth_url).and_return(auth_url)
    end

    it 'should return authentication URL' do
      result = use_case.start_authentication

      expect(result[:auth_url]).to eq(auth_url)
      expect(result[:instructions]).to include('認証')
      expect(mock_oauth_service).to have_received(:generate_auth_url)
    end
  end

  describe '#complete_authentication' do
    let(:auth_code) { 'valid_auth_code' }
    let(:credentials) { { access_token: 'token', refresh_token: 'refresh' } }

    context 'when authentication is successful' do
      before do
        allow(mock_oauth_service).to receive(:exchange_code_for_token).with(auth_code)
          .and_return(credentials)
        allow(mock_token_repository).to receive(:save_credentials).with(credentials)
      end

      it 'should complete authentication successfully' do
        result = use_case.complete_authentication(auth_code)

        expect(result[:success]).to be true
        expect(result[:message]).to eq('認証が完了しました')
        expect(mock_oauth_service).to have_received(:exchange_code_for_token).with(auth_code)
        expect(mock_token_repository).to have_received(:save_credentials).with(credentials)
      end
    end

    context 'when authentication fails' do
      before do
        allow(mock_oauth_service).to receive(:exchange_code_for_token).with(auth_code)
          .and_raise(Infrastructure::ExternalServiceError, "Invalid code")
      end

      it 'should raise AuthenticationError' do
        expect {
          use_case.complete_authentication(auth_code)
        }.to raise_error(Application::AuthenticationError, "認証完了に失敗しました: Invalid code")
      end
    end
  end

  describe '#check_authentication_status' do
    context 'when authenticated' do
      before do
        allow(mock_token_repository).to receive(:token_exist?).and_return(true)
        allow(mock_token_repository).to receive(:token_file_exists?).and_return(true)
      end

      it 'should return authenticated status with message and no auth URL' do
        result = use_case.check_authentication_status

        expect(result[:authenticated]).to be true
        expect(result[:token_file_exists]).to be true
        expect(result[:message]).to eq("認証済みです")
        expect(result[:auth_url]).to be_nil
      end
    end

    context 'when not authenticated' do
      before do
        allow(mock_token_repository).to receive(:token_exist?).and_return(false)
        allow(mock_token_repository).to receive(:token_file_exists?).and_return(false)
        allow(mock_oauth_service).to receive(:generate_auth_url).and_return('https://oauth.example.com/auth')
      end

      it 'should return not authenticated status with message and auth URL' do
        result = use_case.check_authentication_status

        expect(result[:authenticated]).to be false
        expect(result[:token_file_exists]).to be false
        expect(result[:message]).to eq("認証が必要です。start_authを実行してください")
        expect(result[:auth_url]).to eq('https://oauth.example.com/auth')
      end
    end
  end
end
