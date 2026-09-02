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
  /* 色の文字列を [r,g,b(,a)] にする。
     rgb()/rgba() だけでなく #rrggbb / #rgb も受ける。
     16進数を数値抽出だけで処理すると "#14406F" が [14406] という
     1要素になり、下地の取得に失敗して判定が丸ごと狂う。 */
  const parse = s => {
    s = (s || '').trim();
    let m = s.match(/^#([0-9a-f]{3})$/i);
    if (m) return m[1].split('').map(c => parseInt(c + c, 16));
    m = s.match(/^#([0-9a-f]{6})$/i);
    if (m) return [0, 2, 4].map(i => parseInt(m[1].substr(i, 2), 16));
    return (s.match(/[\d.]+/g) || []).map(Number);
  };

  /* 半透明の色を下地に合成する。カードは rgba で敷くことが多く、
     合成後の実効色で測らないと判定が実態とずれる。 */
  const over = (fg, bg) => {
    const a = fg[3] === undefined ? 1 : fg[3];
    return [0, 1, 2].map(i => Math.round(fg[i] * a + bg[i] * (1 - a)));
  };

  /* ページ下地の色を、要素のY座標から求める。

     以前は各セクションが宣言した --tier-bg という定数を使っていたが、
     グラデーションはセクションの中でも色が変わるため、実際の下地と
     ずれてコントラスト不足を見逃していた（1セクション1色で近似する
     と、最大で明度が2段階ぶんずれる）。
     style.css の --sea-0〜--sea-7 と同じ停止位置で線形補間する。 */
  /* 停止位置と色は style.css の :root から読む。
     ここに値を書き写すと、CSS だけ直したときに判定が実態とずれる
     （実際に --tier-bg を定数で持っていて AA未達を5件見逃した）。 */
  const SEA = (() => {
    const rs = getComputedStyle(document.documentElement);
    const out = [];
    for (let i = 0; i < 8; i++) {
      const c = parse(rs.getPropertyValue(`--sea-${i}`));
      const p = parseFloat(rs.getPropertyValue(`--sea-p${i}`));
      if (c.length >= 3 && !isNaN(p)) out.push([p / 100, c.slice(0, 3)]);
    }
    return out.length >= 2 ? out : [[0, [255, 255, 255]], [1, [255, 255, 255]]];
  })();
  const seaAt = t => {
    t = Math.max(0, Math.min(1, t));
    for (let i = 1; i < SEA.length; i++) {
      if (t <= SEA[i][0]) {
        const [p0, c0] = SEA[i - 1], [p1, c1] = SEA[i];
        const k = (t - p0) / (p1 - p0);
        return c0.map((v, j) => Math.round(v + (c1[j] - v) * k));
      }
    }
    return SEA[SEA.length - 1][1];
  };
  const pageH = () => Math.max(document.body.scrollHeight, document.documentElement.scrollHeight, 1);
  /* 下地は「ページ全体のグラデーション」＋「深海の器に掛けた幕1枚」。
     幕は擬似要素なので祖先の背景としては読めない。CSS と同じ値を
     :root から読み、同じ式で合成する。以前は深海セクションごとに
     幕が1枚ずつ掛かっていて、それが横縞に見えたので器1つにまとめた。 */
  const rs0 = getComputedStyle(document.documentElement);
  const DEEP = {
    rgb: (rs0.getPropertyValue("--deep-rgb") || "6,26,52").split(",").map(Number),
    lead: parseFloat(rs0.getPropertyValue("--deep-lead")) || 320,
    a1: parseFloat(rs0.getPropertyValue("--deep-a1")) || 0.55,
    a2: parseFloat(rs0.getPropertyValue("--deep-a2")) || 0.78,
    a3: parseFloat(rs0.getPropertyValue("--deep-a3")) || 0.88
  };
  const deepAlpha = mid => {
    const zone = document.querySelector(".deep-zone");
    if (!zone) return 0;
    const zr = zone.getBoundingClientRect();
    const top = zr.top + scrollY - DEEP.lead;       /* 幕の上端 */
    const h = zr.height + DEEP.lead;                /* 幕の高さ */
    const d = mid - top;
    if (d <= 0) return 0;
    if (d >= h) return DEEP.a3;
    /* CSS の停止位置と同じ3区間で線形に補間する */
    if (d < DEEP.lead) return DEEP.a1 * (d / DEEP.lead);
    if (d < DEEP.lead * 2) return DEEP.a1 + (DEEP.a2 - DEEP.a1) * ((d - DEEP.lead) / DEEP.lead);
    return DEEP.a2 + (DEEP.a3 - DEEP.a2) * ((d - DEEP.lead * 2) / (h - DEEP.lead * 2));
  };
  const baseOf = el => {
    const b = el.getBoundingClientRect();
    const mid = b.top + scrollY + b.height / 2;
    const base = seaAt(mid / pageH());
    const a = deepAlpha(mid);
    if (a <= 0) return base;
    return base.map((v, i) => Math.round(DEEP.rgb[i] * a + v * (1 - a)));
  };

  const bgOf = el => {
    const stack = [];
    /* body と html は数えない。実際の下地はページ全体の深度グラデーション
       （body::before）であり、body の background-color はその下に隠れる
       ただのフォールバックでしかない。これを合成に含めると、
       body のクリーム色が階層の海の色を上書きしてしまう。 */
    for (let n = el; n && n !== document.body && n !== document.documentElement; n = n.parentElement) {
      const c = parse(getComputedStyle(n).backgroundColor);
      if (c.length >= 3 && (c[3] === undefined || c[3] > 0.01)) stack.push(c);
      if (c.length >= 3 && (c[3] === undefined || c[3] >= 0.999)) break;
    }
    let acc = baseOf(el);
    for (let i = stack.length - 1; i >= 0; i--) acc = over(stack[i], acc);
    return acc;
  };

  const ratio = (a, b) => {
    const l1 = lum(a[0], a[1], a[2]), l2 = lum(b[0], b[1], b[2]);
    return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
  };

  /* --- 1. コントラスト --- */
  const texts = [...document.querySelectorAll('p, li, h1, h2, h3, h4, a, span, strong, .eyebrow, .btn, .num, dt, dd')]
    /* 「自分自身が文字を持つ」要素だけを測る。
       子要素を包むだけの器（<p> の中に <a> が1つ、など）まで測ると、
       器の背景（＝地の色）と子の文字色を突き合わせてしまい、
       実際には読める文字を不足として報告する。 */
    .filter(el => el.offsetParent !== null && el.getClientRects().length &&
      [...el.childNodes].some(nd => nd.nodeType === 3 && nd.textContent.trim()));
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

  /* --- 2. 横あふれ --- */
  /* scrollWidth だけで見てはいけない。body は overflow-x:clip なので
     実際には横へ動かないが、装飾（生き物）が画面の外へ泳ぎ出ていると
     scrollWidth だけが伸びて、ありもしない横スクロールを報告する。
     見るべきは2つ。
       ・本当に横へ動くか（動けば内容に手が届かなくなる）
       ・中身（aria-hidden でない要素）が画面からはみ出していないか
     画面の端から泳ぎ出す生き物は意図した見せ方なので数えない。 */
  const de = document.documentElement;
  const keep = de.scrollLeft;
  de.scrollLeft = 9999;
  const movable = de.scrollLeft > 0;
  de.scrollLeft = keep;
  if (movable) F.push(`横スクロール発生 ${de.scrollWidth} > ${innerWidth}`);

  let worst = null;
  [...document.querySelectorAll('main *, header *, footer *')].forEach(el => {
    if (el.closest('[aria-hidden="true"]') || el.closest('.sprite') || el.closest('dialog')) return;
    const cs = getComputedStyle(el);
    if (cs.display === 'none' || cs.visibility === 'hidden' || cs.position === 'fixed') return;
    const r = el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return;
    if (r.right > innerWidth + 1 && (!worst || r.right > worst.right)) {
      worst = { right: Math.round(r.right), cls: el.className || el.tagName };
    }
  });
  if (worst) F.push(`中身が画面からはみ出している ${worst.right} > ${innerWidth}（${worst.cls}）`);

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
    details: { viewport: [innerWidth, innerHeight], scrollWidth: de.scrollWidth, 横へ動くか: movable, 検査した文字要素: texts.length, コントラスト不足: low.length }
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
