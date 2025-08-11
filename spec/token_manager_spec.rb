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
    let(:mock_credentials) do
      double('credentials',
        access_token: 'test_access_token',
        refresh_token: 'test_refresh_token',
        expires_at: Time.now + 3600
      )
    end

    before do
      # テスト用のクリーンアップ
      token_manager.clear_credentials if token_manager.authenticated?

      # 環境変数のモック（デフォルトを設定してcall_originalを使用）
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('GOOGLE_CLIENT_ID').and_return('test_client_id')
      allow(ENV).to receive(:[]).with('GOOGLE_CLIENT_SECRET').and_return('test_client_secret')
      allow(ENV).to receive(:[]).with('DEBUG').and_return(nil)
    end

    after do
      # テスト後のクリーンアップ
      token_manager.clear_credentials if token_manager.authenticated?
    end

    describe "#authenticated?" do
      let(:invalid_credentials_no_access) do
        double('credentials',
          access_token: nil,
          refresh_token: 'test_refresh_token',
          expires_at: Time.now + 3600
        )
      end

      let(:invalid_credentials_no_refresh) do
        double('credentials',
          access_token: 'test_access_token',
          refresh_token: nil,
          expires_at: Time.now + 3600
        )
      end

      where(:case_name, :setup_action, :expected_result) do
        [
          ["no token file exists", :no_file, false], # File.exist?がfalseなので
          ["valid token file exists", :valid_file, "test_refresh_token"], # valid_token?が文字列を返す
          ["invalid token file exists", :invalid_file, false],
          ["credentials missing access token", :missing_access_token, nil],# access_tokenがnilなので
          ["credentials missing refresh token", :missing_refresh_token, nil]# refresh_tokenがnilなので
        ]
      end

      with_them do
        before do
          case setup_action
          when :valid_file
            token_manager.save_credentials(mock_credentials)
          when :invalid_file
            File.write(token_manager.instance_variable_get(:@token_file_path), "invalid json")
          when :missing_access_token
            token_manager.save_credentials(invalid_credentials_no_access)
          when :missing_refresh_token
            token_manager.save_credentials(invalid_credentials_no_refresh)
          # :no_file の場合は何もしない（デフォルト状態）
          end
        end

        it "should return #{params[:expected_result]} when #{params[:case_name]}" do
          expect(token_manager.authenticated?).to eq(expected_result)
        end
      end
    end

    describe "#save_credentials" do
      it "should save credentials to file" do
        token_manager.save_credentials(mock_credentials)

        expect(File.exist?(token_manager.instance_variable_get(:@token_file_path))).to be true

        saved_data = JSON.parse(File.read(token_manager.instance_variable_get(:@token_file_path)))
        expect(saved_data['access_token']).to eq('test_access_token')
        expect(saved_data['refresh_token']).to eq('test_refresh_token')
        expect(saved_data['expires_at']).to be_a(Integer)
        expect(saved_data['saved_at']).to be_a(Integer)
      end

      context "when file write fails" do
        before do
          allow(File).to receive(:write).and_raise(Errno::EACCES.new("Permission denied"))
        end

        it "should raise an error with descriptive message" do
          expect { token_manager.save_credentials(mock_credentials) }
            .to raise_error(/トークンファイルの書き込み権限エラー/)
        end
      end

      context "when other error occurs during save" do
        before do
          allow(File).to receive(:write).and_raise(StandardError.new("Unexpected error"))
        end

        it "should raise an error with descriptive message" do
          expect { token_manager.save_credentials(mock_credentials) }
            .to raise_error(/トークンファイルの保存エラー/)
        end
      end
    end

    describe "#load_credentials" do
      subject { token_manager.load_credentials }

      context "when no token file exists" do
        it { is_expected.to be nil }
      end

      context "when valid token file exists" do
        before do
          token_manager.save_credentials(mock_credentials)
        end

        it { is_expected.to be_a(Google::Auth::UserRefreshCredentials) }

        it "should have correct access_token" do
          expect(subject.access_token).to eq('test_access_token')
        end

        it "should have correct refresh_token" do
          expect(subject.refresh_token).to eq('test_refresh_token')
        end

        it "should set expires_at when present in token data" do
          expect(subject.expires_at).to be_a(Time)
        end
      end

      context "when token file contains invalid JSON" do
        before do
          File.write(token_manager.instance_variable_get(:@token_file_path), "invalid json")
        end

        it "should return nil and output error message" do
          expect { subject }
            .to output(/トークンファイルの読み込みエラー/).to_stdout

          expect(subject).to be nil
        end
      end

      context "when file read fails due to permissions" do
        before do
          token_manager.save_credentials(mock_credentials)
          allow(File).to receive(:read).with(token_manager.instance_variable_get(:@token_file_path))
            .and_raise(Errno::EACCES.new("Permission denied"))
        end

        it "should handle permission errors gracefully" do
          expect { subject }.to raise_error(Errno::EACCES)
        end
      end
    end

    describe "#last_auth_time" do
      context "when no token file exists" do
        it "should return nil" do
          expect(token_manager.last_auth_time).to be nil
        end
      end

      context "when valid token file exists" do
        before do
          token_manager.save_credentials(mock_credentials)
        end

        it "should return formatted timestamp" do
          auth_time = token_manager.last_auth_time

          expect(auth_time).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/)
        end
      end

      context "when token file is corrupted" do
        before do
          File.write(token_manager.instance_variable_get(:@token_file_path), "invalid json")
        end

        it "should return nil" do
          expect(token_manager.last_auth_time).to be nil
        end
      end
    end

    describe "#clear_credentials" do
      context "when token file exists" do
        before do
          token_manager.save_credentials(mock_credentials)
        end

        it "should delete the token file" do
          expect(File.exist?(token_manager.instance_variable_get(:@token_file_path))).to be true

          token_manager.clear_credentials

          expect(File.exist?(token_manager.instance_variable_get(:@token_file_path))).to be false
        end
      end

      context "when token file does not exist" do
        before do
          token_manager.clear_credentials
        end

        it "should not raise an error and file should remain non-existent" do
          expect { token_manager.clear_credentials }.not_to raise_error
          expect(File.exist?(token_manager.instance_variable_get(:@token_file_path))).to be false
        end
      end
    end
  end
end
