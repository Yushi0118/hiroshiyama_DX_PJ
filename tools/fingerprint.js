/* tools/fingerprint.js ― 見た目の指紋を採る

   CSSを整理するとき、「効いていないはずの宣言」を消したつもりが実は
   効いていた、という事故がいちばん怖い。目で見比べても、1978行の
   スタイルのうちどこが動いたかは分からない。

   そこで、ページ上の要素の「計算済みの値」をまとめて文字列にしておき、
   整理の前後で突き合わせる。差が 0 なら、見た目は変わっていない。

   使い方（ブラウザのコンソール）:
     const t = await fetch('tools/fingerprint.js').then(r=>r.text()); eval(t);
     const before = __fingerprint();        // 整理する前に採る
     … CSSを直す …
     const after  = __fingerprint();
     __fpDiff(before, after);               // 差の一覧（空なら同じ）

   要素は「セレクタごとに最初の数個」を見る。全部を見ると量が多すぎるし、
   同じ規則から色を受け取っているものは1つ見れば足りる。 */
'use strict';

window.__fingerprint = function () {
  var SELECTORS = [
    'body', 'main', '.wrap',
    'h1', 'h2', 'h2 .h-rule', '.lead', '.eyebrow',
    '.card', '.tier-shallow .card', '.tier-mid .card', '.tier-deep .card',
    '.card-title', '.card p', '.num', '.vignette', '.theme-head', '.theme-name', '.theme-icon',
    '.note', '.checklist', '.checklist li', '.checklist .sub',
    '.btn', '.btn-primary', '.btn-ghost', '.btn-accent',
    '.cta', '.cta-sub', '.cta-badge', '.chev', '.sticky-cta',
    '.hero-panel', '.hero-title', '.hero-sub', '.hero-lead', '.hero-brand', '.hero-brand span',
    '.hero-nav a', '.hero-art',
    '.timeline .card', '.tl-when', '.tl-step', '.tl-date', '.tl-body',
    '.nodes .card', '.hub-center', '.hub-center span',
    '.faq-item', '.faq-item summary', '.faq-item p',
    '.site-footer', '.foot-nav a', '.foot-top a', '.lockup-item', '.lockup-name', '.credit-note',
    '.creature', '.creatures', '.deep-zone',
    '.fc', '.fc-inner', '.fc-head', '.fc-title', '.fc-step', '.fc-choice', '.fc-note', '.fc-close', '.fc-back'
  ];

  /* 見るのは「目に見える結果」だけ。transform は揺れで毎回変わるので外す。 */
  var PROPS = [
    'color', 'background-color', 'background-image', 'background-size', 'background-position',
    'box-shadow', 'border-top-width', 'border-right-width', 'border-bottom-width', 'border-left-width',
    'border-top-color', 'border-left-color', 'border-radius',
    'font-size', 'font-weight', 'font-family', 'line-height', 'letter-spacing', 'text-align',
    'padding-top', 'padding-right', 'padding-bottom', 'padding-left',
    'margin-top', 'margin-right', 'margin-bottom', 'margin-left',
    'width', 'height', 'max-width', 'min-height', 'display', 'position', 'z-index',
    'opacity', 'mix-blend-mode', 'overflow', 'gap', 'align-items', 'justify-content'
  ];

  var out = {};
  SELECTORS.forEach(function (sel) {
    var els;
    try { els = document.querySelectorAll(sel); } catch (e) { return; }
    /* 同じ規則から値をもらう仲間は1つ見れば足りるので、先頭3つまで。 */
    Array.prototype.slice.call(els, 0, 3).forEach(function (el, i) {
      var cs = getComputedStyle(el);
      var row = {};
      PROPS.forEach(function (p) { row[p] = cs.getPropertyValue(p); });
      /* 大きさは実測も入れる（変数の置き換えで幅が変わる事故を拾う） */
      var r = el.getBoundingClientRect();
      row['__rect'] = Math.round(r.width) + 'x' + Math.round(r.height);
      out[sel + '#' + i] = row;
    });
  });

  /* ページ全体の丈も見る。ここが動いたら、どこかで組み直っている。 */
  out['__page'] = { height: document.documentElement.scrollHeight, width: innerWidth };
  return out;
};

window.__fpDiff = function (a, b) {
  var diffs = [];
  var keys = Object.keys(a);
  Object.keys(b).forEach(function (k) { if (keys.indexOf(k) < 0) keys.push(k); });
  keys.forEach(function (k) {
    var x = a[k], y = b[k];
    if (!x) { diffs.push(k + ' … 前には無かった'); return; }
    if (!y) { diffs.push(k + ' … 後で消えた'); return; }
    Object.keys(x).forEach(function (p) {
      if (String(x[p]) !== String(y[p])) diffs.push(k + ' / ' + p + ': ' + x[p] + ' → ' + y[p]);
    });
  });
  return diffs;
};
