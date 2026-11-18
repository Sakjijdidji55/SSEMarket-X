/// 原生化升级开关。
///
/// 用 `--dart-define=NATIVE_RANKING=false` 可以临时切回旧的小程序页面，
/// 默认只打开已经完成验收的页面。
class NativeUpgradeFlags {
  const NativeUpgradeFlags._();

  /// 排行榜（第一个原生化样板页）。
  static const bool ranking = bool.fromEnvironment(
    'NATIVE_RANKING',
    defaultValue: false,
  );

  /// 后续页面完成验收后再逐个打开。
  static const bool media = bool.fromEnvironment(
    'NATIVE_MEDIA',
    defaultValue: true,
  );
  static const bool novel = bool.fromEnvironment(
    'NATIVE_NOVEL',
    defaultValue: true,
  );
  static const bool resume = bool.fromEnvironment(
    'NATIVE_RESUME',
    defaultValue: false,
  );
  static const bool course = bool.fromEnvironment(
    'NATIVE_COURSE',
    defaultValue: false,
  );
}