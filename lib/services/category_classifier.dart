// category_classifier.dart
// 할 일 제목(todoText)을 받아서 자동으로 카테고리를 분류하는 함수
// 주요 카테고리 분류 기준 및 해당 키워드 예시
// - 시험: 중간고사, 기말고사, 시험 관련 키워드가 포함된 경우
// - 과제: 과제, 레포트, 보고서, 리포트 관련 키워드가 포함된 경우
// - 팀플: 팀플 키워드가 포함된 경우
// - 기타: 위의 조건에 모두 해당하지 않는 경우 기본 분류

String classifyCategory(String todoText) {
  // 입력된 텍스트를 모두 소문자로 변환해 대소문자 구분 없이 검사
  final lowerText = todoText.toLowerCase();

  // 시험 관련 키워드가 포함되어 있으면 '시험' 반환
  if (lowerText.contains('중간고사') ||
      lowerText.contains('기말고사') ||
      lowerText.contains('시험')) {
    return '시험';

    // 과제 관련 키워드가 포함되어 있으면 '과제' 반환
  } else if (lowerText.contains('과제') ||
      lowerText.contains('레포트') ||
      lowerText.contains('보고서') ||
      lowerText.contains('리포트')) {
    return '과제';

    // 팀플 키워드가 포함되어 있으면 '팀플' 반환
  } else if (lowerText.contains('팀플')) {
    return '팀플';

    // 위 어느 조건에도 해당하지 않으면 기본값 '기타' 반환
  } else {
    return '기타';
  }
}
