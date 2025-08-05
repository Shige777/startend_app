class RateLimiter {
  static final Map<String, List<DateTime>> _actionHistory = {};
  
  /// レート制限をチェック
  static bool canPerformAction(String actionKey, {
    int maxActions = 10,
    Duration timeWindow = const Duration(minutes: 1),
  }) {
    final now = DateTime.now();
    final cutoff = now.subtract(timeWindow);
    
    // 既存の履歴を取得またはCreate
    final history = _actionHistory[actionKey] ?? [];
    
    // 古い記録を削除
    history.removeWhere((timestamp) => timestamp.isBefore(cutoff));
    
    // 制限をチェック
    if (history.length >= maxActions) {
      return false;
    }
    
    // 新しいアクションを記録
    history.add(now);
    _actionHistory[actionKey] = history;
    
    return true;
  }
  
  /// 特定のアクションの残り時間を取得
  static Duration? getResetTime(String actionKey, {
    int maxActions = 10,
    Duration timeWindow = const Duration(minutes: 1),
  }) {
    final history = _actionHistory[actionKey] ?? [];
    if (history.length < maxActions) {
      return null;
    }
    
    final oldestAction = history.first;
    final resetTime = oldestAction.add(timeWindow);
    final now = DateTime.now();
    
    if (resetTime.isAfter(now)) {
      return resetTime.difference(now);
    }
    
    return null;
  }
  
  /// 投稿作成制限
  static bool canCreatePost(String userId) {
    return canPerformAction(
      'create_post_$userId',
      maxActions: 10,
      timeWindow: const Duration(hours: 24),
    );
  }
  
  /// いいね制限
  static bool canLikePost(String userId) {
    return canPerformAction(
      'like_post_$userId',
      maxActions: 100,
      timeWindow: const Duration(hours: 1),
    );
  }
  
  /// フォロー制限
  static bool canFollow(String userId) {
    return canPerformAction(
      'follow_$userId',
      maxActions: 50,
      timeWindow: const Duration(hours: 1),
    );
  }
  
  /// 検索制限
  static bool canSearch(String userId) {
    return canPerformAction(
      'search_$userId',
      maxActions: 100,
      timeWindow: const Duration(minutes: 10),
    );
  }
  
  /// コメント制限
  static bool canComment(String userId) {
    return canPerformAction(
      'comment_$userId',
      maxActions: 50,
      timeWindow: const Duration(hours: 1),
    );
  }
}