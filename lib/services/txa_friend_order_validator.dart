class TXAFriendOrderValidator {
  static final TXAFriendOrderValidator instance = TXAFriendOrderValidator._internal();
  TXAFriendOrderValidator._internal();

  /// Kiểm tra xem việc kéo thả từ oldIndex sang newIndex trong danh sách hiển thị có hợp lệ hay không.
  /// Trả về một translation key của TXALanguage nếu không hợp lệ, hoặc null nếu hợp lệ.
  String? validateReorder({
    required List<Map<String, dynamic>> friendsList,
    required int oldIndex,
    required int newIndex,
    bool isPremiumUser = false,
  }) {
    if (isPremiumUser) {
      return null; // Thuê bao Premium được kéo thả tự do
    }

    if (oldIndex < 0 || oldIndex >= friendsList.length) return null;
    if (newIndex < 0 || newIndex >= friendsList.length) return null;

    final draggedFriend = friendsList[oldIndex];
    final targetFriend = friendsList[newIndex];

    final isDraggedBest = draggedFriend['isBestFriend'] == true;
    final isDraggedLover = draggedFriend['isLover'] == true;
    final isDraggedNormal = !isDraggedBest && !isDraggedLover;

    final isTargetBest = targetFriend['isBestFriend'] == true;
    final isTargetLover = targetFriend['isLover'] == true;
    final isTargetNormal = !isTargetBest && !isTargetLover;

    // Hướng kéo: newIndex < oldIndex là kéo lên, newIndex > oldIndex là kéo xuống

    // RULE 1: Không được kéo bạn bình thường lên trên người yêu hoặc bạn thân
    if (isDraggedNormal && (isTargetBest || isTargetLover)) {
      if (newIndex < oldIndex) {
        return 'cannot_drag_normal_above_priority';
      }
    }

    // RULE 2: Không được kéo bạn thân xuống dưới người yêu hoặc bạn bình thường
    if (isDraggedBest && (isTargetLover || isTargetNormal)) {
      if (newIndex > oldIndex) {
        return 'cannot_drag_best_below_priority';
      }
    }

    // RULE 3: Không được kéo người yêu lên trên bạn thân (vì bạn thân luôn ở đầu)
    if (isDraggedLover && isTargetBest) {
      if (newIndex < oldIndex) {
        return 'cannot_drag_lover_above_best';
      }
    }

    // RULE 4: Không được kéo người yêu xuống dưới bạn bè bình thường
    if (isDraggedLover && isTargetNormal) {
      if (newIndex > oldIndex) {
        return 'cannot_drag_lover_below_normal';
      }
    }

    return null;
  }
}
