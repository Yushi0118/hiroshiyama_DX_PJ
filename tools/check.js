/* tools/check.js ― ブラウザで実行する自動検証。
   コンソールで __check() を呼ぶと、合否と落ちた項目が返る。

   使い方:
     fetch('tools/check.js').then(r=>r.text()).then(t=>{eval(t);console.log(__check())})

   判定するもの:
     1. 文字と背景のコントラスト比（WCAG 2.1 AA）
     2. 横スクロールの発生
     3. タップ領域の大きさ
     4. 画像に文字が入っていないか
     5. 絶対パス（GitHub Pages のサブディレクトリ配信で壊れる） */
window.__check = function () {
  const F = [];

  /* --- 相対輝度とコントラスト比（WCAG 2.1 の定義そのまま） --- */
  const lum = (r, g, b) => {
    const f = c => { c /= 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
  };
  const parse = s => (s.match(/[\d.]+/g) || []).map(Number);

  /* 半透明の色を下地に合成する。カードは rgba で敷くことが多く、
     合成後の実効色で測らないと判定が実態とずれる。 */
  const over = (fg, bg) => {
    const a = fg[3] === undefined ? 1 : fg[3];
    return [0, 1, 2].map(i => Math.round(fg[i] * a + bg[i] * (1 - a)));
  };

  /* 祖先をたどって背景色を積み上げる。透明なら親へ、を繰り返す。 */
  const bgOf = el => {
    const stack = [];
    for (let n = el; n && n !== document.documentElement; n = n.parentElement) {
      const c = parse(getComputedStyle(n).backgroundColor);
      if (c.length >= 3 && (c[3] === undefined || c[3] > 0.01)) stack.push(c);
      if (c.length >= 3 && (c[3] === undefined || c[3] >= 0.999)) break;
    }
    // ページ全体の下地。深度グラデーションは body::before なので取得できない。
    // 取れない場合は body の背景色を最終下地として使う。
    let acc = parse(getComputedStyle(document.body).backgroundColor);
    if (!(acc.length >= 3) || acc[3] === 0) acc = [255, 255, 255];
    acc = acc.slice(0, 3);
    for (let i = stack.length - 1; i >= 0; i--) acc = over(stack[i], acc);
    return acc;
  };

  const ratio = (a, b) => {
    const l1 = lum(a[0], a[1], a[2]), l2 = lum(b[0], b[1], b[2]);
    return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
  };

  /* --- 1. コントラスト --- */
  const texts = [...document.querySelectorAll('p, li, h1, h2, h3, h4, a, .eyebrow, .btn, .num, strong, dt, dd')]
    .filter(el => el.textContent.trim() && el.offsetParent !== null && el.getClientRects().length);
  const low = [];
  texts.forEach(el => {
    const cs = getComputedStyle(el);
    const size = parseFloat(cs.fontSize);
    const bold = parseInt(cs.fontWeight, 10) >= 700;
    const need = (size >= 24 || (size >= 18.66 && bold)) ? 3 : 4.5;
    const r = ratio(parse(cs.color).slice(0, 3), bgOf(el));
    if (r < need) low.push({ r: +r.toFixed(2), need, txt: el.textContent.trim().slice(0, 20), cls: el.className || el.tagName });
  });
  low.forEach(x => F.push(`コントラスト ${x.r}:1（要 ${x.need}:1） "${x.txt}"`));

  /* --- 2. 横スクロール --- */
  const sw = document.documentElement.scrollWidth;
  if (sw > innerWidth + 1) F.push(`横スクロール発生 ${sw} > ${innerWidth}`);

  /* --- 3. タップ領域 --- */
  [...document.querySelectorAll('a, button')].forEach(el => {
    const b = el.getBoundingClientRect();
    if (b.height > 0 && (b.height < 44 || b.width < 44)) {
      F.push(`タップ領域 ${Math.round(b.width)}x${Math.round(b.height)} "${el.textContent.trim().slice(0, 14)}"`);
    }
  });

  /* --- 4. 画像に文字が入っていないか ---
     装飾画像なのに alt が入っている＝画像内に情報がある疑い。 */
  [...document.querySelectorAll('img')].forEach(img => {
    if (img.closest('[aria-hidden="true"]') && img.alt) F.push(`装飾画像に alt "${img.alt}"`);
  });

  /* --- 5. 絶対パス --- */
  [...document.querySelectorAll('[src], [href]')].forEach(el => {
    const v = el.getAttribute('src') || el.getAttribute('href') || '';
    if (v.startsWith('/')) F.push(`絶対パス ${v}`);
  });

  /* --- 6. 読み込めていない画像 --- */
  const broken = [...document.querySelectorAll('img')].filter(i => i.complete && i.naturalWidth === 0);
  broken.forEach(i => F.push(`画像が読めない ${i.getAttribute('src')}`));

  return {
    pass: F.length === 0,
    failures: F,
    details: { viewport: [innerWidth, innerHeight], scrollWidth: sw, 検査した文字要素: texts.length, コントラスト不足: low.length }
  };
};

/* 画像の読み込みを待ってから検証する。
   ブラウザペインが非表示の環境では loading="lazy" の画像が交差判定を
   受けられず読み込まれないため、そのままだと高さ0で誤判定する。 */
window.__checkReady = async function () {
  const imgs = [...document.querySelectorAll('img')];
  imgs.forEach(i => { i.loading = 'eager'; });
  const t0 = Date.now();
  while (Date.now() - t0 < 8000) {
    if (imgs.every(i => i.complete)) break;
    await new Promise(r => setTimeout(r, 150));
  }
  return window.__check();
};
