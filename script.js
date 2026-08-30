/* script.js ― 対象診断のポップアップ

   このLPで唯一のJavaScript。ページの見た目や本文には一切関わらない。
   質問・選択肢・結果の文言はすべて index.html にあり、ここがするのは
   「どれを表示するか」と「点数を数えること」だけ。

   JSが動かない環境では、呼び出しボタンは素の <a href="#entry"> として
   お申し込みセクションへ飛ぶ。診断が使えないだけで、導線は切れない。

   判定の内容は現時点の想定です。最終的な対象可否は県・事務局の
   確認が前提で、結果画面にもその旨を明記しています。 */
(function () {
  'use strict';

  var dlg = document.getElementById('fitcheck');
  if (!dlg || typeof dlg.showModal !== 'function') return;   /* 未対応なら何もしない */

  var form    = dlg.querySelector('[data-fc="form"]');
  var steps   = Array.prototype.slice.call(dlg.querySelectorAll('.fc-step'));
  var prog    = dlg.querySelector('[data-fc="prog"]');
  var result  = dlg.querySelector('[data-fc="result"]');
  var backBtn = dlg.querySelector('[data-fc="back"]');
  var results = Array.prototype.slice.call(dlg.querySelectorAll('.fc-res'));

  var TOTAL = steps.length;
  var at = 0;              /* いま表示している質問の番号（0始まり） */
  var opener = null;       /* 閉じたときにフォーカスを返す先 */

  /* 満点は 10。しきい値は「広島県内であること」を満たした上での目安。 */
  var FIT = 8;    /* これ以上なら、想定している事業者像とよく重なる */
  var MAYBE = 5;  /* これ以上なら、可能性あり */

  function show(i) {
    at = i;
    steps.forEach(function (s, k) { s.hidden = (k !== i); });
    result.hidden = true;
    prog.hidden = false;
    prog.textContent = '質問 ' + (i + 1) + ' / ' + TOTAL;
    backBtn.hidden = (i === 0);
    /* 新しい質問の最初の選択肢へフォーカスを移す。
       これが無いと、キーボードだけで進めたときに現在地を見失う。 */
    var first = steps[i].querySelector('input[type="radio"]');
    if (first) first.focus();
  }

  function score() {
    var sum = 0, verdict = null, answered = 0;
    steps.forEach(function (s) {
      var picked = s.querySelector('input[type="radio"]:checked');
      if (!picked) return;
      answered++;
      sum += parseInt(picked.getAttribute('data-score'), 10) || 0;
      if (picked.getAttribute('data-verdict')) verdict = picked.getAttribute('data-verdict');
    });
    return { sum: sum, verdict: verdict, answered: answered };
  }

  function finish() {
    var s = score();
    var key = s.verdict ? s.verdict
            : s.sum >= FIT ? 'fit'
            : s.sum >= MAYBE ? 'maybe'
            : 'far';

    steps.forEach(function (st) { st.hidden = true; });
    prog.hidden = true;
    backBtn.hidden = false;
    results.forEach(function (r) { r.hidden = (r.getAttribute('data-res') !== key); });
    result.hidden = false;
    /* 結果は見出しではないので、読み上げを促すために明示的に知らせる。
       hidden を外したあとに設定しないと、変化として拾われないことがある。 */
    result.setAttribute('role', 'status');
    var verdictEl = result.querySelector('.fc-res:not([hidden]) .fc-verdict');
    if (verdictEl) {
      verdictEl.setAttribute('tabindex', '-1');
      verdictEl.focus();
    }
  }

  function reset() {
    form.reset();
    result.removeAttribute('role');
    /* 中の結果も畳んでおく。親を隠すだけだと、次の診断で別の結果を
       出したときに前回の結果が一緒に見えてしまう。 */
    results.forEach(function (r) { r.hidden = true; });
    show(0);
  }

  function open(from) {
    opener = from || null;
    reset();
    dlg.showModal();
  }

  /* --- 選ぶと次へ進む ---
     「次へ」を押させると、5問で10回の操作になる。選んだ時点で進める。
     最後の質問だけは結果へ。 */
  form.addEventListener('change', function (e) {
    if (!e.target.matches('input[type="radio"]')) return;
    /* その場で結論が出る選択肢（県外）は、残りを聞かずに結果へ。
       答えが結果を変えないと分かっている質問を続けさせない。 */
    var decisive = e.target.hasAttribute('data-verdict');
    window.setTimeout(function () {
      if (!decisive && at + 1 < TOTAL) show(at + 1); else finish();
    }, 180);   /* 選んだことが目に見えるだけの間を置く */
  });

  dlg.addEventListener('click', function (e) {
    var act = e.target.closest('[data-fc]');
    if (act) {
      var kind = act.getAttribute('data-fc');
      if (kind === 'close') { dlg.close(); return; }        /* リンクは既定の遷移も行う */
      if (kind === 'restart') { e.preventDefault(); reset(); return; }
      if (kind === 'back') {
        e.preventDefault();
        if (!result.hidden) { result.hidden = true; show(TOTAL - 1); }
        else if (at > 0) show(at - 1);
        return;
      }
    }
    /* 枠の外側を押したら閉じる。dialog 自身の領域は余白まで含むので、
       中身（.fc-inner）の外を押したかどうかで見分ける。 */
    if (!e.target.closest('.fc-inner')) dlg.close();
  });

  dlg.addEventListener('close', function () {
    if (opener && document.contains(opener)) opener.focus();
  });

  /* --- 呼び出し --- */
  document.addEventListener('click', function (e) {
    var trigger = e.target.closest('[data-fitcheck]');
    if (!trigger) return;
    e.preventDefault();
    open(trigger);
  });
})();
