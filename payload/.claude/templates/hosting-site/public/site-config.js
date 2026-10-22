// 웹 페이지 설정 — 이 파일 하나만 고쳐 랜딩 모드와 연락처를 바꿉니다.
//
// releasePhase(출시 단계)
//   'pre-register' — 사전 등록 중: 「곧 나옵니다」 + (있으면) 플레이 사전 등록 버튼
//   'beta'         — 비공개 테스트 중: 「지금은 시험 중입니다」 + (있으면) 시험 참가 링크
//   'production'   — 정식 출시: 플레이 스토어 버튼
//
// deletionForm
//   false — 계정 삭제 요청을 문의 메일로만 받습니다(3단계 — Firestore가 아직 없을 때)
//   true  — 계정 삭제 요청 폼을 엽니다(4단계 — 서버 함수 deletionRequest와 Hosting 재작성 규칙이 나간 뒤)
//
// 값을 바꾸면 백엔드 출시(backend-release)로 Hosting만 다시 내보냅니다.
window.SITE = {
  releasePhase: 'pre-register',
  appName: '<앱 이름>',
  developerName: '<개발자 이름>', // 플레이 스토어에 보이는 이름 그대로
  contactEmail: '<문의 메일>',
  // 비워 두면 그 버튼을 그리지 않습니다.
  playStoreUrl: '', // 정식 출시·사전 등록: https://play.google.com/store/apps/details?id=<패키지 이름>
  betaJoinUrl: '', // 비공개 테스트 참가 링크(플레이 콘솔에서 복사)
  deletionForm: false,
};
