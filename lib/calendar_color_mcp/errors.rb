module CalendarColorMCP
  # カレンダークライアント関連のカスタム例外クラス
  class CalendarError < StandardError
    def initialize(message)
      super(message)
    end
  end

  # 認証が必要または無効な場合の例外
  class AuthenticationError < CalendarError
    def initialize(message = "認証が必要です")
      super(message)
    end
  end

  # カレンダーAPIアクセスエラー
  class CalendarApiError < CalendarError
    def initialize(message = "カレンダーAPIアクセスエラー")
      super(message)
    end
  end
end