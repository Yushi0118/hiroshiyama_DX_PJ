/* tools/overlap.js ― 海の生き物が文字の読みやすさを損ねていないか測る。

   生き物は z-index:-1 で本文の下に潜る。カードの中の文字は不透明な
   カードに守られるが、見出し・リード文・注記は地の上に直接置かれている。
   そこへ水彩の絵が入り込むと、文字の下地が絵になってしまう。

   tools/check.js のコントラスト判定は「CSSで宣言された背景色」しか
   見ないので、画像である生き物は見えない。だから別の物差しとして持つ。

   「重なっているか」ではなく「重なった結果、読めなくなっているか」を見る。
   スマホでは画面幅いっぱいに本文が広がるため、重なりを禁じると生き物を
   置く場所が無くなる。薄い水彩が紺地に少し掛かっても、実際のコントラスト
   比が足りていれば問題にはならない。

   手順:
     1. その位置のページ下地の色を求める（深度グラデーション＋深海の幕）
     2. 生き物の画素を、その透明度と要素の opacity で重ねる
     3. 文字側の背景（注記の半透明パネルなど）をさらに重ねる
     4. 文字色とのコントラスト比を出し、WCAG 2.1 AA と比べる

   回転（海藻・珊瑚の揺れ、±2.4度）は無視して矩形として扱う。
   ずれは数px で、判定の結論を変えるほどではない。

   使い方:
     fetch('tools/overlap.js').then(r=>r.text()).then(t=>{eval(t);return __overlap()}).then(console.log) */
window.__overlap = async function () {
  const parse = s => {
    s = (s || '').trim();
    let m = s.match(/^#([0-9a-f]{3})$/i);
    if (m) return m[1].split('').map(c => parseInt(c + c, 16));
    m = s.match(/^#([0-9a-f]{6})$/i);
    if (m) return [0, 2, 4].map(i => parseInt(m[1].substr(i, 2), 16));
    return (s.match(/[\d.]+/g) || []).map(Number);
  };
  const over = (fg, bg, a) => {
    if (a === undefined) a = fg[3] === undefined ? 1 : fg[3];
    return [0, 1, 2].map(i => fg[i] * a + bg[i] * (1 - a));
  };
  const lum = c => {
    const f = v => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]);
  };
  const ratio = (a, b) => {
    const l1 = lum(a), l2 = lum(b);
    return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
  };

  /* --- ページ下地（style.css の :root から読む。値を写さない） --- */
  const rs = getComputedStyle(document.documentElement);
  const SEA = [];
  for (let i = 0; i < 8; i++) {
    const c = parse(rs.getPropertyValue(`--sea-${i}`));
    const p = parseFloat(rs.getPropertyValue(`--sea-p${i}`));
    if (c.length >= 3 && !isNaN(p)) SEA.push([p / 100, c.slice(0, 3)]);
  }
  const SCRIM = {
    rgb: (rs.getPropertyValue('--scrim-rgb') || '6,26,52').split(',').map(Number),
    a: parseFloat(rs.getPropertyValue('--scrim-a')) || 0.62,
    h: parseFloat(rs.getPropertyValue('--scrim-h')) || 420
  };
  const pageH = () => Math.max(document.body.scrollHeight, document.documentElement.scrollHeight, 1);
  const seaAt = t => {
    t = Math.max(0, Math.min(1, t));
    for (let i = 1; i < SEA.length; i++) {
      if (t <= SEA[i][0]) {
        const [p0, c0] = SEA[i - 1], [p1, c1] = SEA[i];
        const k = (t - p0) / (p1 - p0);
        return c0.map((v, j) => v + (c1[j] - v) * k);
      }
    }
    return SEA[SEA.length - 1][1];
  };
  const baseAt = (pageY, deepSec) => {
    let base = seaAt(pageY / pageH());
    if (deepSec) {
      const h = Math.min(deepSec.offsetHeight * 0.62, SCRIM.h);
      const d = pageY - deepSec.offsetTop;
      if (d >= 0 && d < h) {
        const t = d / h;
        const a = t < 0.6 ? SCRIM.a + (SCRIM.a * 0.74 - SCRIM.a) * (t / 0.6)
                          : SCRIM.a * 0.74 * (1 - (t - 0.6) / 0.4);
        base = over(SCRIM.rgb, base, a);
      }
    }
    return base;
  };

  /* --- 生き物の画像を canvas に取り込む（同じURLは1回だけ） --- */
  const canvases = {};
  const load = async src => {
    if (canvases[src]) return canvases[src];
    const img = new Image();
    await new Promise((ok, ng) => { img.onload = ok; img.onerror = ng; img.src = src; });
    const c = document.createElement('canvas');
    c.width = img.naturalWidth; c.height = img.naturalHeight;
    c.getContext('2d').drawImage(img, 0, 0);
    canvases[src] = {
      w: img.naturalWidth, h: img.naturalHeight,
      px: c.getContext('2d').getImageData(0, 0, c.width, c.height).data
    };
    return canvases[src];
  };

  const imgs = [...document.querySelectorAll('.creature')]
    .filter(el => getComputedStyle(el).display !== 'none' && el.naturalWidth);
  for (const el of imgs) await load(el.src);

  /* --- 背景を持たない文字（地の上に直接置かれたもの） --- */
  const texts = [...document.querySelectorAll('.wrap h2, .wrap .lead, .wrap .eyebrow, .wrap .note, .wrap > p')]
    .filter(el => el.offsetParent !== null &&
      [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim()));

  const findings = [];
  for (const t of texts) {
    const cs = getComputedStyle(t);
    const fg = parse(cs.color).slice(0, 3);
    const size = parseFloat(cs.fontSize);
    const need = (size >= 24 || (size >= 18.66 && parseInt(cs.fontWeight, 10) >= 700)) ? 3 : 4.5;
    /* 文字自身と祖先の背景を、上から順に積む */
    const stack = [];
    for (let n = t; n && n !== document.body && n !== document.documentElement; n = n.parentElement) {
      const c = parse(getComputedStyle(n).backgroundColor);
      if (c.length >= 3 && (c[3] === undefined || c[3] > 0.01)) stack.push(c);
      if (c.length >= 3 && (c[3] === undefined || c[3] >= 0.999)) break;
    }
    const deepSec = t.closest('.tier-deep');

    const r = document.createRange();
    r.selectNodeContents(t);
    const lines = [...r.getClientRects()].filter(b => b.width > 1 && b.height > 1);

    for (const el of imgs) {
      const cb = el.getBoundingClientRect();
      const flip = (getComputedStyle(el).getPropertyValue('--cfx') || '1').trim() === '-1';
      const cv = canvases[el.src];
      for (const b of lines) {
        const x1 = Math.max(b.left, cb.left), x2 = Math.min(b.right, cb.right);
        const y1 = Math.max(b.top, cb.top), y2 = Math.min(b.bottom, cb.bottom);
        if (x2 - x1 <= 2 || y2 - y1 <= 2) continue;

        let worst = Infinity, worstAt = null;
        for (let i = 0; i <= 8; i++) {
          for (let j = 0; j <= 4; j++) {
            const vx = x1 + (x2 - x1) * i / 8, vy = y1 + (y2 - y1) * j / 4;
            let u = (vx - cb.left) / cb.width;
            if (flip) u = 1 - u;
            const ix = Math.min(cv.w - 1, Math.max(0, Math.round(u * cv.w)));
            const iy = Math.min(cv.h - 1, Math.max(0, Math.round((vy - cb.top) / cb.height * cv.h)));
            const k = (iy * cv.w + ix) * 4;
            const a = (cv.px[k + 3] / 255) * parseFloat(getComputedStyle(el).opacity);
            let bg = baseAt(vy + scrollY, deepSec);
            if (a > 0.004) bg = over([cv.px[k], cv.px[k + 1], cv.px[k + 2]], bg, a);
            for (let s = stack.length - 1; s >= 0; s--) bg = over(stack[s], bg);
            const rr = ratio(fg, bg);
            if (rr < worst) { worst = rr; worstAt = [Math.round(vx), Math.round(vy + scrollY)]; }
          }
        }
        if (worst < need) {
          findings.push({
            文字: t.textContent.trim().slice(0, 18),
            生き物: (el.closest('section') || {}).id + '/' + (el.className.split(' ').pop()),
            比: +worst.toFixed(2), 要: need, 位置: worstAt
          });
        }
      }
    }
  }

  /* 同じ組み合わせは1件にまとめる */
  const seen = new Set();
  const uniq = findings.filter(f => {
    const k = f.文字 + '|' + f.生き物;
    if (seen.has(k)) return false;
    seen.add(k); return true;
  });
  return { pass: uniq.length === 0, 画面: [innerWidth, innerHeight], 生き物: imgs.length, 不足: uniq };
};
