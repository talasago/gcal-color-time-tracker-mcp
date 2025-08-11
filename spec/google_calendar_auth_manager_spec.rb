require 'spec_helper'
require_relative '../lib/calendar_color_mcp/google_calendar_auth_manager'

describe CalendarColorMCP::GoogleCalendarAuthManager do
  let(:auth_manager) { CalendarColorMCP::GoogleCalendarAuthManager.instance }

  context "when using singleton pattern" do
    it "should return the same instance" do
      instance1 = CalendarColorMCP::GoogleCalendarAuthManager.instance
      instance2 = CalendarColorMCP::GoogleCalendarAuthManager.instance
      expect(instance1).to be(instance2)
    end

    it "should not allow direct instantiation" do
      expect { CalendarColorMCP::GoogleCalendarAuthManager.new }.to raise_error(NoMethodError)
    end
  end

  context "when managing authentication" do
    describe "#get_auth_url" do
      context "when environment variables are set" do
        before do
          ENV['GOOGLE_CLIENT_ID'] = 'test_client_id'
          ENV['GOOGLE_CLIENT_SECRET'] = 'test_client_secret'
        end

        it "should return a valid Google OAuth URL" do
          url = auth_manager.get_auth_url
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
    end
  end
end
