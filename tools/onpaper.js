/* tools/onpaper.js ― ヒーローの文字が「絵の中の紙」の上に乗っているか測る。

   ヒーローの背景は1枚絵で、左側だけが紙（明るいクリーム）、右側は海。
   紺の文字が紙からはみ出して海に乗ると、読めなくなる。
   境目は破れた曲線なので、CSSの値を見ても判断できない。

   そこで背景画像を canvas に描き、cover と同じ式で画面座標を画像座標へ
   変換して、文字の矩形の下を実際にサンプリングする。

   使い方:
     fetch('tools/onpaper.js').then(r=>r.text()).then(t=>{eval(t);return __onPaper()}).then(console.log)

   判定: 文字の下地と文字色のコントラスト比が WCAG 2.1 AA を満たせば合格。 */
window.__onPaper = async function () {
  const art = document.querySelector('.hero-art');
  const cs = getComputedStyle(art);
  if (cs.backgroundImage === 'none') return { pass: null, note: '背景画像なし' };
  const url = cs.backgroundImage.slice(5, -2);

  const img = new Image();
  await new Promise((ok, ng) => { img.onload = ok; img.onerror = ng; img.src = url; });
  const c = document.createElement('canvas');
  c.width = img.naturalWidth; c.height = img.naturalHeight;
  const ctx = c.getContext('2d');
  ctx.drawImage(img, 0, 0);
  const px = ctx.getImageData(0, 0, c.width, c.height).data;

  const ar = art.getBoundingClientRect();
  const iw = img.naturalWidth, ih = img.naturalHeight;
  /* background-size:cover と同じ式。短いほうの辺に合わせて拡大する */
  const s = Math.max(ar.width / iw, ar.height / ih);
  const dw = iw * s, dh = ih * s;
  /* background-position の % は「(器 - 画像) × 割合」。px 指定なら素の値 */
  const px2n = v => v.endsWith('%') ? parseFloat(v) / 100 : null;
  const fy = px2n(cs.backgroundPositionY);
  const fx = px2n(cs.backgroundPositionX);
  const ox = (ar.width - dw) * (fx === null ? 0.5 : fx);
  const oy = (ar.height - dh) * (fy === null ? 0.5 : fy);

  const sample = (vx, vy) => {
    const ix = Math.round((vx - ar.left - ox) / s);
    const iy = Math.round((vy - ar.top - oy) / s);
    if (ix < 0 || iy < 0 || ix >= iw || iy >= ih) return null;
    const k = (iy * iw + ix) * 4;
    return [px[k], px[k + 1], px[k + 2]];
  };

  /* 要素の枠ではなく、文字が実際に占める行の矩形を測る。
     <p> の枠は段落の幅いっぱいに広がるので、最終行が短くても右端まで
     測ってしまい、紙からはみ出していると誤って報告する。
     Range の getClientRects() なら行ごとの、文字に密着した矩形が取れる。 */
  /* 測るのは「文字が実際に置かれている行」だけ。

     selectNodeContents(el).getClientRects() は、要素の中身をまるごと
     囲むので、置換要素（<img>）の箱まで文字の行として返す。
     .hero-brand は左に印の画像を抱えていて文字は子の <span> の中に
     あるため、印の上の絵の色を「文字の下地」として測っていた。
     900x1200 でちょうど印が絵の中間調に乗り、3.46:1 の不合格が出た
     （実際にはそこに文字は無く、印の絵が乗っているので読める）。
     文字ノードだけを辿れば、この取り違えは起きない。 */
  const lineRects = el => {
    const out = [];
    const w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    for (let n = w.nextNode(); n; n = w.nextNode()) {
      if (!n.textContent.trim()) continue;
      const r = document.createRange();
      r.selectNodeContents(n);
      for (const b of r.getClientRects()) if (b.width > 1 && b.height > 1) out.push(b);
    }
    return out;
  };

  /* 「紙の上か」ではなく「実際に読めるか」で判定する。
     縦画面の絵は紙から空へ連続していて、右のほうは淡い水色になる。
     明るさだけで線を引くと、読めているのに不合格になってしまう。
     文字色との実際のコントラスト比を出して WCAG 2.1 AA と比べる。 */
  const lum = c => {
    const f = v => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]);
  };
  const ratio = (a, b) => {
    const l1 = lum(a), l2 = lum(b);
    return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
  };
  const parse = s => (String(s).match(/[\d.]+/g) || []).map(Number);

  /* 文字と絵の間に不透明な下敷きがあるなら、絵の色は関係ない。
     読めるかどうかは下敷きとの対比で決まり、それは tools/check.js が
     見ている（check.js は宣言された背景色を読む）。ここで判定すると、
     下敷きの下にある絵を見て「紙から外れた」と誤って報告する。
     夜の縦画面は、絵の紙が本文を覆いきれないので下敷きを敷いてある。 */
  const onPanel = el => {
    for (let n = el; n && n !== document.body; n = n.parentElement) {
      const cs = getComputedStyle(n);
      const bg = parse(cs.backgroundColor);
      if (bg.length >= 3 && (bg[3] === undefined || bg[3] >= 0.75)) return true;
      /* 下敷きがグラデーションのこともある。ヒーローの絵そのもの
         （.hero-art）は下敷きではないので数えない。 */
      if (!n.classList.contains('hero-art') && cs.backgroundImage !== 'none') return true;
    }
    return false;
  };

  const rows = [];
  document.querySelectorAll('.hero-title,.hero-brand,.hero-sub,.hero-lead').forEach(el => {
    if (onPanel(el)) return;
    const ecs = getComputedStyle(el);
    const fg = parse(ecs.color).slice(0, 3);
    const size = parseFloat(ecs.fontSize);
    const need = (size >= 24 || (size >= 18.66 && parseInt(ecs.fontWeight, 10) >= 700)) ? 3 : 4.5;
    let worst = Infinity, n = 0, at = null;
    lineRects(el).forEach(b => {
      for (let i = 0; i <= 12; i++) {
        for (let j = 0; j <= 3; j++) {
          const vx = b.left + b.width * i / 12, vy = b.top + b.height * j / 3;
          const c = sample(vx, vy);
          if (c === null) continue;
          n++;
          const r = ratio(fg, c);
          if (r < worst) { worst = r; at = [Math.round(vx), Math.round(vy + scrollY)]; }
        }
      }
    });
    if (n) rows.push({ 要素: el.className || el.tagName, 比: +worst.toFixed(2), 要: need, 位置: at });
  });

  const bad = rows.filter(r => r.比 < r.要);
  return {
    pass: bad.length === 0,
    画面: [innerWidth, innerHeight],
    倍率: +s.toFixed(3),
    縦位置: cs.backgroundPositionY,
    読みにくい要素: bad.map(r => r.要素 + ' ' + r.比 + '/' + r.要),
    明細: rows
  };
};
