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
      /* 規則が読めるだけでなく、実際に効いていることまで確かめる。
         body の overflow-x:clip は style.css にしか無いので目印に使える。
         ここを省くと、まだ適用されていない一瞬を測って「背景が無い」と
         読み、ありもしないコントラスト不足を20件以上でっち上げる。 */
      if (n > 0 && getComputedStyle(document.body).overflowX === 'clip') break;
      await new Promise(r => setTimeout(r, 60));
    }
    /* 画面幅を変えた直後は再レイアウトが済んでいないことがある。
       2フレーム待って、位置が確定してから測る。
       ただしブラウザペインが隠れていると rAF は一切呼ばれず、ここで
       永久に止まる。測っているのはレイアウトを読むだけなので、
       一定時間で来なければタイマーで代用して先へ進む。 */
    const frame = () => new Promise(r => {
      let done = false;
      const go = () => { if (!done) { done = true; r(); } };
      const t = setTimeout(go, 120);
      requestAnimationFrame(() => { clearTimeout(t); go(); });
    });
    await frame(); await frame();
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

  /* 同じ画面で2回測り、両方で出た指摘だけを採る。
     このブラウザペインでは、画面幅を変えた直後やスタイルを読み直した
     直後に、まだ効いていない状態を測ってしまうことがある。そのときは
     背景を持つ要素まで「背景が無い」と読み、20件以上の不足をでっち上げる。
     一過性のずれは2回目には出ないので、共通部分を取れば消える。
     本物の不足は何度測っても出る。 */
  const a1 = await window.__check();
  await new Promise(r => setTimeout(r, 260));
  const a2 = await window.__check();
  const common = a1.failures.filter(f => a2.failures.includes(f));
  const a = { pass: common.length === 0, failures: common, details: a2.details };
  const wobble = (a1.failures.length !== a2.failures.length)
    ? (a1.failures.length + " → " + a2.failures.length + " 件（共通 " + common.length + " 件を採用）")
    : "なし";
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
    測定ゆらぎ: wobble,
    生き物と文字: b.pass ? ('OK（' + b.生き物 + '体）') : b.不足,
    ヒーローの文字: c.pass === null ? '―' : (c.pass ? 'OK' : c.読みにくい要素),
    ヒーローの絵: /mobile|tall/.test(getComputedStyle(document.querySelector('.hero-art')).backgroundImage) ? '縦長' : '横長',
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
