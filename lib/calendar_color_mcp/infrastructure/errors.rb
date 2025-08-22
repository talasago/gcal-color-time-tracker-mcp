module Infrastructure
  # 基底エラー
  class InfrastructureError < StandardError; end
  
  # 外部サービス連携エラー（Google Calendar API等）
  class ExternalServiceError < InfrastructureError; end
  
  # 設定・構成エラー（環境変数、設定ファイル等）  
  class ConfigurationError < InfrastructureError; end
  
  # データ処理エラー（ファイルI/O、フィルタリング等）
  class DataProcessingError < InfrastructureError; end
end
