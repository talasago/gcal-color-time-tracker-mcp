# frozen_string_literal: true

require_relative '../../spec_helper'

describe Infrastructure::TokenRepository do
  subject(:token_repository) { Infrastructure::TokenRepository.instance }

  let(:mock_credentials) do
    instance_double(Google::Auth::UserRefreshCredentials).tap do |mock|
      allow(mock).to receive(:access_token).and_return('test_access_token')
      allow(mock).to receive(:refresh_token).and_return('test_refresh_token')
      allow(mock).to receive(:expires_at).and_return(Time.now + 3600)
      allow(mock).to receive(:expires_at=)
    end
  end

  before do
    # 環境変数を設定してConfigurationServiceが正常に動作するようにする
    ENV['GOOGLE_CLIENT_ID'] = 'test_client_id'
    ENV['GOOGLE_CLIENT_SECRET'] = 'test_client_secret'

    # テスト前にトークンファイルをクリア
    begin
      token_repository.clear_credentials
    rescue
      # ファイルが存在しない場合は無視
    end
  end

  after do
    # テスト後にトークンファイルをクリア
    begin
      token_repository.clear_credentials
    rescue
      # エラーが発生しても無視
    end

    # 環境変数をクリア
    ENV.delete('GOOGLE_CLIENT_ID')
    ENV.delete('GOOGLE_CLIENT_SECRET')
  end

  context "when using singleton pattern" do
    it "should return the same instance" do
      instance1 = Infrastructure::TokenRepository.instance
      instance2 = Infrastructure::TokenRepository.instance
      expect(instance1).to be(instance2)
    end

    it "should not allow direct instantiation" do
      expect { Infrastructure::TokenRepository.new }.to raise_error(NoMethodError)
    end
  end

  describe '#save_credentials' do
    it 'should save credentials to token file' do
      token_repository.save_credentials(mock_credentials)

      expect(token_repository.token_exist?).to be true
    end

    it 'should handle file write errors gracefully' do
      allow(File).to receive(:write).and_raise(Errno::EACCES, 'Permission denied')

      expect { token_repository.save_credentials(mock_credentials) }
        .to raise_error(/Token file write permission error/)
    end

    context "when other error occurs during save" do
      before do
        allow(File).to receive(:write).and_raise(StandardError.new("Unexpected error"))
      end

      it "should raise an error with descriptive message" do
        expect { token_repository.save_credentials(mock_credentials) }
          .to raise_error(/Token file save error/)
      end
    end
  end

  describe '#load_credentials' do
    context 'when token file exists' do
      before do
        token_repository.save_credentials(mock_credentials)
      end

      it 'should load credentials from token file' do
        allow(Google::Auth::UserRefreshCredentials).to receive(:new)
          .and_return(mock_credentials)

        credentials = token_repository.load_credentials

        expect(credentials).to eq(mock_credentials)
        expect(Google::Auth::UserRefreshCredentials).to have_received(:new)
          .with(hash_including(
            client_id: 'test_client_id',
            client_secret: 'test_client_secret'
          ))
      end
    end

    context 'when token file does not exist' do
      it 'should return nil' do
        credentials = token_repository.load_credentials

        expect(credentials).to be_nil
      end
    end

    context 'when token file is corrupted' do
      before do
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:read).and_return('invalid json')
      end

      it 'should return nil for corrupted file' do
        credentials = token_repository.load_credentials

        expect(credentials).to be_nil
      end
    end

    context "when file read fails due to permissions" do
      before do
        token_repository.save_credentials(mock_credentials)
        allow(File).to receive(:read).and_raise(Errno::EACCES.new("Permission denied"))
      end

      after do
        # 権限エラーのテストでは通常のクリーンアップをスキップ
        allow(File).to receive(:read).and_call_original
        token_repository.clear_credentials rescue nil
      end

      it "should raise RuntimeError with descriptive message" do
        expect { token_repository.load_credentials }.to raise_error(RuntimeError, /Failed to access token file/)
      end
    end
  end

  describe '#token_exist?' do
    let(:invalid_credentials_no_access) do
      instance_double(Google::Auth::UserRefreshCredentials).tap do |mock|
        allow(mock).to receive(:access_token).and_return(nil)
        allow(mock).to receive(:refresh_token).and_return('test_refresh_token')
        allow(mock).to receive(:expires_at).and_return(Time.now + 3600)
        allow(mock).to receive(:expires_at=)
      end
    end

    let(:invalid_credentials_no_refresh) do
      instance_double(Google::Auth::UserRefreshCredentials).tap do |mock|
        allow(mock).to receive(:access_token).and_return('test_access_token')
        allow(mock).to receive(:refresh_token).and_return(nil)
        allow(mock).to receive(:expires_at).and_return(Time.now + 3600)
        allow(mock).to receive(:expires_at=)
      end
    end

    where(:case_name, :setup_action, :expected_result) do
      [
        ["no token file exists", :no_file, false],
        ["valid token file exists", :valid_file, true],
        ["invalid token file exists", :invalid_file, false],
        ["credentials missing access token", :missing_access_token, true],
        ["credentials missing refresh token", :missing_refresh_token, true]
      ]
    end

    with_them do
      before do
        case setup_action
        when :valid_file
          token_repository.save_credentials(mock_credentials)
        when :invalid_file
          File.write(token_repository.instance_variable_get(:@token_file_path), "invalid json")
        when :missing_access_token
          token_repository.save_credentials(invalid_credentials_no_access)
        when :missing_refresh_token
          token_repository.save_credentials(invalid_credentials_no_refresh)
        # :no_file の場合は何もしない（デフォルト状態）
        end
      end

      it "should return #{params[:expected_result]} when #{params[:case_name]}" do
        expect(token_repository.token_exist?).to eq(expected_result)
      end
    end

    context 'when load_credentials raises error' do
      before do
        allow(token_repository).to receive(:load_credentials).and_raise(StandardError)
      end

      it 'should return false' do
        expect(token_repository.token_exist?).to be false
      end
    end
  end

  describe '#clear_credentials' do
    context "when token file exists" do
      before do
        token_repository.save_credentials(mock_credentials)
      end

      it 'should remove token file' do
        expect(token_repository.token_exist?).to be true

        token_repository.clear_credentials

        expect(token_repository.token_exist?).to be false
      end
    end

    context "when token file does not exist" do
      before do
        token_repository.clear_credentials
      end

      it "should not raise an error and file should remain non-existent" do
        expect { token_repository.clear_credentials }.not_to raise_error
        expect(token_repository.token_exist?).to be false
      end
    end
  end
end
