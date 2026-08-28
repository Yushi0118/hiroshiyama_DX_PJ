/* ============================================================
   ひろしま協働DXプロジェクト スクロールLP — script.js
   - reveal-on-scroll (fade-up / left / right / scale) + stagger
   - 船団の「集結」と、スクロールに追従する前進
   - 装飾レイヤー（.deco）と ヒーロー背景（.parallax-bg）のパララックス
   - GSAP ScrollTrigger を優先使用、読み込み失敗時は
     IntersectionObserver + CSS transition にフォールバック
   - ヘッダーのスクロール状態切り替え
   - prefers-reduced-motion 対応
   ============================================================ */
(function () {
  "use strict";

  // JS が動いたことを示す（no-js フォールバック解除）
  document.documentElement.classList.remove("no-js");

  var reduceMotion =
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  var isMobile = window.matchMedia && window.matchMedia("(max-width: 767px)").matches;

  /* ------------------------------------------------------------
     0. 船団の「集結」
     .ship-slot は既定で opacity:0、かつ --dx/--dy の分だけ隊列から
     ずれた位置に置いてある。is-gathered を付けるとそれが 0 に向かって
     動き、ばらばらの小舟が船団になる（＝LPのコンセプトの視覚化）。
     どこで例外が起きても船が消えたままにならないよう、この予約だけは
     最初に済ませておく。
     ------------------------------------------------------------ */
  function gatherFleets() {
    var fleets = document.querySelectorAll(".fleet");
    for (var i = 0; i < fleets.length; i++) fleets[i].classList.add("is-gathered");
  }
  // 散らばった状態が一瞬見えてから集まるよう、わずかに遅らせる
  window.setTimeout(gatherFleets, reduceMotion ? 0 : 420);

  /* ------------------------------------------------------------
     1. 船団フレームのカバーフィット配置
     .fleet-viewport（= セクションいっぱいの窓）の中で、.fleet フレームを
     背景画像の background-size:cover と全く同じ計算式でサイズ・位置決めする。
     これにより、各船の left/top/width（%指定、元画像基準で配置）は
     ビューポートの縦横比が変わっても常に元画像の同じ場所を指し続ける
     （= 船が背景の陸地に乗り上げたり水平線からズレたりしない）。
     reduced-motion でも常に実行する必要がある（実行しないと .fleet が
     0×0 に潰れて船が消えてしまうため）。
     ------------------------------------------------------------ */
  function sizeFleetFrame(frame) {
    var viewport = frame.parentElement;
    if (!viewport) return;
    var vw = viewport.clientWidth;
    var vh = viewport.clientHeight;
    if (!vw || !vh) return;
    var imgW = parseFloat(frame.getAttribute("data-img-w")) || 1600;
    var imgH = parseFloat(frame.getAttribute("data-img-h")) || 900;
    var imgRatio = imgW / imgH;
    var viewRatio = vw / vh;
    var w, h;
    if (viewRatio > imgRatio) {
      w = vw;
      h = w / imgRatio;
    } else {
      h = vh;
      w = h * imgRatio;
    }
    frame.style.width = w + "px";
    frame.style.height = h + "px";
    frame.style.left = (vw - w) / 2 + "px";
    frame.style.top = (vh - h) / 2 + "px";
  }
  function sizeAllFleetFrames() {
    document.querySelectorAll(".fleet").forEach(sizeFleetFrame);
  }
  sizeAllFleetFrames();
  window.addEventListener("resize", debounce(sizeAllFleetFrames, 120));
  window.addEventListener("orientationchange", sizeAllFleetFrames);
  // フォント読み込み等による遅延レイアウト変化を拾うための保険再計算
  window.setTimeout(sizeAllFleetFrames, 300);

  /* ------------------------------------------------------------
     2. 装飾部品ごとのパララックス速度
     手前にあるもの（下辺の波の帯）ほど速く、遠くにあるもの
     （コンパス・空の葉）ほど遅く動かして奥行きを出す。
     .deco の transform は scaleX（左右反転）と合成する必要があるため、
     移動量は --py というカスタムプロパティ経由で渡す。
     ------------------------------------------------------------ */
  var DECO_SPEED = {
    "d-band": 0.17,
    "d-house": 0.10,
    "d-wave": 0.08,
    "d-sea": 0.07,
    "d-sweep": 0.07,
    "d-bridge": 0.06,
    "d-leaf": 0.05,
    "d-vine": 0.05,
    "d-gulls": 0.04,
    "d-compass": 0.03
  };
  /* 船団の前進量を適用する。t は 0（ヒーロー上端）〜1（ヒーローを抜けきる）。 */
  function applyFleetAdvance(fleets, t) {
    var x = (t * (isMobile ? -14 : -26)).toFixed(1) + "px";
    var y = (t * (isMobile ? 10 : 18)).toFixed(1) + "px";
    for (var i = 0; i < fleets.length; i++) {
      fleets[i].style.setProperty("--advX", x);
      fleets[i].style.setProperty("--advY", y);
    }
  }

  function decoAmplitude(el) {
    var speed = 0.06;
    for (var key in DECO_SPEED) {
      if (el.classList.contains(key)) { speed = DECO_SPEED[key]; break; }
    }
    // スマホでは動きを控えめにする（画面が狭く、動きが大きいと酔いやすい）
    return speed * (isMobile ? 0.45 : 1) * 320;
  }

  /* ------------------------------------------------------------
     3. reduced-motion の場合はすべて即表示にして終了
     ------------------------------------------------------------ */
  if (reduceMotion) {
    document.querySelectorAll(".reveal").forEach(function (el) {
      el.classList.add("is-visible");
    });
    gatherFleets();
    setupHeaderScroll();
    return; // パララックス・stagger・floatはCSS側で無効化済みなのでJSも何もしない
  }

  /* ------------------------------------------------------------
     4. stagger 用の遅延値 (--d) を各グループ内で設定
     ------------------------------------------------------------ */
  var STAGGER_STEP = 0.09; // seconds
  document.querySelectorAll("[data-stagger]").forEach(function (group) {
    var children = Array.prototype.slice.call(group.children);
    children.forEach(function (child, i) {
      child.style.setProperty("--d", i * STAGGER_STEP + "s");
    });
  });

  /* ------------------------------------------------------------
     5. ヘッダーのスクロール状態
     ------------------------------------------------------------ */
  function setupHeaderScroll() {
    var header = document.getElementById("siteHeader");
    if (!header) return;
    var toggle = function () {
      if (window.scrollY > 12) {
        header.classList.add("is-scrolled");
      } else {
        header.classList.remove("is-scrolled");
      }
    };
    toggle();
    window.addEventListener("scroll", toggle, { passive: true });
  }
  setupHeaderScroll();

  /* ------------------------------------------------------------
     6. GSAP + ScrollTrigger が使えるか判定
     ------------------------------------------------------------ */
  var hasGSAP =
    typeof window.gsap !== "undefined" &&
    typeof window.ScrollTrigger !== "undefined";

  if (hasGSAP) {
    initGSAP();
  } else {
    initFallback();
  }

  /* ------------------------------------------------------------
     7a. GSAP ScrollTrigger 実装
     ------------------------------------------------------------ */
  function initGSAP() {
    gsap.registerPlugin(ScrollTrigger);

    // reveal 要素：一つずつ ScrollTrigger を張る（--d の遅延を尊重）
    // フェードイン自体はCSSの transition が担当するので、ここでは
    // is-visible を付けるだけでよい。以前は「アニメーション対象のプロパティを
    // 持たない gsap.to() の onStart」に頼っていたが、GSAPは動かすものが無い
    // tween を再生しないため is-visible が付かず、GSAPがCDNから読める環境では
    // 本文がすべて opacity:0 のまま残ってしまっていた。ScrollTrigger を直接
    // 使うことでこの依存をなくす。
    document.querySelectorAll(".reveal").forEach(function (el) {
      var delay = parseFloat(
        (el.style.getPropertyValue("--d") || "0s").replace("s", "")
      ) || 0;

      ScrollTrigger.create({
        trigger: el,
        start: "top 88%",
        once: true,
        onEnter: function () {
          if (delay > 0) {
            window.setTimeout(function () { el.classList.add("is-visible"); }, delay * 1000);
          } else {
            el.classList.add("is-visible");
          }
        },
      });
    });

    // ヒーロー背景のパララックス
    document.querySelectorAll(".parallax-bg").forEach(function (el) {
      var speedAttr = parseFloat(el.getAttribute("data-speed")) || 0.1;
      var speed = isMobile ? speedAttr * 0.4 : speedAttr;
      var section = el.closest(".section");
      if (!section) return;
      gsap.fromTo(
        el,
        { yPercent: -speed * 50 },
        {
          yPercent: speed * 50,
          ease: "none",
          scrollTrigger: { trigger: section, start: "top bottom", end: "bottom top", scrub: true },
        }
      );
    });

    // 装飾部品のパララックス（部品ごとに速度が違う）
    document.querySelectorAll(".deco").forEach(function (el) {
      var section = el.closest(".section");
      if (!section) return;
      var amp = decoAmplitude(el);
      gsap.fromTo(
        el,
        { "--py": -amp + "px" },
        {
          "--py": amp + "px",
          ease: "none",
          scrollTrigger: { trigger: section, start: "top bottom", end: "bottom top", scrub: true },
        }
      );
    });

    // 船団の前進：ヒーローをスクロールしていく間、船団がわずかに手前へ寄る。
    // カスタムプロパティを直接 tween させるのではなく、素の数値を tween して
    // onUpdate で setProperty する（GSAPのCSS変数対応に依存しないため確実）。
    var hero = document.getElementById("hero");
    if (hero) {
      var fleets = document.querySelectorAll(".fleet");
      if (fleets.length) {
        var adv = { t: 0 };
        gsap.to(adv, {
          t: 1,
          ease: "none",
          scrollTrigger: { trigger: hero, start: "top top", end: "bottom top", scrub: true },
          onUpdate: function () {
            applyFleetAdvance(fleets, adv.t);
          },
        });
      }
    }

    // ビューポート変更時にモバイル判定を更新（回転など）
    window.addEventListener(
      "resize",
      debounce(function () {
        isMobile = window.matchMedia("(max-width: 767px)").matches;
        ScrollTrigger.refresh();
      }, 250)
    );
  }

  /* ------------------------------------------------------------
     7b. フォールバック実装（IntersectionObserver + CSS transition）
     ------------------------------------------------------------ */
  function initFallback() {
    if ("IntersectionObserver" in window) {
      var io = new IntersectionObserver(
        function (entries) {
          entries.forEach(function (entry) {
            if (entry.isIntersecting) {
              entry.target.classList.add("is-visible");
              io.unobserve(entry.target);
            }
          });
        },
        { threshold: 0.15, rootMargin: "0px 0px -8% 0px" }
      );
      document.querySelectorAll(".reveal").forEach(function (el) {
        io.observe(el);
      });
    } else {
      // IntersectionObserver 非対応ブラウザ：即表示
      document.querySelectorAll(".reveal").forEach(function (el) {
        el.classList.add("is-visible");
      });
    }

    // パララックス（scroll イベント + rAF、簡易版）
    var bgEls = Array.prototype.slice.call(document.querySelectorAll(".parallax-bg"));
    var decoEls = Array.prototype.slice.call(document.querySelectorAll(".deco"));
    var fleets = Array.prototype.slice.call(document.querySelectorAll(".fleet"));
    var hero = document.getElementById("hero");

    if (bgEls.length || decoEls.length || fleets.length) {
      var ticking = false;
      var updateParallax = function () {
        ticking = false;
        var vh = window.innerHeight;

        bgEls.forEach(function (el) {
          var section = el.closest(".section");
          if (!section) return;
          var rect = section.getBoundingClientRect();
          if (rect.bottom < 0 || rect.top > vh) return;
          var speedAttr = parseFloat(el.getAttribute("data-speed")) || 0.1;
          var speed = isMobile ? speedAttr * 0.4 : speedAttr;
          var progress = (vh - rect.top) / (vh + rect.height); // 0..1
          el.style.transform = "translate3d(0," + ((progress - 0.5) * speed * 100).toFixed(2) + "%,0)";
        });

        decoEls.forEach(function (el) {
          var section = el.closest(".section");
          if (!section) return;
          var rect = section.getBoundingClientRect();
          if (rect.bottom < 0 || rect.top > vh) return;
          var progress = (vh - rect.top) / (vh + rect.height); // 0..1
          el.style.setProperty("--py", ((progress - 0.5) * 2 * decoAmplitude(el)).toFixed(1) + "px");
        });

        if (hero && fleets.length) {
          var hr = hero.getBoundingClientRect();
          if (hr.bottom > 0 && hr.top < vh) {
            // ヒーローが上へ抜けていく割合（0..1）
            applyFleetAdvance(fleets, Math.min(1, Math.max(0, -hr.top / Math.max(1, hr.height))));
          }
        }
      };
      var onScroll = function () {
        if (!ticking) {
          window.requestAnimationFrame(updateParallax);
          ticking = true;
        }
      };
      updateParallax();
      window.addEventListener("scroll", onScroll, { passive: true });
      window.addEventListener(
        "resize",
        debounce(function () {
          isMobile = window.matchMedia("(max-width: 767px)").matches;
          updateParallax();
        }, 250)
      );
    }
  }

  /* ------------------------------------------------------------
     util
     ------------------------------------------------------------ */
  function debounce(fn, wait) {
    var t;
    return function () {
      clearTimeout(t);
      var args = arguments;
      t = setTimeout(function () {
        fn.apply(null, args);
      }, wait);
    };
  }
})();
