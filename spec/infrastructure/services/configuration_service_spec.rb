require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/infrastructure/services/configuration_service'

describe Infrastructure::ConfigurationService do
  around do |example|
    # 環境変数を一時的に保存・復元
    original_client_id = ENV['GOOGLE_CLIENT_ID']
    original_client_secret = ENV['GOOGLE_CLIENT_SECRET']

    example.run

    ENV['GOOGLE_CLIENT_ID'] = original_client_id
    ENV['GOOGLE_CLIENT_SECRET'] = original_client_secret
  end

  # Singletonインスタンスをテスト間でリセット
  after do
    Infrastructure::ConfigurationService.instance_variable_set(:@singleton__instance__, nil)
  end

  describe '#initialize' do
    context 'when environment variables are properly set' do
      before do
        ENV['GOOGLE_CLIENT_ID'] = 'test_client_id'
        ENV['GOOGLE_CLIENT_SECRET'] = 'test_client_secret'
      end

      it 'should not raise an error' do
        expect { Infrastructure::ConfigurationService.instance }.not_to raise_error
      end
    end

    context 'when environment variables are missing' do
      where(:client_id, :client_secret, :expected_error) do
        [
          [nil, 'test_client_secret', /Missing required environment variables: GOOGLE_CLIENT_ID/],
          ['test_client_id', nil, /Missing required environment variables: GOOGLE_CLIENT_SECRET/],
          [nil, nil, /Missing required environment variables: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET/],
          ['', '', /Missing required environment variables: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET/]
        ]
      end

      with_them do
        before do
          ENV['GOOGLE_CLIENT_ID'] = client_id
          ENV['GOOGLE_CLIENT_SECRET'] = client_secret
        end

        it 'should raise an error' do
          expect { Infrastructure::ConfigurationService.instance }.to raise_error(expected_error)
        end
      end
    end
  end

  describe '#google_client_id' do
    context 'when GOOGLE_CLIENT_ID is set' do
      before do
        ENV['GOOGLE_CLIENT_ID'] = 'test_client_id'
        ENV['GOOGLE_CLIENT_SECRET'] = 'test_client_secret'
      end

      subject(:config) { Infrastructure::ConfigurationService.instance }

      it 'should return the client ID' do
        expect(config.google_client_id).to eq('test_client_id')
      end

      it 'should cache the value' do
        expect(ENV).to receive(:fetch).with('GOOGLE_CLIENT_ID').once.and_return('test_client_id')
        
        2.times { config.google_client_id }
      end
    end
  end

  describe '#google_client_secret' do
    context 'when GOOGLE_CLIENT_SECRET is set' do
      before do
        ENV['GOOGLE_CLIENT_ID'] = 'test_client_id'
        ENV['GOOGLE_CLIENT_SECRET'] = 'test_client_secret'
      end

      subject(:config) { Infrastructure::ConfigurationService.instance }

      it 'should return the client secret' do
        expect(config.google_client_secret).to eq('test_client_secret')
      end

      it 'should cache the value' do
        expect(ENV).to receive(:fetch).with('GOOGLE_CLIENT_SECRET').once.and_return('test_client_secret')
        
        2.times { config.google_client_secret }
      end
    end
  end
end