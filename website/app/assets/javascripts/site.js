// The comb's motion, GSAP only. On first load each comb assembles from its
// kernel outward; a small client router then carries cells and ticks between
// pages with Flip. Every route is still a real server-rendered page; without
// JavaScript or with reduced motion, links navigate normally or swap instantly.
(() => {
  const { gsap, Flip } = window;
  if (!gsap || !Flip) return;
  gsap.registerPlugin(Flip);

  const root = document.documentElement;
  const SETTLE = "expo.out";
  const SEAT = "back.out(1.6)";
  const MOVE = "expo.inOut";
  const FADE = [
    ".home-head", ".comb-title", ".row-label:not([data-flip-id])", ".hex-head", ".hex-userland",
    ".hex-kernel", ".kernel-caption", ".comb-lattice", ".pull-head > :not(.pull-name)", ".runs",
    ".loupe-notes", ".loupe-steps", ".ledger"
  ].join(",");
  // Hand cells back to CSS when a tween ends (hover dimming, the cells' own scale).
  // Never "all": that would also wipe the --col and --row position variables.
  const CLEAR = "opacity,visibility,transform,translate,rotate,scale";
  const moves = () => !matchMedia("(prefers-reduced-motion: reduce)").matches;
  let ctx = null;
  let pending = null;

  const centre = (el) => {
    const r = el.getBoundingClientRect();
    return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
  };

  // First load: the lattice draws on ring by ring, the kernel seats, then the cells
  // lock in from the kernel outward (userland, tests bottom-up, distro heads last).
  function assemble(main) {
    main.querySelectorAll(".comb").forEach((comb, s) => {
      const kernel = comb.querySelector(".hex-kernel");
      if (!kernel) return;
      const k = centre(kernel);
      const row = (el) => Number(el.style.getPropertyValue("--row"));
      const cells = [...comb.querySelectorAll(".hex:not(.hex-kernel)")].sort((a, b) => row(b) - row(a));
      const tl = gsap.timeline({ delay: 0.15 + s * 0.2, defaults: { ease: SETTLE } });

      [0, 1, 2].forEach((ring) => {
        const lines = comb.querySelectorAll(`.comb-lattice [data-ring="${ring}"]`);
        tl.fromTo(lines, { strokeDasharray: 1, strokeDashoffset: 1 },
          { strokeDashoffset: 0, duration: 0.9, ease: "power2.inOut", stagger: 0.01 }, ring * 0.18);
      });
      tl.from(kernel, { scale: 0.5, autoAlpha: 0, duration: 0.55, ease: SEAT, clearProps: CLEAR }, 0.1)
        .from(kernel.querySelector("svg"), { y: -18, autoAlpha: 0, duration: 0.5, ease: SEAT }, 0.4)
        .from(comb.querySelector(".kernel-caption"), { autoAlpha: 0, y: 6, duration: 0.4 }, 0.55);

      cells.forEach((cell) => {
        const c = centre(cell);
        const at = 0.55 + (6 - row(cell)) * 0.08;
        tl.from(cell, { x: (k.x - c.x) * 0.18, y: (k.y - c.y) * 0.18, autoAlpha: 0, duration: 0.55, ease: SEAT, clearProps: CLEAR }, at);
      });
      tl.from(comb.querySelectorAll(".comb-title, .row-label"), { autoAlpha: 0, duration: 0.5 }, 1.0);
    });
  }

  // A test page loaded directly: each number of a raw string travels to its tick.
  function drop(main) {
    main.querySelectorAll(".run-lane").forEach((lane, li) => {
      const tokens = lane.querySelectorAll(".raw b");
      lane.querySelectorAll(".band i").forEach((tick, i) => {
        const from = tokens[i].getBoundingClientRect();
        const to = tick.getBoundingClientRect();
        const delay = 0.3 + li * 0.06 + i * 0.04;
        gsap.from(tick, {
          x: from.left + from.width / 2 - to.left,
          y: from.top + from.height / 2 - (to.top + to.height / 2),
          scaleY: 0.3, duration: 0.7, ease: SETTLE, delay, clearProps: CLEAR
        });
        gsap.from(tokens[i], { color: getComputedStyle(tick).backgroundColor, duration: 0.9, delay, clearProps: "color" });
      });
    });
  }

  function enter(main, state) {
    ctx?.revert();
    // Lift the pre-paint mask first: autoAlpha reads a hidden element's alpha as 0, so
    // tweens built under the mask would animate to invisible. Same frame, so no flash.
    root.classList.remove("intro");
    ctx = gsap.context(() => {
      if (!moves()) return;
      if (!state) {
        assemble(main);
        drop(main);
        return;
      }
      const targets = main.querySelectorAll("[data-flip-id]");
      Flip.from(state, {
        targets,
        duration: 0.85,
        ease: MOVE,
        scale: true,
        onEnter: (els) => gsap.from(els, { autoAlpha: 0, duration: 0.5, delay: 0.35, clearProps: CLEAR }),
        onComplete: () => {
          gsap.set(targets, { clearProps: CLEAR }); // Flip ignores clearProps; hand cells back to CSS
          ctx?.add(() => drop(main));
        }
      });
      gsap.from(main.querySelectorAll(FADE), {
        autoAlpha: 0, duration: 0.5, ease: SETTLE, delay: 0.3, stagger: 0.015, clearProps: "opacity,visibility"
      });
    }, main);
  }

  function syncHead(doc) {
    document.title = doc.title;
    for (const sel of ['meta[name="description"]', 'meta[property="og:title"]', 'meta[property="og:description"]', 'link[rel="canonical"]']) {
      const next = doc.head.querySelector(sel);
      const here = document.head.querySelector(sel);
      if (next && here) here.replaceWith(next.cloneNode(true));
    }
  }

  async function go(url, push) {
    const request = (pending = fetch(url, { headers: { Accept: "text/html" } }));
    let response;
    try {
      response = await request;
    } catch {
      location.href = url;
      return;
    }
    if (request !== pending) return;
    const doc = response.ok ? new DOMParser().parseFromString(await response.text(), "text/html") : null;
    const next = doc?.querySelector("main");
    if (!next) {
      location.href = url;
      return;
    }
    const state = moves() ? Flip.getState("[data-flip-id]", { props: "opacity" }) : null;
    ctx?.revert();
    root.classList.remove("intro");
    const main = document.importNode(next, true);
    document.querySelector("main").replaceWith(main);
    syncHead(doc);
    if (push) history.pushState(null, "", url);
    scrollTo(0, 0);
    main.focus({ preventScroll: true });
    enter(main, state);
  }

  const internal = (a) =>
    a.origin === location.origin && !a.target && !a.hasAttribute("download") && /\/$/.test(a.pathname);

  document.addEventListener("click", (event) => {
    const a = event.target.closest("a[href]");
    if (!a || event.defaultPrevented || event.button || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    if (!internal(a)) return;
    if (a.pathname === location.pathname) {
      if (!a.hash) event.preventDefault();
      return;
    }
    event.preventDefault();
    go(a.href, true);
  });

  addEventListener("popstate", () => go(location.href, false));

  addEventListener("keydown", (event) => {
    if (event.key === "Escape" && document.querySelector(".pull")) go(`${location.origin}/`, true);
  });

  enter(document.querySelector("main"), null);
})();
