// 랜딩 모드 전환 — site-config.js의 releasePhase에 맞는 블록 하나만 보이게 합니다.
(function () {
  'use strict';

  var site = window.SITE || {};
  var phases = ['pre-register', 'beta', 'production'];
  var phase = phases.indexOf(site.releasePhase) >= 0 ? site.releasePhase : 'pre-register';

  var blocks = document.querySelectorAll('[data-phase]');
  for (var i = 0; i < blocks.length; i++) {
    blocks[i].hidden = blocks[i].getAttribute('data-phase') !== phase;
  }

  // 주소가 https로 시작하는 링크만 버튼으로 그립니다.
  var links = document.querySelectorAll('[data-link]');
  for (var j = 0; j < links.length; j++) {
    var url = site[links[j].getAttribute('data-link')];
    if (typeof url === 'string' && /^https:\/\//.test(url)) {
      links[j].href = url;
      links[j].rel = 'noopener';
      links[j].hidden = false;
    }
  }
})();
