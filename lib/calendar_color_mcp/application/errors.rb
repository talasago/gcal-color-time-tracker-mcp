module Application
  # 基底エラー
  class ApplicationError < StandardError; end
  
  # ビジネスロジック実行エラー（Use Case、ワークフロー関連）
  class BusinessLogicError < ApplicationError; end
  
  # 認証・認可エラー（ユーザー認証、権限関連）
  class AuthenticationError < ApplicationError; end
  
  # データ検証エラー（入力データ、ビジネスルール検証関連）
  class ValidationError < ApplicationError; end
  
  # 既存のエラークラス（後方互換性のため残す）
  class UseCaseError < StandardError; end
  class AuthenticationRequiredError < UseCaseError; end
  class CalendarAccessError < UseCaseError; end
  class InvalidParameterError < UseCaseError; end
end