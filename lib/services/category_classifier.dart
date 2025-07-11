// category_classifier.dart
// 할 일 제목을 기반으로 카테고리를 자동 분류하는 함수
/// 주요 분류 예시 및 키워드:
/// - 시험: 중간고사, 기말고사, 시험
/// - 과제: 레포트, 보고서,리포트
/// - 팀플: 팀플
/// - 기타: 위에 해당하지 않는 모든 내용
///
///   /// 할 일 제목을 분석해 카테고리를 자동 분류하는 함수
/// - 입력: 할 일 제목 (String)
/// - 출력: 분류된 카테고리명 (String)
String classifyCategory(String todoText) {
  final lowerText = todoText.toLowerCase();

  if (lowerText.contains('중간고사') ||
      lowerText.contains('기말고사') ||
      lowerText.contains('시험')) {
    return '시험';
  } else if (lowerText.contains('과제') ||
      lowerText.contains('레포트') ||
      lowerText.contains('보고서') ||
      lowerText.contains('리포트')) {
    return '과제';
  } else if (lowerText.contains('팀플')) {
    return '팀플';
  } else {
    return '기타';
  }
}
