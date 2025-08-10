require 'spec_helper'
require_relative '../lib/calendar_color_mcp/simple_auth_manager'

describe CalendarColorMCP::SimpleAuthManager do
  let(:auth_manager) { CalendarColorMCP::SimpleAuthManager.instance }

  context "when using singleton pattern" do
    it "should return the same instance" do
      instance1 = CalendarColorMCP::SimpleAuthManager.instance
      instance2 = CalendarColorMCP::SimpleAuthManager.instance
      expect(instance1).to be(instance2)
    end

    it "should not allow direct instantiation" do
      expect { CalendarColorMCP::SimpleAuthManager.new }.to raise_error(NoMethodError)
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
          expect(url).to include('https://accounts.google.com/o/oauth2/auth')
          expect(url).to include('client_id=test_client_id')
          expect(url).to include('response_type=code')
        end
      end
    end
  end
end
