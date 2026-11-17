/// 小说模块数据模型（对齐 Web `src/api/novel/types.ts`）。
library;

class NovelItem {
  const NovelItem({
    required this.novelID,
    required this.title,
    this.authorID = 0,
    this.authorName = '',
    this.coverURL = '',
    this.category = '',
    this.intro = '',
    this.status = '',
    this.chapterNum = 0,
    this.wordNum = 0,
    this.readNum = 0,
    this.shelfNum = 0,
    this.commentNum = 0,
    this.coinNum = 0,
    this.ratingCount = 0,
    this.ratingAvg = 0,
    this.myCoins = 0,
    this.myRating = 0,
    this.latestChapterID = 0,
    this.latestChapterTitle = '',
    this.latestChapterAt,
    this.createdAt = '',
    this.updatedAt = '',
    this.onShelf = false,
    this.progressPercent = 0,
    this.progressChapterID = 0,
    this.progressChapterNum = 0,
  });

  final int novelID;
  final String title;
  final int authorID;
  final String authorName;
  final String coverURL;
  final String category;
  final String intro;
  final String status;
  final int chapterNum;
  final int wordNum;
  final int readNum;
  final int shelfNum;
  final int commentNum;
  final int coinNum;
  final int ratingCount;
  final double ratingAvg;
  final int myCoins;
  final int myRating;
  final int latestChapterID;
  final String latestChapterTitle;
  final String? latestChapterAt;
  final String createdAt;
  final String updatedAt;
  final bool onShelf;
  final double progressPercent;
  final int progressChapterID;
  final int progressChapterNum;

  factory NovelItem.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return NovelItem(
      novelID: _int(map['novelID'] ?? map['NovelID']),
      title: _str(map['title'] ?? map['Title']),
      authorID: _int(map['authorID'] ?? map['AuthorID']),
      authorName: _str(map['authorName'] ?? map['AuthorName']),
      coverURL: _str(map['coverURL'] ?? map['CoverURL']),
      category: _str(map['category'] ?? map['Category']),
      intro: _str(map['intro'] ?? map['Intro']),
      status: _str(map['status'] ?? map['Status']),
      chapterNum: _int(map['chapterNum'] ?? map['ChapterNum']),
      wordNum: _int(map['wordNum'] ?? map['WordNum']),
      readNum: _int(map['readNum'] ?? map['ReadNum']),
      shelfNum: _int(map['shelfNum'] ?? map['ShelfNum']),
      commentNum: _int(map['commentNum'] ?? map['CommentNum']),
      coinNum: _int(map['coinNum'] ?? map['CoinNum']),
      ratingCount: _int(map['ratingCount'] ?? map['RatingCount']),
      ratingAvg: _double(map['ratingAvg'] ?? map['RatingAvg']),
      myCoins: _int(map['myCoins'] ?? map['MyCoins']),
      myRating: _int(map['myRating'] ?? map['MyRating']),
      latestChapterID:
          _int(map['latestChapterID'] ?? map['LatestChapterID']),
      latestChapterTitle:
          _str(map['latestChapterTitle'] ?? map['LatestChapterTitle']),
      latestChapterAt: _nullableStr(
          map['latestChapterAt'] ?? map['LatestChapterAt']),
      createdAt: _str(map['createdAt'] ?? map['CreatedAt']),
      updatedAt: _str(map['updatedAt'] ?? map['UpdatedAt']),
      onShelf: map['onShelf'] == true || map['OnShelf'] == true,
      progressPercent:
          _double(map['progressPercent'] ?? map['ProgressPercent']),
      progressChapterID:
          _int(map['progressChapterID'] ?? map['ProgressChapterID']),
      progressChapterNum:
          _int(map['progressChapterNum'] ?? map['ProgressChapterNum']),
    );
  }
}

class NovelCategory {
  const NovelCategory({required this.name, required this.count});

  final String name;
  final int count;

  factory NovelCategory.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return NovelCategory(
      name: _str(map['name'] ?? map['Name']),
      count: _int(map['count'] ?? map['Count']),
    );
  }
}

class NovelChapter {
  const NovelChapter({
    required this.chapterID,
    required this.novelID,
    required this.chapterNum,
    required this.title,
    this.wordNum = 0,
    this.commentNum = 0,
    this.readNum = 0,
    this.createdAt = '',
  });

  final int chapterID;
  final int novelID;
  final int chapterNum;
  final String title;
  final int wordNum;
  final int commentNum;
  final int readNum;
  final String createdAt;

  factory NovelChapter.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return NovelChapter(
      chapterID: _int(map['chapterID'] ?? map['ChapterID']),
      novelID: _int(map['novelID'] ?? map['NovelID']),
      chapterNum: _int(map['chapterNum'] ?? map['ChapterNum']),
      title: _str(map['title'] ?? map['Title']),
      wordNum: _int(map['wordNum'] ?? map['WordNum']),
      commentNum: _int(map['commentNum'] ?? map['CommentNum']),
      readNum: _int(map['readNum'] ?? map['ReadNum']),
      createdAt: _str(map['createdAt'] ?? map['CreatedAt']),
    );
  }
}

class NovelParagraph {
  const NovelParagraph({
    required this.index,
    required this.text,
    this.imageURL = '',
    this.commentNum = 0,
  });

  final int index;
  final String text;
  final String imageURL;
  final int commentNum;

  bool get isImage => imageURL.isNotEmpty;

  factory NovelParagraph.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return NovelParagraph(
      index: _int(map['index'] ?? map['Index']),
      text: _str(map['text'] ?? map['Text']),
      imageURL: _str(map['imageURL'] ?? map['ImageURL']),
      commentNum: _int(map['commentNum'] ?? map['CommentNum']),
    );
  }
}

class NovelAdjacent {
  const NovelAdjacent({
    required this.chapterID,
    required this.chapterNum,
    required this.title,
  });

  final int chapterID;
  final int chapterNum;
  final String title;

  factory NovelAdjacent.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return NovelAdjacent(
      chapterID: _int(map['chapterID'] ?? map['ChapterID']),
      chapterNum: _int(map['chapterNum'] ?? map['ChapterNum']),
      title: _str(map['title'] ?? map['Title']),
    );
  }
}

class NovelChapterDetail {
  const NovelChapterDetail({
    required this.chapter,
    required this.novelID,
    required this.novelTitle,
    required this.authorName,
    required this.paragraphs,
    this.authorNote = '',
    this.prev,
    this.next,
    this.onShelf = false,
    this.progressPercent = 0,
  });

  final NovelChapter chapter;
  final int novelID;
  final String novelTitle;
  final String authorName;
  final List<NovelParagraph> paragraphs;
  final String authorNote;
  final NovelAdjacent? prev;
  final NovelAdjacent? next;
  final bool onShelf;
  final double progressPercent;

  factory NovelChapterDetail.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    final chapter = NovelChapter.fromDynamic(map['chapter']);
    final paragraphs = map['paragraphs'];
    return NovelChapterDetail(
      chapter: chapter,
      novelID: _int(map['novelID'] ?? map['NovelID']) == 0
          ? chapter.novelID
          : _int(map['novelID'] ?? map['NovelID']),
      novelTitle: _str(map['novelTitle'] ?? map['NovelTitle']),
      authorName: _str(map['authorName'] ?? map['AuthorName']),
      paragraphs: paragraphs is List
          ? paragraphs
              .map(NovelParagraph.fromDynamic)
              .toList(growable: false)
          : const <NovelParagraph>[],
      authorNote: _str(map['authorNote'] ?? map['AuthorNote']),
      prev: map['prev'] == null && map['Prev'] == null
          ? null
          : NovelAdjacent.fromDynamic(map['prev'] ?? map['Prev']),
      next: map['next'] == null && map['Next'] == null
          ? null
          : NovelAdjacent.fromDynamic(map['next'] ?? map['Next']),
      onShelf: map['onShelf'] == true || map['OnShelf'] == true,
      progressPercent:
          _double(map['progressPercent'] ?? map['ProgressPercent']),
    );
  }
}

class NovelComment {
  const NovelComment({
    required this.commentID,
    required this.novelID,
    this.chapterID = 0,
    this.paragraphIndex = 0,
    this.targetType = 'book',
    this.paragraphExcerpt = '',
    this.authorID = 0,
    this.author = '',
    this.authorTelephone = '',
    this.authorScore = 0,
    this.authorAvatar = '',
    this.authorIdentity = '',
    this.commentTime = '',
    this.content = '',
    this.isRating = false,
    this.likeNum = 0,
    this.isLiked = false,
  });

  final int commentID;
  final int novelID;
  final int chapterID;
  final int paragraphIndex;
  final String targetType;
  final String paragraphExcerpt;
  final int authorID;
  final String author;
  final String authorTelephone;
  final int authorScore;
  final String authorAvatar;
  final String authorIdentity;
  final String commentTime;
  final String content;
  final bool isRating;
  final int likeNum;
  final bool isLiked;

  factory NovelComment.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return NovelComment(
      commentID: _int(map['commentID'] ?? map['CommentID']),
      novelID: _int(map['novelID'] ?? map['NovelID']),
      chapterID: _int(map['chapterID'] ?? map['ChapterID']),
      paragraphIndex: _int(map['paragraphIndex'] ?? map['ParagraphIndex']),
      targetType: _str(map['targetType'] ?? map['TargetType']).isEmpty
          ? 'book'
          : _str(map['targetType'] ?? map['TargetType']),
      paragraphExcerpt:
          _str(map['paragraphExcerpt'] ?? map['ParagraphExcerpt']),
      authorID: _int(map['authorID'] ?? map['AuthorID']),
      author: _str(map['author'] ?? map['Author']),
      authorTelephone:
          _str(map['authorTelephone'] ?? map['AuthorTelephone']),
      authorScore: _int(map['authorScore'] ?? map['AuthorScore']),
      authorAvatar: _str(map['authorAvatar'] ?? map['AuthorAvatar']),
      authorIdentity: _str(map['authorIdentity'] ?? map['AuthorIdentity']),
      commentTime: _str(map['commentTime'] ?? map['CommentTime']),
      content: _str(map['content'] ?? map['Content']),
      isRating: map['isRating'] == true || map['IsRating'] == true,
      likeNum: _int(map['likeNum'] ?? map['LikeNum']),
      isLiked: map['isLiked'] == true || map['IsLiked'] == true,
    );
  }
}

class NovelPointsSummary {
  const NovelPointsSummary({
    required this.experience,
    required this.pointsFen,
    required this.pointsScore,
    required this.todayExp,
    required this.checkInDay,
    required this.checkInStreak,
    required this.byEvent,
  });

  final int experience;
  final int pointsFen;
  final int pointsScore;
  final int todayExp;
  final String checkInDay;
  final int checkInStreak;
  final List<NovelPointsEvent> byEvent;

  factory NovelPointsSummary.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    final list = map['byEvent'];
    return NovelPointsSummary(
      experience: _int(map['experience']),
      pointsFen: _int(map['pointsFen']),
      pointsScore: _int(map['pointsScore']),
      todayExp: _int(map['todayExp']),
      checkInDay: _str(map['checkInDay']),
      checkInStreak: _int(map['checkInStreak']),
      byEvent: list is List
          ? list.map(NovelPointsEvent.fromDynamic).toList(growable: false)
          : const <NovelPointsEvent>[],
    );
  }
}

class NovelPointsEvent {
  const NovelPointsEvent({
    required this.event,
    required this.label,
    required this.currency,
    required this.amount,
  });

  final String event;
  final String label;
  final String currency;
  final int amount;

  factory NovelPointsEvent.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return NovelPointsEvent(
      event: _str(map['event']),
      label: _str(map['label']),
      currency: _str(map['currency']),
      amount: _int(map['amount']),
    );
  }
}

class NovelLedgerItem {
  const NovelLedgerItem({
    required this.ledgerID,
    required this.novelID,
    required this.event,
    required this.label,
    required this.currency,
    required this.amount,
    required this.settledValue,
    required this.createdAt,
  });

  final int ledgerID;
  final int novelID;
  final String event;
  final String label;
  final String currency;
  final int amount;
  final int settledValue;
  final String createdAt;

  factory NovelLedgerItem.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return NovelLedgerItem(
      ledgerID: _int(map['ledgerID']),
      novelID: _int(map['novelID']),
      event: _str(map['event']),
      label: _str(map['label']),
      currency: _str(map['currency']),
      amount: _int(map['amount']),
      settledValue: _int(map['settledValue']),
      createdAt: _str(map['createdAt']),
    );
  }
}

class NovelCheckInResult {
  const NovelCheckInResult({
    required this.amount,
    required this.streak,
    required this.day,
    required this.already,
  });

  final int amount;
  final int streak;
  final String day;
  final bool already;

  factory NovelCheckInResult.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return NovelCheckInResult(
      amount: _int(map['amount']),
      streak: _int(map['streak']),
      day: _str(map['day']),
      already: map['already'] == true,
    );
  }
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _str(dynamic value) => value?.toString() ?? '';

String? _nullableStr(dynamic value) {
  if (value == null) return null;
  final s = value.toString();
  return s.isEmpty ? null : s;
}