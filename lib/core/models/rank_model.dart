/// 排行榜（投币口径）数据模型。
///
/// 后端接口：
/// - `GET /auth/postRanking` → `{ code, data: { ranking: [...] } }`
/// - `GET /auth/userRanking` → `{ code, data: { ranking: [...] } }`
class PostRankItem {
  const PostRankItem({
    required this.postID,
    required this.title,
    required this.partition,
    required this.coinNum,
    required this.postTime,
  });

  final int postID;
  final String title;
  final String partition;
  final int coinNum;
  final String postTime;

  factory PostRankItem.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return PostRankItem(
      postID: _int(map['postID'] ?? map['PostID']),
      title: _string(map['title'] ?? map['Title']),
      partition: _string(map['partition'] ?? map['Partition']),
      coinNum: _int(map['coinNum'] ?? map['CoinNum']),
      postTime: _string(map['postTime'] ?? map['PostTime']),
    );
  }
}

class UserRankItem {
  const UserRankItem({
    required this.userID,
    required this.userName,
    required this.avatarURL,
    required this.receivedCoins,
  });

  final int userID;
  final String userName;
  final String avatarURL;
  final int receivedCoins;

  factory UserRankItem.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return UserRankItem(
      userID: _int(map['userID'] ?? map['UserID']),
      userName: _string(map['userName'] ?? map['UserName']),
      avatarURL: _string(map['avatarURL'] ?? map['AvatarURL']),
      receivedCoins: _int(map['receivedCoins'] ?? map['ReceivedCoins']),
    );
  }
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _string(dynamic value) => value?.toString() ?? '';