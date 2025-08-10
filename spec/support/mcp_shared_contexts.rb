RSpec.shared_context 'authenticated user' do
  let(:mock_auth_manager) do
    instance_double('CalendarColorMCP::GoogleCalendarAuthManager').tap do |mock|
      allow(mock).to receive(:authenticated?).and_return(true)
      allow(mock).to receive(:get_auth_url).and_return('https://accounts.google.com/oauth2/auth?client_id=...')
    end
  end

  let(:server_context) { { auth_manager: mock_auth_manager } }
end

RSpec.shared_context 'unauthenticated user' do
  let(:mock_auth_manager) do
    instance_double('CalendarColorMCP::GoogleCalendarAuthManager').tap do |mock|
      allow(mock).to receive(:authenticated?).and_return(false)
      allow(mock).to receive(:get_auth_url).and_return('https://accounts.google.com/oauth2/auth?client_id=...')
    end
  end

  let(:server_context) { { auth_manager: mock_auth_manager } }
end

RSpec.shared_context 'calendar analysis setup' do
  include_context 'authenticated user'

  let(:mock_calendar_client) do
    instance_double('CalendarColorMCP::GoogleCalendarClient').tap do |mock|
      allow(mock).to receive(:get_events).and_return([])
    end
  end

  let(:server_context) { { auth_manager: mock_auth_manager, calendar_client: mock_calendar_client } }

  before do
    allow(CalendarColorMCP::GoogleCalendarClient).to receive(:new).and_return(mock_calendar_client)
    
    mock_analyzer = instance_double('CalendarColorMCP::TimeAnalyzer')
    mock_filter = instance_double('CalendarColorMCP::ColorFilterManager')
    
    allow(CalendarColorMCP::TimeAnalyzer).to receive(:new).and_return(mock_analyzer)
    allow(CalendarColorMCP::ColorFilterManager).to receive(:new).and_return(mock_filter)
    
    allow(mock_analyzer).to receive(:analyze).and_return({
      color_breakdown: {},
      summary: { total_hours: 0, total_events: 0 }
    })
    allow(mock_filter).to receive(:get_filtering_summary).and_return({ has_filters: false })
  end
end