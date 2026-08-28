/* tools/audit.js ― ブラウザのコンソールに貼って実行する幾何監査。
   スクリーンショットが撮れない環境でも、レイアウトの破綻を機械的に検出する。 */
window.__audit = function () {
  const r = { viewport: [innerWidth, innerHeight], issues: [] };
  const add = (sev, msg) => r.issues.push(sev + ' ' + msg);

  // 1. 横スクロールの発生
  const sw = document.documentElement.scrollWidth;
  r.scrollWidth = sw;
  if (sw > innerWidth + 1) add('NG', `横スクロールが発生 (scrollWidth ${sw} > ${innerWidth})`);

  // 2. ヒーロー：どちらの海景と船団が有効か
  const heroBg = getComputedStyle(document.querySelector('#hero .section-bg')).backgroundImage;
  r.heroScene = /tall/.test(heroBg) ? 'tall(縦)' : /wide/.test(heroBg) ? 'wide(横)' : '不明';
  const dv = getComputedStyle(document.querySelector('.fleet-viewport-desktop')).display;
  const mv = getComputedStyle(document.querySelector('.fleet-viewport-mobile')).display;
  r.fleetActive = dv !== 'none' ? 'desktop' : mv !== 'none' ? 'mobile' : 'なし';
  if ((r.heroScene.startsWith('tall') && r.fleetActive !== 'mobile') ||
      (r.heroScene.startsWith('wide') && r.fleetActive !== 'desktop')) {
    add('NG', `海景(${r.heroScene})と船団(${r.fleetActive})の組み合わせが不整合`);
  }

  // 3. 船団：集結済みか、画面内に何隻見えているか
  const fleet = document.querySelector(r.fleetActive === 'mobile' ? '.fleet-mobile' : '.fleet-desktop');
  r.gathered = fleet ? fleet.classList.contains('is-gathered') : null;
  if (fleet && !r.gathered) add('NG', '船団に is-gathered が付いていない（船が非表示のまま）');
  if (fleet) {
    const slots = [...fleet.querySelectorAll('.ship-slot')];
    const heroRect = document.getElementById('hero').getBoundingClientRect();
    let visible = 0, clipped = 0;
    slots.forEach(s => {
      const b = s.getBoundingClientRect();
      const inX = b.right > 0 && b.left < innerWidth;
      const inY = b.bottom > heroRect.top && b.top < heroRect.bottom;
      if (inX && inY) visible++;
      if (inX && inY && (b.left < 0 || b.right > innerWidth || b.bottom > heroRect.bottom)) clipped++;
    });
    r.shipsTotal = slots.length; r.shipsVisible = visible; r.shipsClipped = clipped;
    if (visible < Math.ceil(slots.length * 0.5)) {
      add('WARN', `船が ${slots.length}隻中 ${visible}隻しか画面内に入っていない`);
    }
  }

  // 4. 装飾部品：完全に画面外＝無駄なダウンロードになっていないか
  r.deco = [];
  document.querySelectorAll('.section-deco').forEach(d => {
    const sec = d.closest('.section');
    const sr = sec.getBoundingClientRect();
    d.querySelectorAll('.deco').forEach(el => {
      const cs = getComputedStyle(el);
      if (cs.display === 'none') return;
      const b = el.getBoundingClientRect();
      const visW = Math.max(0, Math.min(b.right, innerWidth) - Math.max(b.left, 0));
      const visH = Math.max(0, Math.min(b.bottom, sr.bottom) - Math.max(b.top, sr.top));
      const ratio = (b.width && b.height) ? (visW * visH) / (b.width * b.height) : 0;
      const id = sec.id + '/' + [...el.classList].find(c => c.startsWith('d-'));
      r.deco.push({ id, blend: cs.mixBlendMode, w: Math.round(b.width), visible: +(ratio * 100).toFixed(0) });
      if (ratio < 0.06) add('WARN', `装飾 ${id} がほぼ画面外 (可視 ${(ratio*100).toFixed(0)}%)`);
      if (b.width > innerWidth * 2.6) add('WARN', `装飾 ${id} が画面幅の2.6倍超 (${Math.round(b.width)}px)`);
    });
  });

  // 5. 見出しの上に濃い装飾が乗っていないか（可読性）
  document.querySelectorAll('.section-head h2').forEach(h2 => {
    const hb = h2.getBoundingClientRect();
    if (hb.width === 0) return;
    const sec = h2.closest('.section');
    let worst = 0, who = '';
    sec.querySelectorAll('.deco').forEach(el => {
      const b = el.getBoundingClientRect();
      const ow = Math.max(0, Math.min(b.right, hb.right) - Math.max(b.left, hb.left));
      const oh = Math.max(0, Math.min(b.bottom, hb.bottom) - Math.max(b.top, hb.top));
      const cover = (ow * oh) / (hb.width * hb.height);
      if (cover > worst) { worst = cover; who = [...el.classList].find(c => c.startsWith('d-')); }
    });
    if (worst > 0.45) add('WARN', `${sec.id} の見出しに装飾 ${who} が ${(worst*100).toFixed(0)}% 重なっている`);
  });

  // 6. カードのグリッド列数
  r.grids = {};
  ['pain-grid','step-grid','benefit-grid','theme-grid','tl-track','cta-grid','hub'].forEach(c => {
    const el = document.querySelector('.' + c);
    if (el) r.grids[c] = getComputedStyle(el).gridTemplateColumns.split(' ').length;
  });

  // 7. タップ領域（モバイルで44px未満のリンク・ボタン）
  if (innerWidth <= 767) {
    const small = [...document.querySelectorAll('a.btn, a.cta-tile')].filter(a => {
      const b = a.getBoundingClientRect();
      return b.height > 0 && b.height < 44;
    });
    if (small.length) add('WARN', `タップ領域が44px未満の要素 ${small.length}件`);
  }

  r.result = r.issues.length ? r.issues : ['問題なし'];
  return r;
};

/* 画像を強制的に読み込んでから監査する。
   ブラウザペインが非表示の環境では loading="lazy" の画像が
   交差判定を受けられず読み込まれないため、高さ0で計測されてしまう。 */
window.__auditReady = async function () {
  const imgs = [...document.querySelectorAll('.ship, .deco')];
  imgs.forEach(i => { i.loading = 'eager'; });
  const t0 = Date.now();
  while (Date.now() - t0 < 8000) {
    if (imgs.every(i => i.complete && i.naturalWidth > 0)) break;
    await new Promise(r => setTimeout(r, 200));
  }
  const notLoaded = imgs.filter(i => !(i.complete && i.naturalWidth > 0)).length;
  const a = window.__audit();
  a.imagesNotLoaded = notLoaded;
  return a;
};
