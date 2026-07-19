class FriendInfo {
  final String uid;
  final String displayName;
  final int overallStreak;
  final int sharedStreak;
  final String? sharedLastDate;
  final bool friendDoneToday;
  final String pairId;
  final String? photoUrl;

  FriendInfo({
    required this.uid,
    required this.displayName,
    required this.overallStreak,
    required this.sharedStreak,
    this.sharedLastDate,
    required this.friendDoneToday,
    required this.pairId,
    this.photoUrl,
  });
}
