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
  var advance = null;      /* 「選んだら次へ」のタイマー。必ず1本だけ持つ */
  var lastStep = 0;        /* 結果へ進む直前に見せていた質問 */

  /* 対象の条件は3つ。県内であること、従業員9名以下であること、業種が
     理美容・飲食・バックオフィスのいずれかであること。どれかを外したら
     その時点で結論が出るので、選んだ選択肢に data-verdict を持たせて
     残りを聞かずに結果へ進む（答えても結論が変わらない質問を続けさせない）。

     3つを満たした人はいずれも対象なので、残りの2問は「どれだけ噛み合うか」
     の目安にしか使わない。満点は 10、条件を満たした時点で 6 は確定する。 */
  var FIT = 9;    /* これ以上なら、想定している事業者像とよく重なる */

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
    /* 打ち切り（県外など）で結果へ飛んだときは、最後に見せた質問が
       Q5 とは限らない。控えておかないと「前の質問へ戻る」で、
       本人がまだ見ていない質問に飛ばされる。 */
    lastStep = at;
    var s = score();
    var key = s.verdict ? s.verdict : (s.sum >= FIT ? 'fit' : 'maybe');

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
    window.clearTimeout(advance);
    form.reset();
    result.removeAttribute('role');
    /* 中の結果も畳んでおく。親を隠すだけだと、次の診断で別の結果を
       出したときに前回の結果が一緒に見えてしまう。 */
    results.forEach(function (r) { r.hidden = true; });
    show(0);
  }

  function open(from) {
    opener = from || null;
    /* 先に開くこと。showModal() の前は display:none なので、
       reset() の中の focus() が何もせずに終わり、実際の初期位置が
       ブラウザ既定（閉じるボタン）になってしまう。 */
    dlg.showModal();
    reset();
  }

  /* --- 選ぶと次へ進む ---
     「次へ」を押させると、5問で10回の操作になる。選んだ時点で進める。
     最後の質問だけは結果へ。 */
  form.addEventListener('change', function (e) {
    if (!e.target.matches('input[type="radio"]')) return;
    /* その場で結論が出る選択肢（県外）は、残りを聞かずに結果へ。
       答えが結果を変えないと分かっている質問を続けさせない。 */
    var decisive = e.target.hasAttribute('data-verdict');
    /* 前のタイマーを必ず捨てる。180ms 以内にもう一度選ぶと
       （矢印キーで選択肢を見て回ると必ず起きる）タイマーが2本走り、
       間の質問を飛ばしたまま結果へ進んでいた。飛ばされた質問は
       未回答のまま点数に数えられないので、操作の速さだけで
       「対象に当てはまりそうです」が「可能性があります」に化けた。 */
    window.clearTimeout(advance);
    advance = window.setTimeout(function () {
      advance = null;
      if (!decisive && at + 1 < TOTAL) show(at + 1); else finish();
    }, 180);   /* 選んだことが目に見えるだけの間を置く */
  });

  dlg.addEventListener('close', function () { window.clearTimeout(advance); });

  dlg.addEventListener('click', function (e) {
    var act = e.target.closest('[data-fc]');
    if (act) {
      var kind = act.getAttribute('data-fc');
      if (kind === 'close') { dlg.close(); return; }        /* リンクは既定の遷移も行う */
      if (kind === 'restart') { e.preventDefault(); reset(); return; }
      if (kind === 'back') {
        e.preventDefault();
        if (!result.hidden) { result.hidden = true; show(lastStep); }
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


/* ============================================================
   昼と夜の切り替え
   ============================================================
   ヒーローの名前に3秒マウスを乗せると、ページ全体が夜の海になる。
   もう一度3秒乗せると昼へ戻る。

   3秒待たせるのは、通し読みの途中でうっかり乗せただけでは変わって
   ほしくないため。名前の上をただ通り過ぎる動きは1秒に満たない。

   色そのものは CSS の .is-night が持っている（style.css の :root の
   すぐ下）。ここでやるのは付け外しだけ。検証ツールは :root の変数を
   読むので、色をこちら側に書いてはいけない。

   マウスの無い環境（スマホ・キーボード）では乗せる動作が起きないので、
   Enter / Space でも同じことができるようにしてある。 */
(function () {
  'use strict';
  var sw = document.querySelector('[data-nightswitch]');
  if (!sw) return;

  var HOLD = 3000;
  var timer = null;

  function toggle() {
    var night = document.documentElement.classList.toggle('is-night');
    sw.setAttribute('aria-pressed', night ? 'true' : 'false');
  }
  function start() {
    clearTimeout(timer);
    /* 数え始めたことを見せる。指で押さえている間は何の反応も無いと、
       3秒待つ理由が分からない（スマホでは「乗せ続ける」動作自体が
       目に見えないぶん、これが唯一の手がかりになる）。
       光は CSS 側で3秒かけて強まる。 */
    sw.classList.add('is-charging');
    timer = setTimeout(function () {
      sw.classList.remove('is-charging');
      toggle();
    }, HOLD);
  }
  function cancel() {
    clearTimeout(timer);
    timer = null;
    sw.classList.remove('is-charging');
  }

  /* 夜の絵は最初にマウスが乗った時点で読み込んでおく。切り替えの瞬間に
     取りに行くと、一拍おいて絵が差し替わる。ページを開いた時点で読むと、
     使わない人にも300KB余計に読ませることになるので、ここで読む。 */
  var warmed = false;
  function warm() {
    if (warmed) return;
    warmed = true;
    ['hero-night-wide.jpg', 'hero-night-mobile.jpg'].forEach(function (f) {
      new Image().src = 'assets/img/backgrounds/' + f;
    });
  }

  /* pointerenter / pointerleave は入れ子の要素で発火しない。
     mouseover だと画像と文字の境目でいちいち数え直しになる。 */
  sw.addEventListener('pointerenter', function () { warm(); start(); });
  sw.addEventListener('pointerleave', cancel);

  /* 指で押さえたままでも切り替わるようにする。

     タッチでは pointerenter / pointerleave が触れた瞬間と離した瞬間に
     ほぼ同時に起きるので、乗せ続ける仕掛けはそのままでは成立しない
     （実測でも touchstart のまま3.4秒待って切り替わらなかった）。
     touchstart で数え始め、指が動いたら（＝スクロールしたいだけ）やめる。

     passive: true にしてあるので、押さえている間もページは普通に動く。 */
  sw.addEventListener('touchstart', function () { warm(); start(); }, { passive: true });
  ['touchend', 'touchcancel', 'touchmove'].forEach(function (t) {
    sw.addEventListener(t, cancel, { passive: true });
  });

  /* キーボード。Enter / Space で切り替える。
     焦点を当てただけで数え始めてはいけない。Tab で辿って読んでいる
     だけの人が、3秒後に勝手にページ全体を夜にされてしまう。
     マウスの「乗せ続ける」は意図的な滞留だが、焦点の滞留は違う。 */
  sw.addEventListener('focus', warm);
  sw.addEventListener('blur', cancel);
  sw.addEventListener('keydown', function (e) {
    if (e.key !== 'Enter' && e.key !== ' ' && e.key !== 'Spacebar') return;
    e.preventDefault();
    cancel();
    toggle();
  });
})();
