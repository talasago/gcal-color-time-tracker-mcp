# frozen_string_literal: true

require_relative '../../spec_helper'

describe Infrastructure::GoogleOAuthService do
  subject(:oauth_service) { Infrastructure::GoogleOAuthService.new }

  let(:mock_config) do
    instance_double(Infrastructure::ConfigurationService).tap do |mock|
      allow(mock).to receive(:google_client_id).and_return('test_client_id')
      allow(mock).to receive(:google_client_secret).and_return('test_client_secret')
    end
  end

  before do
    allow(Infrastructure::ConfigurationService).to receive(:instance).and_return(mock_config)
  end

  describe '#generate_auth_url' do
    it "should return a valid Google OAuth URL" do
      url = oauth_service.generate_auth_url
      expected_url = 'https://accounts.google.com/o/oauth2/auth?' \
                    'client_id=test_client_id&' \
                    'redirect_uri=urn%3Aietf%3Awg%3Aoauth%3A2.0%3Aoob&' \
                    'scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcalendar.readonly&' \
                    'response_type=code&' \
                    'access_type=offline&' \
                    'prompt=consent'
      expect(url).to eq(expected_url)
    end
  end

  describe '#exchange_code_for_token' do
    let(:auth_code) { 'valid_auth_code_123' }
    let(:mock_oauth_client) { instance_double(Signet::OAuth2::Client) }

    before do
      allow(Signet::OAuth2::Client).to receive(:new).and_return(mock_oauth_client)
    end

    context 'when code exchange succeeds' do
      before do
        allow(mock_oauth_client).to receive(:code=).with(auth_code)
        allow(mock_oauth_client).to receive(:fetch_access_token!)
      end

      it 'should exchange authorization code for access token' do
        result = oauth_service.exchange_code_for_token(auth_code)

        expect(result).to eq(mock_oauth_client)
      end
    end

    context 'when code exchange fails' do
      before do
        allow(mock_oauth_client).to receive(:code=).with(auth_code)
        allow(mock_oauth_client).to receive(:fetch_access_token!)
          .and_raise(StandardError, 'Invalid authorization code')
      end

      it 'should raise Infrastructure::ExternalServiceError' do
        expect { oauth_service.exchange_code_for_token(auth_code) }
          .to raise_error(Infrastructure::ExternalServiceError, /Failed to exchange token: Invalid authorization code/)
      end
    end
  end
end
