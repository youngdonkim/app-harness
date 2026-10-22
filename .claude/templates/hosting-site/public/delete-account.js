// 계정 삭제 요청 폼 — 같은 사이트의 /api/deletion-request로 보냅니다.
//
// - Hosting이 이 주소를 서버 함수 deletionRequest로 넘깁니다(firebase.json의 hosting.rewrites).
//   함수가 이메일 형식·이유 길이를 다시 검사하고, 같은 이메일의 반복 요청을 거르고,
//   createdAt을 서버 시간으로 넣어 Firestore의 deletionRequests에 씁니다.
// - 이 페이지는 Firestore에 직접 쓰지 않습니다 — 웹 페이지에는 App Check 토큰이 없어,
//   Firestore의 App Check 강제를 켜면 직접 쓰기가 막히기 때문입니다. 보안 규칙도 이 컬렉션의 직접 쓰기를 막습니다.
// - 같은 사이트 주소라 프로젝트 값을 적지 않고, 개발용·실서비스용 어디에 올려도 그 프로젝트의 함수로 갑니다.
// - 아래 검사는 사람이 바로 고칠 수 있게 하려는 것이고, 막는 일은 서버 함수가 합니다.
//   길이·필드를 바꾸면 서버 함수(functions/src/deletion/)와 그 단위 테스트를 한 커밋에서 함께 고칩니다.
// - site-config.js의 deletionForm이 false면 폼을 숨기고 메일 안내만 보입니다.
(function () {
  'use strict';

  var site = window.SITE || {};
  var form = document.getElementById('deletion-form');
  var mailOnly = document.getElementById('mail-only');
  var statusEl = document.getElementById('form-status');

  if (!site.deletionForm) {
    mailOnly.hidden = false;
    return;
  }
  form.hidden = false;

  var EMAIL_MAX = 320;
  var REASON_MAX = 500;
  var EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  function setStatus(text, kind) {
    statusEl.textContent = text;
    statusEl.className = 'status' + (kind ? ' ' + kind : '');
  }

  function send(email, reason, website) {
    return fetch('/api/deletion-request', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: email, reason: reason, website: website }),
    }).then(function (res) {
      if (!res.ok) throw new Error('send ' + res.status);
    });
  }

  form.addEventListener('submit', function (event) {
    event.preventDefault();
    var button = form.querySelector('button[type="submit"]');
    var email = form.email.value.trim();
    var reason = form.reason.value.trim();

    // 봇이 채우는 빈칸 — 사람은 볼 수 없어 비어 있습니다. 채워졌으면 서버 함수가 받은 척만 합니다.
    var website = form.website.value;
    if (!email || email.length > EMAIL_MAX || !EMAIL_RE.test(email)) {
      setStatus('이메일 주소를 다시 확인해 주세요.', 'error');
      form.email.focus();
      return;
    }
    if (reason.length > REASON_MAX) {
      setStatus('이유는 ' + REASON_MAX + '자 안으로 적어 주세요.', 'error');
      form.reason.focus();
      return;
    }

    button.disabled = true;
    setStatus('보내는 중입니다…');
    send(email, reason, website)
      .then(function () {
        form.reset();
        setStatus('요청을 받았습니다. 본인 확인 메일을 보내 드리겠습니다.', 'ok');
      })
      .catch(function () {
        setStatus('요청을 보내지 못했습니다. 잠시 뒤 다시 시도하거나 ' +
          (site.contactEmail || '문의 메일') + '로 보내 주세요.', 'error');
      })
      .then(function () { button.disabled = false; });
  });
})();
