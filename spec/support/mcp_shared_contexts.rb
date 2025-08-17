RSpec.shared_context 'authenticated user' do
  let(:mock_auth_manager) do
    instance_double('GoogleCalendarAuthManager').tap do |mock|
      allow(mock).to receive(:token_exist?).and_return(true)
      allow(mock).to receive(:get_auth_url).and_return('https://accounts.google.com/oauth2/auth?client_id=...')
    end
  end

  let(:server_context) { { auth_manager: mock_auth_manager } }
end

RSpec.shared_context 'unauthenticated user' do
  let(:mock_auth_manager) do
    instance_double('GoogleCalendarAuthManager').tap do |mock|
      allow(mock).to receive(:token_exist?).and_return(false)
      allow(mock).to receive(:get_auth_url).and_return('https://accounts.google.com/oauth2/auth?client_id=...')
    end
  end

  let(:server_context) { { auth_manager: mock_auth_manager } }
end

RSpec.shared_context 'calendar analysis setup' do
  include_context 'authenticated user'

  let(:mock_token_manager) do
    instance_double('TokenManager').tap do |mock|
      allow(mock).to receive(:token_exist?).and_return(true)
    end
  end

  let(:mock_calendar_repository) do
    instance_double('GoogleCalendarRepository').tap do |mock|
      allow(mock).to receive(:fetch_events).and_return([])
      allow(mock).to receive(:get_user_email).and_return('test@example.com')
    end
  end


  let(:server_context) {
    {
      auth_manager: mock_auth_manager,
      token_manager: mock_token_manager,
      calendar_repository: mock_calendar_repository
    }
  }


end
