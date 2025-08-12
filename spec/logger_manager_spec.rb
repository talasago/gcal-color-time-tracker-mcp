require 'spec_helper'
require 'tmpdir'
require 'fileutils'

describe CalendarColorMCP::LoggerManager do
  let(:temp_dir) { Dir.mktmpdir }
  
  # Arrange: テストごとに新しいSingletonインスタンスを使用
  before do
    described_class.instance_variable_set(:@singleton__instance__, nil)
    allow_any_instance_of(described_class).to receive(:log_directory_path).and_return(temp_dir)
  end
  
  after do
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
    described_class.instance_variable_set(:@singleton__instance__, nil)
  end

  describe "#initialize" do
    subject { described_class.instance }
    
    context "when logs directory does not exist" do
      before do
        FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
      end
      
      it "should create logs directory" do
        subject
        expect(Dir.exist?(temp_dir)).to be true
      end
    end
    
    context "when logs directory exists" do
      before do
        FileUtils.mkdir_p(temp_dir)
      end
      
      it "should not raise error" do
        expect { subject }.not_to raise_error
      end
    end
    
    it "should create log file with daily rotation" do
      subject
      log_file = File.join(temp_dir, 'calendar_color_mcp.log')
      expect(File.exist?(log_file)).to be true
    end
  end

  describe "log level determination" do
    subject { described_class.instance }
    
    context "when RSPEC_RUNNING is true" do
      before do
        allow(ENV).to receive(:[]).with('RSPEC_RUNNING').and_return('true')
        allow(ENV).to receive(:[]).with('RAILS_ENV').and_return(nil)
        allow(ENV).to receive(:[]).with('RACK_ENV').and_return(nil)
        allow(ENV).to receive(:[]).with('DEBUG').and_return(nil)
      end
      
      it "should set FATAL log level" do
        expect(subject.logger.level).to eq(Logger::FATAL)
      end
    end
    
    context "when DEBUG is true" do
      before do
        allow(ENV).to receive(:[]).with('RSPEC_RUNNING').and_return(nil)
        allow(ENV).to receive(:[]).with('RAILS_ENV').and_return(nil)
        allow(ENV).to receive(:[]).with('RACK_ENV').and_return(nil)
        allow(ENV).to receive(:[]).with('DEBUG').and_return('true')
      end
      
      it "should set DEBUG log level" do
        expect(subject.logger.level).to eq(Logger::DEBUG)
      end
    end
    
    context "when DEBUG is not set" do
      before do
        allow(ENV).to receive(:[]).with('RSPEC_RUNNING').and_return(nil)
        allow(ENV).to receive(:[]).with('RAILS_ENV').and_return(nil)
        allow(ENV).to receive(:[]).with('RACK_ENV').and_return(nil)
        allow(ENV).to receive(:[]).with('DEBUG').and_return(nil)
      end
      
      it "should set INFO log level" do
        expect(subject.logger.level).to eq(Logger::INFO)
      end
    end
  end

  describe "log output methods" do
    let(:log_file) { File.join(temp_dir, 'calendar_color_mcp.log') }
    
    before do
      allow(ENV).to receive(:[]).with('RSPEC_RUNNING').and_return(nil)
      allow(ENV).to receive(:[]).with('RAILS_ENV').and_return(nil)
      allow(ENV).to receive(:[]).with('RACK_ENV').and_return(nil)
      allow(ENV).to receive(:[]).with('DEBUG').and_return('true')
    end
    
    subject { described_class.instance }
    
    context "when logging debug message" do
      it "should write debug message to file" do
        subject.debug('test debug message')
        content = File.read(log_file)
        expect(content).to include('DEBUG: test debug message')
      end
    end
    
    context "when logging info message" do
      it "should write info message to file" do
        subject.info('test info message')
        content = File.read(log_file)
        expect(content).to include('INFO: test info message')
      end
    end
    
    context "when logging warn message" do
      it "should write warn message to file" do
        subject.warn('test warn message')
        content = File.read(log_file)
        expect(content).to include('WARN: test warn message')
      end
    end
    
    context "when logging error message" do
      it "should write error message to file" do
        subject.error('test error message')
        content = File.read(log_file)
        expect(content).to include('ERROR: test error message')
      end
    end
  end

  describe "log format" do
    let(:log_file) { File.join(temp_dir, 'calendar_color_mcp.log') }
    
    before do
      allow(ENV).to receive(:[]).with('RSPEC_RUNNING').and_return(nil)
      allow(ENV).to receive(:[]).with('RAILS_ENV').and_return(nil)
      allow(ENV).to receive(:[]).with('RACK_ENV').and_return(nil)
      allow(ENV).to receive(:[]).with('DEBUG').and_return('true')
    end
    
    subject { described_class.instance }
    
    context "when message is logged" do
      it "should format with timestamp and level" do
        subject.info('test message')
        content = File.read(log_file)
        expect(content).to match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] INFO: test message/)
      end
    end
  end

  describe "singleton behavior" do
    subject { described_class.instance }
    
    context "when called multiple times" do
      let(:instance1) { described_class.instance }
      let(:instance2) { described_class.instance }
      
      it "should return same instance" do
        expect(instance1).to be(instance2)
      end
    end
  end

  describe "error handling" do
    context "when directory creation fails" do
      before do
        allow(Dir).to receive(:exist?).and_return(false)
        allow(FileUtils).to receive(:mkdir_p).and_raise(Errno::EACCES, 'Permission denied')
      end
      
      it "should raise permission error" do
        expect { described_class.instance }.to raise_error(Errno::EACCES)
      end
    end
    
    context "when log file creation fails" do
      before do
        allow(Logger).to receive(:new).and_raise(Errno::EACCES, 'Permission denied')
      end
      
      it "should raise permission error" do
        expect { described_class.instance }.to raise_error(Errno::EACCES)
      end
    end
  end

  describe "integration with environment variables" do
    let(:log_file) { File.join(temp_dir, 'calendar_color_mcp.log') }
    
    context "when in production mode" do
      before do
        allow(ENV).to receive(:[]).with('RSPEC_RUNNING').and_return(nil)
        allow(ENV).to receive(:[]).with('RAILS_ENV').and_return(nil)
        allow(ENV).to receive(:[]).with('RACK_ENV').and_return(nil)
        allow(ENV).to receive(:[]).with('DEBUG').and_return(nil)
      end
      
      subject { described_class.instance }
      
      context "when debug message is logged" do
        it "should not write debug message" do
          subject.debug('debug message')
          content = File.read(log_file)
          expect(content).not_to include('DEBUG: debug message')
        end
      end
      
      context "when info message is logged" do
        it "should write info message" do
          subject.info('info message')
          content = File.read(log_file)
          expect(content).to include('INFO: info message')
        end
      end
    end
  end
end