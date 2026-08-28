/* ============================================================
   ひろしま協働DXプロジェクト スクロールLP — script.js
   - reveal-on-scroll (fade-up / left / right / scale) + stagger
   - GSAP ScrollTrigger を優先使用、読み込み失敗時は
     IntersectionObserver + CSS transition にフォールバック
   - 背景パララックス（data-speed）
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
     0. reduced-motion の場合はすべて即表示にして終了
     ------------------------------------------------------------ */
  if (reduceMotion) {
    document.querySelectorAll(".reveal").forEach(function (el) {
      el.classList.add("is-visible");
    });
    setupHeaderScroll();
    return; // パララックス・stagger・floatはCSS側で無効化済みなのでJSも何もしない
  }

  /* ------------------------------------------------------------
     1. stagger 用の遅延値 (--d) を各グループ内で設定
     ------------------------------------------------------------ */
  var STAGGER_STEP = 0.09; // seconds
  document.querySelectorAll("[data-stagger]").forEach(function (group) {
    var children = Array.prototype.slice.call(group.children);
    children.forEach(function (child, i) {
      child.style.setProperty("--d", i * STAGGER_STEP + "s");
    });
  });

  /* ------------------------------------------------------------
     2. ヘッダーのスクロール状態
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
     3. GSAP + ScrollTrigger が使えるか判定
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
     4a. GSAP ScrollTrigger 実装
     ------------------------------------------------------------ */
  function initGSAP() {
    gsap.registerPlugin(ScrollTrigger);

    // reveal 要素：一つずつ ScrollTrigger を張る（--d の遅延を尊重）
    document.querySelectorAll(".reveal").forEach(function (el) {
      var delay = parseFloat(
        (el.style.getPropertyValue("--d") || "0s").replace("s", "")
      ) || 0;

      gsap.to(el, {
        scrollTrigger: {
          trigger: el,
          start: "top 88%",
          toggleActions: "play none none none",
          once: true,
        },
        delay: delay,
        duration: 0.7,
        ease: "power2.out",
        onStart: function () {
          el.classList.add("is-visible");
        },
      });
    });

    // 背景パララックス
    var parallaxEls = document.querySelectorAll(".parallax-bg");
    parallaxEls.forEach(function (el) {
      var speedAttr = parseFloat(el.getAttribute("data-speed")) || 0.1;
      // スマホでは動きを控えめにする
      var speed = isMobile ? speedAttr * 0.4 : speedAttr;
      var section = el.closest(".section");
      if (!section) return;

      gsap.fromTo(
        el,
        { yPercent: -speed * 100 * 0.5 },
        {
          yPercent: speed * 100 * 0.5,
          ease: "none",
          scrollTrigger: {
            trigger: section,
            start: "top bottom",
            end: "bottom top",
            scrub: true,
          },
        }
      );
    });

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
     4b. フォールバック実装（IntersectionObserver + CSS transition）
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
    var parallaxEls = Array.prototype.slice.call(
      document.querySelectorAll(".parallax-bg")
    );
    if (parallaxEls.length) {
      var ticking = false;
      var updateParallax = function () {
        ticking = false;
        var vh = window.innerHeight;
        parallaxEls.forEach(function (el) {
          var section = el.closest(".section");
          if (!section) return;
          var rect = section.getBoundingClientRect();
          // セクションが画面内にあるときだけ計算
          if (rect.bottom < 0 || rect.top > vh) return;
          var speedAttr = parseFloat(el.getAttribute("data-speed")) || 0.1;
          var speed = isMobile ? speedAttr * 0.4 : speedAttr;
          var progress = (vh - rect.top) / (vh + rect.height); // 0..1
          var offset = (progress - 0.5) * speed * 100;
          el.style.transform = "translate3d(0," + offset.toFixed(2) + "%,0)";
        });
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
