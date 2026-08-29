/* tools/verify-all.js ― ブラウザのコンソールに貼って、
   ページを実際にリサイズせず「合否の要点」を1回で出す補助。
   実際のサイズ別検証は、ブラウザの幅を変えて __checkReady() を呼ぶ。 */
window.__summary = async function () {
  const a = await window.__checkReady();
  const H = document.body.scrollHeight;
  const ctas = [...document.querySelectorAll('a[href="#entry"]')]
    .map(e => Math.round((e.getBoundingClientRect().top + scrollY) / H * 100)).sort((p, q) => p - q);
  let prev = 0, gap = 0;
  ctas.concat([100]).forEach(y => { gap = Math.max(gap, y - prev); prev = y; });
  return {
    サイズ: a.details.viewport,
    合否: a.pass ? '合格' : a.failures,
    検査した文字要素: a.details['検査した文字要素'],
    横スクロール: a.details.scrollWidth <= innerWidth + 1 ? 'なし' : 'あり',
    ヒーローの絵: /tall/.test(getComputedStyle(document.querySelector('.hero-art')).backgroundImage) ? '縦長' : '横長',
    見出し: 'h1=' + document.querySelectorAll('h1').length +
            ' h2=' + document.querySelectorAll('h2').length +
            ' h3=' + document.querySelectorAll('h3').length,
    CTA位置: ctas.join('%, ') + '%',
    最大無導線区間: gap + '%'
  };
};
