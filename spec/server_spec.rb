require 'spec_helper'
require_relative '../lib/calendar_color_mcp/server'

describe CalendarColorMCP::Server do
  around do |example|
    # 環境変数を一時的に保存・復元
    original_client_id = ENV['GOOGLE_CLIENT_ID']
    original_client_secret = ENV['GOOGLE_CLIENT_SECRET']

    example.run

    ENV['GOOGLE_CLIENT_ID'] = original_client_id
    ENV['GOOGLE_CLIENT_SECRET'] = original_client_secret
    
    # ConfigurationServiceのSingletonインスタンスをリセット（テスト間の分離）
    begin
      Infrastructure::ConfigurationService.send(:remove_instance_variable, :@singleton__instance__)
    rescue NameError
      # インスタンス変数が存在しない場合は無視
    end
  end

  before do
    # モック設定: 外部依存を分離
    allow(Infrastructure::TokenRepository).to receive(:instance).and_return(double('TokenRepository'))
  end

  describe '#initialize' do
    context 'when environment variables are properly set' do
      before do
        ENV['GOOGLE_CLIENT_ID'] = 'test_client_id'
        ENV['GOOGLE_CLIENT_SECRET'] = 'test_client_secret'
      end

      let(:mock_mcp_server) { double('MCP::Server') }

      before do
        allow(MCP::Server).to receive(:new).and_return(mock_mcp_server)
      end

      it 'should not raise an error' do
        expect { CalendarColorMCP::Server.new }.not_to raise_error
      end
    end

    context 'when environment variables are missing' do
      where(:client_id, :client_secret, :expected_error) do
        [
          [nil, 'test_client_secret', /必要な環境変数が設定されていません: GOOGLE_CLIENT_ID/],
          ['test_client_id', nil, /必要な環境変数が設定されていません: GOOGLE_CLIENT_SECRET/],
          [nil, nil, /必要な環境変数が設定されていません: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET/],
          ['', '', /必要な環境変数が設定されていません: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET/]
        ]
      end

      with_them do
        before do
          ENV['GOOGLE_CLIENT_ID'] = client_id
          ENV['GOOGLE_CLIENT_SECRET'] = client_secret
        end

        it 'should raise an error' do
          expect { CalendarColorMCP::Server.new }.to raise_error(expected_error)
        end
      end
    end
  end
end
