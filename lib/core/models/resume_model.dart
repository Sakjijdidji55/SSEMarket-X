/// 简历模型（对齐 Web `src/api/resume/types.ts`）。
class ResumeItem {
  const ResumeItem({
    required this.resumeID,
    this.userID = 0,
    this.uploader = '',
    this.title = '',
    this.description = '',
    this.fileName = '',
    this.fileSize = 0,
    this.mimeType = '',
    this.fileExt = '',
    this.downloadNum = 0,
    this.viewNum = 0,
    this.isAnonymous = false,
    this.isOwner = false,
    this.canPreview = false,
    this.createdAt = '',
  });

  final int resumeID;
  final int userID;
  final String uploader;
  final String title;
  final String description;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String fileExt;
  final int downloadNum;
  final int viewNum;
  final bool isAnonymous;
  final bool isOwner;
  final bool canPreview;
  final String createdAt;

  bool get isImage {
    const exts = <String>{'jpg', 'jpeg', 'png', 'webp', 'gif'};
    return exts.contains(fileExt.toLowerCase());
  }

  factory ResumeItem.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw : const <String, dynamic>{};
    return ResumeItem(
      resumeID: _int(map['resumeID'] ?? map['ResumeID']),
      userID: _int(map['userID'] ?? map['UserID']),
      uploader: _str(map['uploader'] ?? map['Uploader']),
      title: _str(map['title'] ?? map['Title']),
      description: _str(map['description'] ?? map['Description']),
      fileName: _str(map['fileName'] ?? map['FileName']),
      fileSize: _int(map['fileSize'] ?? map['FileSize']),
      mimeType: _str(map['mimeType'] ?? map['MimeType']),
      fileExt: _str(map['fileExt'] ?? map['FileExt']),
      downloadNum: _int(map['downloadNum'] ?? map['DownloadNum']),
      viewNum: _int(map['viewNum'] ?? map['ViewNum']),
      isAnonymous: map['isAnonymous'] == true || map['IsAnonymous'] == true,
      isOwner: map['isOwner'] == true || map['IsOwner'] == true,
      canPreview: map['canPreview'] == true || map['CanPreview'] == true,
      createdAt: _str(map['createdAt'] ?? map['CreatedAt']),
    );
  }
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _str(dynamic value) => value?.toString() ?? '';