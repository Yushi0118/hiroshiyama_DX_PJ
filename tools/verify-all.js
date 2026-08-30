/* tools/verify-all.js ― 3つの検証を1回で回す。

     check.js    文字と背景のコントラスト、横スクロール、タップ領域、
                 画像内文字、絶対パス、読み込めない画像
     overlap.js  海の生き物が文字の下地を汚していないか（画像を実測）
     onpaper.js  ヒーローの文字が「絵の中の紙」の上に乗っているか

   3つとも別々の失敗の仕方をするので、まとめて回さないと片方だけ直して
   もう片方を壊す。

   使い方（ブラウザのコンソール）:
     fetch('tools/verify-all.js').then(r=>r.text()).then(t=>{eval(t);return __verify()}).then(console.log)

   注意: style.css はページを再読み込みしても再取得されないことがある。
   __verify() は毎回 link のURLを変えて読み直させる。これを省くと、
   直したはずのCSSではなく古いCSSを測ることになる（実際に一度やった）。 */
window.__verify = async function () {
  const link = document.querySelector('link[rel=stylesheet][href*="style.css"]');
  if (link) {
    const url = link.href.split('?')[0] + '?cb=' + Math.round(performance.now() * 1000);
    await new Promise(ok => { link.onload = ok; link.href = url; setTimeout(ok, 2500); });
    /* load イベントだけでは足りない。差し替えの途中に測ると、まだ規則が
       効いていない状態を「背景が無い」と読んでしまい、ありもしない
       コントラスト不足を報告する（実際に1件でっち上げた）。
       規則が実際に読める状態になるまで待つ。 */
    const t0 = Date.now();
    while (Date.now() - t0 < 3000) {
      const sheet = [...document.styleSheets].find(s => s.href === url);
      let n = 0;
      try { n = sheet ? sheet.cssRules.length : 0; } catch (e) { n = 0; }
      if (n > 0) break;
      await new Promise(r => setTimeout(r, 60));
    }
  }

  const grab = async f => eval(await fetch(f + '?cb=' + Math.round(performance.now() * 1000)).then(r => r.text()));
  await grab('tools/check.js');
  await grab('tools/overlap.js');
  await grab('tools/onpaper.js');

  const imgs = [...document.querySelectorAll('img')];
  imgs.forEach(i => { i.loading = 'eager'; });
  const t0 = Date.now();
  while (Date.now() - t0 < 9000) {
    if (imgs.every(i => i.complete)) break;
    await new Promise(r => setTimeout(r, 150));
  }

  const a = await window.__check();
  const b = await window.__overlap();
  const c = await window.__onPaper();

  const H = document.body.scrollHeight;
  const ctas = [...document.querySelectorAll('a[href="#entry"]')]
    .map(e => Math.round((e.getBoundingClientRect().top + scrollY) / H * 100)).sort((p, q) => p - q);
  let prev = 0, gap = 0;
  ctas.concat([100]).forEach(y => { gap = Math.max(gap, y - prev); prev = y; });

  const ok = a.pass && b.pass && (c.pass !== false);
  return {
    合否: ok ? '合格' : '不合格',
    サイズ: [innerWidth, innerHeight],
    コントラスト等: a.pass ? 'OK' : a.failures,
    生き物と文字: b.pass ? ('OK（' + b.生き物 + '体）') : b.不足,
    ヒーローの文字: c.pass === null ? '―' : (c.pass ? 'OK（紙の上）' : c.紙から外れた要素),
    ヒーローの絵: /tall/.test(getComputedStyle(document.querySelector('.hero-art')).backgroundImage) ? '縦長' : '横長',
    ページ丈: H,
    見出し: 'h1=' + document.querySelectorAll('h1').length +
            ' h2=' + document.querySelectorAll('h2').length +
            ' h3=' + document.querySelectorAll('h3').length,
    CTA位置: ctas.join('%, ') + '%',
    最大無導線区間: gap + '%'
  };
};

/* 旧名。以前のメモや手順書からも呼べるように残す。 */
window.__summary = window.__verify;
