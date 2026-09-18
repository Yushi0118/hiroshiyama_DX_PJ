/* Scroll is observed, never intercepted. No dependency on CSS scroll timelines. */
(function () {
  'use strict';
  var root = document.getElementById('fleet-story');
  if (!root) return;
  var boats = Array.from(root.querySelectorAll('.fleet-boat'));
  var labels = Array.from(root.querySelectorAll('.fleet-label'));
  var chapters = Array.from(root.querySelectorAll('.fleet-chapters li'));
  var ocean = root.querySelector('.fleet-ocean');
  var end = root.querySelector('.fleet-destination');
  var reduce = matchMedia('(prefers-reduced-motion: reduce)');
  var desktop = matchMedia('(min-width: 768px) and (min-height: 700px)');
  var pending = false, active = true;
  var start = [[20,36],[28,74],[76,60],[90,30]];
  var gathered = [[42,43],[29,64],[57,65],[71,44]];
  function clamp(n) { return Math.max(0, Math.min(1,n)); }
  function smooth(n) { n=clamp(n); return n*n*(3-2*n); }
  function render(p) {
    var gather=smooth((p-.18)/.30), join=smooth((p-.49)/.19), sail=smooth((p-.73)/.27);
    var chapter=p<.23?0:p<.51?1:p<.76?2:3;
    chapters.forEach(function(el,i){
      el.classList.toggle('is-current',i===chapter);
      el.setAttribute('aria-hidden',i===chapter?'false':'true');
    });
    boats.forEach(function(el,i){
      var t=i===3?join:gather;
      var x=start[i][0]+(gathered[i][0]-start[i][0])*t+sail*8;
      var y=start[i][1]+(gathered[i][1]-start[i][1])*t-sail*5;
      el.style.left=x+'%';el.style.top=y+'%';
      el.style.opacity=i===3?join:1;
      labels[i].style.opacity=i===3?join:1-smooth((p-.2)/.16);
    });
    end.style.opacity=smooth((p-.75)/.15);
    root.style.setProperty('--fleet-p',p);
  }
  function update() {
    pending=false;
    if(reduce.matches || !active) return;
    var box=root.getBoundingClientRect();
    var p;
    if(desktop.matches){
      p=clamp(-box.top/Math.max(1,box.height-innerHeight));
    } else {
      // Mobile has no pin: complete the short story as the illustration enters.
      var art=ocean.getBoundingClientRect();
      p=clamp((innerHeight*.98-art.top)/Math.max(1,innerHeight*.7));
    }
    render(p);
  }
  function queue() {
    if(!pending && !reduce.matches && active){pending=true;requestAnimationFrame(update);}
  }
  function setup() {
    root.classList.toggle('is-enhanced',!reduce.matches);
    root.classList.toggle('is-pinned',!reduce.matches && desktop.matches);
    if(reduce.matches){
      boats.forEach(function(el){el.removeAttribute('style');});
      labels.forEach(function(el){el.removeAttribute('style');});
      chapters.forEach(function(el){el.removeAttribute('aria-hidden');el.classList.remove('is-current');});
      end.removeAttribute('style');
      root.style.removeProperty('--fleet-p');
    } else { active=true;queue(); }
  }
  addEventListener('scroll',queue,{passive:true});
  addEventListener('resize',queue,{passive:true});
  reduce.addEventListener('change',setup);
  desktop.addEventListener('change',setup);
  if('IntersectionObserver' in window){
    new IntersectionObserver(function(entries){
      active=entries[0].isIntersecting;
      if(active) queue();
    },{rootMargin:'100% 0px'}).observe(root);
  }
  setup();
})();

