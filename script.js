/* ============================================================
   ひろしま協働DXプロジェクト ― スクロールLP
   ・船団の生成と「集結」演出
   ・スクロール連動のフェードイン
   ・装飾部品の視差
   GSAP が CDN から取得できた場合は ScrollTrigger を使い、
   取得できない場合は IntersectionObserver に自動で切り替える。
   ============================================================ */
(function () {
  'use strict';

  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* --------------------------------------------------------
     船団

     位置は「背景画像そのものの座標」で持つ（0〜1の比率）。
     背景は background-size:cover なので、同じ計算式で .fleet の
     枠を作れば、画面比がどう変わっても船は必ず海面の上に乗る。
     -------------------------------------------------------- */
  var SHIPS = ['crest','fish','gear','growth','leaf','plain','shop'];

  // 横長（PC）: hero-scene-wide.jpg 1600x900 / 水平線 y≈0.355 / 海は x>0.48
  var FLEET_WIDE = {
    img: [1600, 900],
    anchorY: 0.5,
    rows: [
      // y の帯, 幅の帯, 隻数, x の帯, 不透明度
      { y:[0.366,0.392], w:[0.010,0.017], n:14, x:[0.500,0.840], fade:0.72 },
      { y:[0.400,0.452], w:[0.022,0.034], n: 9, x:[0.505,0.835], fade:0.86 },
      { y:[0.468,0.598], w:[0.045,0.070], n: 7, x:[0.510,0.830], fade:1    },
      { y:[0.630,0.905], w:[0.105,0.170], n: 5, x:[0.495,0.825], fade:1    }
    ]
  };

  // 縦長（モバイル）: hero-scene-tall.jpg 941x1672 / 水平線 y≈0.665
  var FLEET_TALL = {
    img: [941, 1672],
    anchorY: 1,
    rows: [
      { y:[0.676,0.700], w:[0.024,0.040], n: 8, x:[0.150,0.870], fade:0.75 },
      { y:[0.712,0.762], w:[0.050,0.078], n: 6, x:[0.165,0.855], fade:0.9   },
      { y:[0.775,0.862], w:[0.098,0.150], n: 5, x:[0.175,0.835], fade:1    },
      { y:[0.880,0.968], w:[0.180,0.260], n: 3, x:[0.225,0.785], fade:1    }
    ]
  };

  // 見た目のばらつきを「毎回同じ」にするための決定的な擬似乱数
  function rng(seed) {
    var s = seed >>> 0;
    return function () {
      s = (s * 1664525 + 1013904223) >>> 0;
      return s / 4294967296;
    };
  }

  function buildFleet(cfg) {
    var frag = document.createDocumentFragment();
    var rand = rng(20260828);
    var idx = 0;

    cfg.rows.forEach(function (row, ri) {
      for (var i = 0; i < row.n; i++) {
        // 等間隔に置いてから少しだけ散らす（列に見えないように）
        var t = row.n === 1 ? 0.5 : i / (row.n - 1);
        var jitterX = (rand() - 0.5) * ((row.x[1] - row.x[0]) / row.n) * 0.9;
        var x = row.x[0] + (row.x[1] - row.x[0]) * t + jitterX;
        var y = row.y[0] + (row.y[1] - row.y[0]) * rand();
        var w = row.w[0] + (row.w[1] - row.w[0]) * rand();

        var slot = document.createElement('span');
        slot.className = 'ship-slot';
        slot.style.setProperty('--x', (x * 100).toFixed(2) + '%');
        slot.style.setProperty('--y', (y * 100).toFixed(2) + '%');
        slot.style.setProperty('--w', (w * 100).toFixed(2) + '%');
        slot.style.setProperty('--fade', row.fade);
        // 集結前の散らばり。遠い船ほど遠くから寄ってくる
        var spread = 26 - ri * 5;
        slot.style.setProperty('--sx', ((rand() - 0.35) * spread).toFixed(1) + 'vw');
        slot.style.setProperty('--sy', ((rand() - 0.5) * spread * 0.5).toFixed(1) + 'vh');
        slot.style.setProperty('--sc', (0.55 + rand() * 0.25).toFixed(2));
        slot.style.setProperty('--gd', (0.05 * idx + ri * 0.08).toFixed(2) + 's');
        slot.style.setProperty('--dur', (3.6 + rand() * 3.4).toFixed(2) + 's');
        slot.style.setProperty('--bd', (rand() * 3).toFixed(2) + 's');

        var img = document.createElement('img');
        img.src = 'assets/img/icons/ships/ship-' + SHIPS[idx % SHIPS.length] + '.webp';
        img.alt = '';
        img.decoding = 'async';
        // 遠景の小さな船は帆の柄が潰れるので、無彩色寄りにして奥行きを出す
        if (ri === 0) img.style.filter = 'saturate(.55) opacity(.9)';
        else if (ri === 1) img.style.filter = 'saturate(.8)';

        slot.appendChild(img);
        frag.appendChild(slot);
        idx++;
      }
    });
    return frag;
  }

  var fleetEl = document.getElementById('fleet');
  var fleetCfg = null;
  var fleetMode = null;

  function currentMode() {
    // CSS の @media (max-aspect-ratio:13/10) と必ず同じ条件にすること。
    // ずれると海景と船団の組み合わせが食い違い、船が陸に乗り上げる。
    return window.matchMedia('(max-aspect-ratio: 13/10)').matches ? 'tall' : 'wide';
  }

  function mountFleet() {
    if (!fleetEl) return;
    var mode = currentMode();
    if (mode === fleetMode) return;
    fleetMode = mode;
    fleetCfg = mode === 'tall' ? FLEET_TALL : FLEET_WIDE;
    fleetEl.innerHTML = '';
    fleetEl.appendChild(buildFleet(fleetCfg));
    sizeFleetFrame();
    // 一度でも表示済みなら、組み替え後もすぐ隊列を組んだ状態にする
    if (gathered) requestAnimationFrame(function () { fleetEl.classList.add('is-gathered'); });
  }

  /* background-size:cover と同じ式で .fleet の枠を海面に一致させる。
     この関数はモーション低減時も必ず実行する（実行しないと枠が
     0×0 に潰れて船がすべて消える）。 */
  function sizeFleetFrame() {
    if (!fleetEl || !fleetCfg) return;
    var hero = document.getElementById('hero');
    if (!hero) return;
    var W = hero.clientWidth, H = hero.clientHeight;
    var iw = fleetCfg.img[0], ih = fleetCfg.img[1];
    var scale = Math.max(W / iw, H / ih);
    var fw = iw * scale, fh = ih * scale;
    fleetEl.style.width = fw + 'px';
    fleetEl.style.height = fh + 'px';
    fleetEl.style.left = ((W - fw) / 2) + 'px';
    fleetEl.style.top = ((H - fh) * fleetCfg.anchorY) + 'px';
  }

  var gathered = false;
  function gatherFleet() {
    if (gathered || !fleetEl) return;
    gathered = true;
    fleetEl.classList.add('is-gathered');
  }

  mountFleet();
  window.addEventListener('resize', function () { mountFleet(); sizeFleetFrame(); });
  window.addEventListener('orientationchange', sizeFleetFrame);
  window.addEventListener('load', sizeFleetFrame);

  /* --------------------------------------------------------
     モーション低減：演出はすべて止め、完成状態を静止表示する
     -------------------------------------------------------- */
  if (reduceMotion) {
    document.querySelectorAll('.reveal').forEach(function (el) { el.classList.add('is-visible'); });
    gatherFleet();
    return;
  }

  /* --------------------------------------------------------
     スクロール演出
     -------------------------------------------------------- */
  var hasGSAP = typeof window.gsap !== 'undefined' && typeof window.ScrollTrigger !== 'undefined';

  if (hasGSAP) {
    gsap.registerPlugin(ScrollTrigger);

    document.querySelectorAll('.reveal').forEach(function (el, i) {
      ScrollTrigger.create({
        trigger: el,
        start: 'top 88%',
        once: true,
        onEnter: function () {
          setTimeout(function () { el.classList.add('is-visible'); }, (i % 5) * 70);
        }
      });
    });

    // 装飾部品の視差
    document.querySelectorAll('.section-deco').forEach(function (layer) {
      var sec = layer.closest('.section');
      layer.querySelectorAll('.deco').forEach(function (el, i) {
        var depth = 16 + (i % 3) * 12;
        gsap.fromTo(el, { '--py': depth + 'px' }, {
          '--py': -depth + 'px', ease: 'none',
          scrollTrigger: { trigger: sec, start: 'top bottom', end: 'bottom top', scrub: 0.6 }
        });
      });
    });

    // 船団：ヒーローに入ったら集結し、スクロールに合わせて前へ進む
    ScrollTrigger.create({ trigger: '#hero', start: 'top 92%', once: true, onEnter: gatherFleet });
    if (fleetEl) {
      gsap.fromTo(fleetEl, { '--advX': '0px' }, {
        '--advX': '-56px', ease: 'none',
        scrollTrigger: { trigger: '#hero', start: 'top top', end: 'bottom top', scrub: 0.8 }
      });
    }
  } else {
    // フォールバック
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (!e.isIntersecting) return;
        e.target.classList.add('is-visible');
        io.unobserve(e.target);
      });
    }, { rootMargin: '0px 0px -12% 0px', threshold: 0.05 });
    document.querySelectorAll('.reveal').forEach(function (el) { io.observe(el); });

    var heroIO = new IntersectionObserver(function (entries) {
      if (entries[0].isIntersecting) { gatherFleet(); heroIO.disconnect(); }
    }, { threshold: 0.05 });
    var heroEl = document.getElementById('hero');
    if (heroEl) heroIO.observe(heroEl);

    var ticking = false;
    window.addEventListener('scroll', function () {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(function () {
        var y = window.scrollY;
        document.querySelectorAll('.section-deco').forEach(function (layer) {
          var sec = layer.closest('.section');
          var r = sec.getBoundingClientRect();
          var p = 1 - (r.top + r.height) / (window.innerHeight + r.height);
          layer.querySelectorAll('.deco').forEach(function (el, i) {
            var depth = 16 + (i % 3) * 12;
            el.style.setProperty('--py', ((0.5 - p) * 2 * depth).toFixed(1) + 'px');
          });
        });
        if (fleetEl) {
          var hh = document.getElementById('hero').clientHeight || 1;
          fleetEl.style.setProperty('--advX', (-56 * Math.min(1, y / hh)).toFixed(1) + 'px');
        }
        ticking = false;
      });
    }, { passive: true });
  }

  // 保険：3秒経っても集結していなければ強制的に表示する
  setTimeout(gatherFleet, 3000);
})();
