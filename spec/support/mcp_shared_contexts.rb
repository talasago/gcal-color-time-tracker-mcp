RSpec.shared_context 'authenticated user' do
  let(:mock_oauth_service) do
    instance_double('Infrastructure::GoogleOAuthService').tap do |mock|
      allow(mock).to receive(:generate_auth_url).and_return('https://accounts.google.com/oauth2/auth?client_id=...')
      allow(mock).to receive(:exchange_code_for_token).and_return({
        access_token: 'mock_access_token',
        refresh_token: 'mock_refresh_token',
        expires_in: 3600
      })
    end
  end

  let(:mock_token_repository) do
    instance_double('Infrastructure::TokenRepository').tap do |mock|
      allow(mock).to receive(:token_exist?).and_return(true)
      allow(mock).to receive(:token_file_exists?).and_return(true)
      allow(mock).to receive(:save_credentials).and_return(true)
    end
  end


  let(:server_context) {
    {
      oauth_service: mock_oauth_service,
      token_repository: mock_token_repository
    }
  }
end

RSpec.shared_context 'unauthenticated user' do
  let(:mock_oauth_service) do
    instance_double('Infrastructure::GoogleOAuthService').tap do |mock|
      allow(mock).to receive(:generate_auth_url).and_return('https://accounts.google.com/oauth2/auth?client_id=...')
      allow(mock).to receive(:exchange_code_for_token).and_return({
        access_token: 'mock_access_token',
        refresh_token: 'mock_refresh_token',
        expires_in: 3600
      })
    end
  end

  let(:mock_token_repository) do
    instance_double('Infrastructure::TokenRepository').tap do |mock|
      allow(mock).to receive(:token_exist?).and_return(false)
      allow(mock).to receive(:token_file_exists?).and_return(false)
      allow(mock).to receive(:save_credentials).and_return(true)
    end
  end

  let(:server_context) {
    {
      oauth_service: mock_oauth_service,
      token_repository: mock_token_repository,
    }
  }
end

RSpec.shared_context 'calendar analysis setup' do
  include_context 'authenticated user'

  let(:mock_calendar_repository) do
    instance_double('Infrastructure::GoogleCalendarRepository').tap do |mock|
      allow(mock).to receive(:fetch_events).and_return([])
      allow(mock).to receive(:get_user_email).and_return('test@example.com')
    end
  end

  let(:server_context) {
    {
      oauth_service: mock_oauth_service,
      token_repository: mock_token_repository,
      calendar_repository: mock_calendar_repository,
    }
  }
end
