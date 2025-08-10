require 'spec_helper'
require_relative '../lib/calendar_color_mcp/token_manager'

describe CalendarColorMCP::TokenManager do
  let(:token_manager) { CalendarColorMCP::TokenManager.instance }

  context "when using singleton pattern" do
    it "should return the same instance" do
      instance1 = CalendarColorMCP::TokenManager.instance
      instance2 = CalendarColorMCP::TokenManager.instance
      expect(instance1).to be(instance2)
    end

    it "should not allow direct instantiation" do
      expect { CalendarColorMCP::TokenManager.new }.to raise_error(NoMethodError)
    end
  end

  context "when managing tokens" do
    before do
      # テスト用のクリーンアップ
      token_manager.clear_credentials if token_manager.authenticated?
    end

    after do
      # テスト後のクリーンアップ
      token_manager.clear_credentials if token_manager.authenticated?
    end

    describe "#authenticated?" do
      context "when no token file exists" do
        it "should return false" do
          expect(token_manager.authenticated?).to be false
        end
      end
    end

    describe "#last_auth_time" do
      context "when no token file exists" do
        it "should return nil" do
          expect(token_manager.last_auth_time).to be nil
        end
      end
    end
  end
end