/*  gen-fleet.js ― ヒーローの船団マークアップを生成して index.html に差し込む

    座標は「等間隔の格子」ではなく、夕日の光の道（x≒73%）から手前へ向かって
    扇状に広がる隊列として手で置いている。完成イメージ(1)の船団の見え方に合わせ、
    列ごとに y をわずかにばらつかせて機械的な整列を避ける。

    --y は船の上端。喫水線は船高のおよそ85%の位置なので、水平線より十分下に
    来るよう各行の y を決めてある（tools/preview-fleet.ps1 で確認できる）。       */
const fs = require('fs');
const p = 'index.html', NL = '\r\n';

const TYPES = ['fish', 'growth', 'shop', 'crest', 'leaf', 'gear', 'plain'];

// [x%, y%, width%]  ― 奥から手前へ
// 右端は 84% までに収めてある。background-size:cover では、横長画像を
// 狭いデスクトップ幅（例 1100x800）で表示すると左右がそれぞれ約17%切られるため、
// それより右に置いた船は画面外へ出てしまう。
const DESKTOP = [
  [64.5, 44.6, 1.4], [68.2, 44.0, 1.5], [71.6, 44.4, 1.3], [74.8, 43.9, 1.6], [78.0, 44.5, 1.4],
  [59.5, 52.4, 2.8], [65.8, 53.6, 3.1], [72.0, 52.2, 2.7], [78.4, 54.0, 3.2], [83.6, 52.8, 2.9],
  [57.5, 62.5, 5.2], [68.0, 64.5, 4.8], [78.2, 62.0, 5.4],
  [58.5, 74.5, 8.0], [72.5, 76.0, 8.6], [83.0, 73.5, 7.4],
];
const MOBILE = [
  [52.5, 70.8, 2.8], [60.0, 70.2, 3.1], [67.5, 70.9, 2.7],
  [46.5, 76.0, 5.4], [58.5, 77.2, 6.0], [71.0, 75.8, 5.2],
  [42.0, 83.5, 9.6], [60.5, 84.8, 8.8], [78.5, 82.8, 10.0],
  [50.0, 88.6, 14.5], [76.0, 87.6, 13.0],
];

const SPINE = 73; // 光の道の位置。集結前は、ここから左右へ散らばっている

function build(list, typeOffset) {
  return list.map(([x, y, w], i) => {
    // 手前の船（＝幅が大きい船）ほど大きく散らばってから集まる
    const depth = Math.min(1, w / 9);
    const sdx = ((x - SPINE) * (0.55 + depth * 1.5) + (i % 2 ? 3.5 : -3.5)).toFixed(1);
    const sdy = (2 + depth * 7).toFixed(1);
    const bob = (4.4 + ((i * 0.41) % 1.9) + depth * 0.5).toFixed(2);
    const bd = (((i * 0.31) % 1.7)).toFixed(2);
    const type = TYPES[(i + typeOffset) % TYPES.length];
    const style = `--x:${x}%;--y:${y}%;--w:${w}%;--sdx:${sdx}%;--sdy:${sdy}%;--bob:${bob}s;--bd:${bd}s`;
    return `        <span class="ship-slot" style="${style}">` +
           `<img class="ship" src="assets/img/icons/ships/ship-${type}.webp" alt="" loading="lazy" decoding="async"></span>`;
  });
}

const block = [
  '    <div class="fleet-viewport fleet-viewport-desktop" aria-hidden="true">',
  '      <div class="fleet fleet-desktop" data-img-w="1600" data-img-h="772">',
  ...build(DESKTOP, 0),
  '      </div>',
  '    </div>',
  '    <div class="fleet-viewport fleet-viewport-mobile" aria-hidden="true">',
  '      <div class="fleet fleet-mobile" data-img-w="941" data-img-h="1672">',
  ...build(MOBILE, 3),
  '      </div>',
  '    </div>',
];

let lines = fs.readFileSync(p, 'utf8').split(/\r?\n/);
const start = lines.findIndex(l => l.includes('fleet-viewport-desktop'));
const end = lines.findIndex(l => l.includes('class="wrap hero-wrap"'));
if (start < 0 || end < 0) { console.error('markers not found'); process.exit(1); }
lines.splice(start, end - start - 1, ...block);
fs.writeFileSync(p, lines.join(NL));
console.log('fleet: desktop ' + DESKTOP.length + ' / mobile ' + MOBILE.length);
