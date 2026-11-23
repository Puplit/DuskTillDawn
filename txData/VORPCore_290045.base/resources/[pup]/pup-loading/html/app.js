/* pup-loading: builds the screen from config.js, rotates tips and backgrounds,
   plays the music, and fills the progress bar from the game's load events. */

/* ---- config, with defaults for anything left out ---- */
const C = window.LoadingConfig || {};
const cfg = (obj, key, fallback) => (obj && obj[key] !== undefined ? obj[key] : fallback);

const colors     = C.colors || {};
const background = C.background || {};
const tips       = C.tips || {};
const progress   = C.progress || {};
const music      = C.music || {};
const logo       = C.logo || {};

const $ = (id) => document.getElementById(id);
const show = (el, on) => { if (el) el.style.display = on ? '' : 'none'; };

/* ---- theme ---- */
const root = document.documentElement.style;
if (colors.text)       root.setProperty('--parchment', colors.text);
if (colors.textDim)    root.setProperty('--parchment-dim', colors.textDim);
if (colors.accent)     root.setProperty('--gold', colors.accent);
if (colors.accentDark) root.setProperty('--gold-dark', colors.accentDark);
if (colors.background) root.setProperty('--bg', colors.background);
root.setProperty('--darken', String(cfg(background, 'darken', 1)));

if (C.titleFont) {
    const face = new FontFace('PupTitle', `url('${C.titleFont}')`);
    face.load().then((f) => document.fonts.add(f)).catch(() => {});
} else {
    root.setProperty('--serif', "Georgia, 'Times New Roman', serif");
}

/* ---- text ---- */
document.title = cfg(C, 'title', 'Loading');
$('title').textContent = cfg(C, 'title', '');
$('subtitle').textContent = cfg(C, 'subtitle', '');
show($('subtitle'), !!C.subtitle);
show($('rule'), cfg(C, 'showRule', true));

const logoEl = $('logo');
if (logo.image) {
    logoEl.src = logo.image;
    logoEl.style.height = `${cfg(logo, 'height', 14)}vh`;
} else {
    show(logoEl, false);
}

/* ---- links ---- */
const linksEl = $('links');
(C.links || []).forEach((l) => {
    const row = document.createElement('div');
    row.className = 'link';
    row.innerHTML = '<span class="link-label"></span><span class="link-value"></span>';
    row.children[0].textContent = l.label || '';
    row.children[1].textContent = l.value || '';
    linksEl.appendChild(row);
});

/* ---- background: one image, or a cross-fading slideshow ---- */
const images = (background.images && background.images.length) ? background.images : [];
const layers = [$('banner-a'), $('banner-b')];
layers.forEach((l) => l.classList.toggle('drift', cfg(background, 'drift', true)));
let slide = 0;
let front = 0;
if (images.length) {
    layers[0].style.backgroundImage = `url('${images[0]}')`;
    layers[0].classList.add('visible');
}
if (images.length > 1) {
    setInterval(() => {
        slide = (slide + 1) % images.length;
        const back = 1 - front;
        layers[back].style.backgroundImage = `url('${images[slide]}')`;
        layers[back].classList.add('visible');
        layers[front].classList.remove('visible');
        front = back;
    }, cfg(background, 'slideSeconds', 12) * 1000);
}

/* ---- tips ---- */
const tipList = tips.list || [];
const tipEl = $('tip');
show($('tips'), cfg(tips, 'enabled', true) && tipList.length > 0);
$('tip-label').textContent = cfg(tips, 'label', '');
if (tipList.length) {
    let tipIndex = cfg(tips, 'randomStart', true) ? Math.floor(Math.random() * tipList.length) : 0;
    tipEl.textContent = tipList[tipIndex];
    if (tipList.length > 1) {
        setInterval(() => {
            tipEl.style.opacity = '0';
            setTimeout(() => {
                tipIndex = (tipIndex + 1) % tipList.length;
                tipEl.textContent = tipList[tipIndex];
                tipEl.style.opacity = '1';
            }, 500);
        }, cfg(tips, 'rotateSeconds', 6) * 1000);
    }
}

/* ---- team: names from config.js, as text ---- */
const team = C.team || {};
const teamGroups = (team.groups || []).filter((g) => g && g.names && g.names.length);
const teamOn = cfg(team, 'enabled', true) && teamGroups.length > 0;
show($('team'), teamOn);
if (teamOn) {
    $('team-label').textContent = cfg(team, 'label', '');
    const listEl = $('team-list');
    teamGroups.forEach((g) => {
        const box = document.createElement('div');
        box.className = 'team-group';
        const rank = document.createElement('div');
        rank.className = 'team-rank';
        rank.textContent = g.rank || '';
        box.appendChild(rank);
        g.names.forEach((n) => {
            const name = document.createElement('div');
            name.className = 'team-name';
            name.textContent = n;
            box.appendChild(name);
        });
        listEl.appendChild(box);
    });
    /* a long team drifts down and back so everyone gets seen, and stops while the mouse is on it */
    let dir = 1;
    let held = false;
    let wait = 40;
    listEl.addEventListener('mouseenter', () => { held = true; });
    listEl.addEventListener('mouseleave', () => { held = false; });
    setInterval(() => {
        const room = listEl.scrollHeight - listEl.clientHeight;
        if (room <= 1 || held) return;
        if (wait > 0) { wait--; return; }
        listEl.scrollTop += dir;
        if (listEl.scrollTop >= room - 1) { dir = -1; wait = 60; }
        else if (listEl.scrollTop <= 0) { dir = 1; wait = 60; }
    }, 50);
}

/* ---- guides: pages from config.js, as text ---- */
const guide = C.guide || {};
const guidePages = guide.pages || [];
const guideOn = cfg(guide, 'enabled', true) && guidePages.length > 0;
show($('guide'), guideOn);
if (guideOn) {
    $('guide-label').textContent = cfg(guide, 'label', '');
    const pageEl = $('guide-page');
    const dotsEl = $('guide-dots');
    const many = guidePages.length > 1;
    show($('guide-nav'), many);
    let pageIndex = 0;
    let guideHeld = false;
    let sinceTurn = 0;

    const add = (host, cls, text) => {
        const d = document.createElement('div');
        d.className = cls;
        d.textContent = text;
        host.appendChild(d);
        return d;
    };

    const drawPage = () => {
        const p = guidePages[pageIndex];
        pageEl.innerHTML = '';
        add(pageEl, 'guide-title', p.title || '');
        if (p.intro) add(pageEl, 'guide-intro', p.intro);
        /* keys and their text in a two-column grid: the key column is as wide as this page's longest key */
        if ((p.rows || []).length) {
            const grid = document.createElement('div');
            grid.className = 'guide-grid';
            p.rows.forEach((r) => {
                add(grid, 'guide-key', r.key || '');
                add(grid, 'guide-text', r.text || '');
            });
            pageEl.appendChild(grid);
        }
        (p.lines || []).forEach((t) => add(pageEl, 'guide-line', t));
        dotsEl.querySelectorAll('.guide-dot').forEach((dot, i) => dot.classList.toggle('on', i === pageIndex));
        pageEl.classList.remove('turn');
        void pageEl.offsetWidth; /* restarts the fade */
        pageEl.classList.add('turn');
    };

    const turn = (by) => {
        pageIndex = (pageIndex + by + guidePages.length) % guidePages.length;
        sinceTurn = 0;
        drawPage();
    };

    if (many) {
        guidePages.forEach((_, i) => {
            const dot = document.createElement('div');
            dot.className = 'guide-dot';
            dot.addEventListener('click', () => turn(i - pageIndex));
            dotsEl.appendChild(dot);
        });
        $('guide-prev').addEventListener('click', () => turn(-1));
        $('guide-next').addEventListener('click', () => turn(1));
        window.addEventListener('keydown', (e) => {
            if (e.key === 'ArrowLeft') { e.preventDefault(); turn(-1); }
            if (e.key === 'ArrowRight') { e.preventDefault(); turn(1); }
        });
        /* the page stays put while someone has the mouse on it, reading */
        $('guide').addEventListener('mouseenter', () => { guideHeld = true; });
        $('guide').addEventListener('mouseleave', () => { guideHeld = false; });
        const everySeconds = cfg(guide, 'rotateSeconds', 14);
        setInterval(() => {
            if (guideHeld) return;
            sinceTurn++;
            if (sinceTurn >= everySeconds) turn(1);
        }, 1000);
    }
    /* the card is as tall as its tallest page: no empty gap under short pages,
       and the arrows don't jump as pages turn. Measured again once the fonts
       arrive and when the window changes size. */
    const fitGuide = () => {
        const keep = pageIndex;
        pageEl.style.height = 'auto';
        let tallest = 0;
        for (let i = 0; i < guidePages.length; i++) {
            pageIndex = i;
            drawPage();
            tallest = Math.max(tallest, pageEl.scrollHeight);
        }
        pageIndex = keep;
        drawPage();
        pageEl.style.height = `${tallest}px`;
    };
    fitGuide();
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(fitGuide);
    window.addEventListener('resize', fitGuide);
}

/* ---- music ----
   LEVELS is a curve, not an even split: what matters on a loading screen is the
   quiet end, so it gets fine steps. The player's choice is saved, so turning the
   music off sticks between loads. localStorage can throw in embedded browsers,
   so every access is guarded. */
const LEVELS = [0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.50, 0.70, 1.00];
const VOL_KEY = 'pupLoadingVolume';
const PAUSE_KEY = 'pupLoadingPaused';

// closest level to the configured 0-100 volume
const wanted = Math.max(0, Math.min(100, cfg(music, 'volume', 35))) / 100;
const DEFAULT_INDEX = LEVELS.reduce((best, v, i) => (Math.abs(v - wanted) < Math.abs(LEVELS[best] - wanted) ? i : best), 0);
const FADE_MS = cfg(music, 'fadeInSeconds', 4) * 1000;

const theme = $('theme');
const ctlEl = $('audio-ctl');
const iconEl = $('ac-icon');
const barsEl = $('ac-bars');

const musicOn = cfg(music, 'enabled', true) && (music.tracks || []).length > 0;
show(ctlEl, musicOn && cfg(music, 'showControls', true));

let tracks = musicOn ? music.tracks.slice() : [];
if (cfg(music, 'shuffle', false)) tracks.sort(() => Math.random() - 0.5);
let trackIndex = 0;
if (musicOn) {
    // a listed file that is missing or will not decode: hide the controls rather than show a dead player
    theme.addEventListener('error', () => { cancelFade(); show(ctlEl, false); });
    theme.src = tracks[0];
    theme.loop = tracks.length === 1;
    theme.addEventListener('ended', () => {
        trackIndex = (trackIndex + 1) % tracks.length;
        theme.src = tracks[trackIndex];
        const p = theme.play();
        if (p && typeof p.catch === 'function') p.catch(() => {});
    });
}

function stored(key, fallback) {
    try {
        const v = localStorage.getItem(key);
        return v === null ? fallback : v;
    } catch (e) {
        return fallback;
    }
}

function store(key, value) {
    try { localStorage.setItem(key, value); } catch (e) { /* private mode: session only */ }
}

let volIndex = parseInt(stored(VOL_KEY, DEFAULT_INDEX), 10);
if (!Number.isInteger(volIndex) || volIndex < 0 || volIndex >= LEVELS.length) volIndex = DEFAULT_INDEX;
let paused = stored(PAUSE_KEY, '0') === '1';
let lastAudible = volIndex > 0 ? volIndex : DEFAULT_INDEX; /* what M restores to */
let fadeTimer = null;

/* one clickable segment per level above silence */
for (let i = 1; i < LEVELS.length; i++) {
    const bar = document.createElement('div');
    bar.className = 'ac-bar';
    bar.dataset.i = i;
    bar.addEventListener('click', () => setVolume(i));
    barsEl.appendChild(bar);
}

function paintControls() {
    barsEl.querySelectorAll('.ac-bar').forEach((bar) => {
        bar.classList.toggle('on', Number(bar.dataset.i) <= volIndex);
    });
    iconEl.innerHTML = paused ? '&#9654;' : '&#10074;&#10074;';
    ctlEl.classList.toggle('paused', paused);
    $('ac-toggle').title = paused ? 'Play the music (P)' : 'Pause the music (P)';
}

/* a deliberate volume change cancels the intro fade, or the fade keeps
   climbing back over what the player just chose */
function cancelFade() {
    if (fadeTimer !== null) { clearInterval(fadeTimer); fadeTimer = null; }
}

function applyVolume() {
    theme.volume = LEVELS[volIndex];
}

function setVolume(i) {
    if (!musicOn) return;
    cancelFade();
    volIndex = Math.max(0, Math.min(LEVELS.length - 1, i));
    if (volIndex > 0) lastAudible = volIndex;
    store(VOL_KEY, volIndex);
    applyVolume();
    paintControls();
}

function setPaused(value) {
    if (!musicOn) return;
    paused = value === true;
    store(PAUSE_KEY, paused ? '1' : '0');
    if (paused) {
        cancelFade();
        theme.pause();
    } else {
        applyVolume();
        const p = theme.play();
        if (p && typeof p.catch === 'function') p.catch(() => {});
    }
    paintControls();
}

function fadeIn(el, target, ms) {
    cancelFade();
    if (target <= 0 || ms <= 0) { el.volume = target; return; }
    const steps = 40;
    const step = target / steps;
    let v = 0;
    fadeTimer = setInterval(() => {
        v = Math.min(target, v + step);
        el.volume = v;
        if (v >= target) cancelFade();
    }, ms / steps);
}

if (musicOn) {
    theme.volume = 0;
    if (!paused) {
        const p = theme.play();
        // play() rejects when autoplay is refused: retry on the first key or click
        if (p && typeof p.catch === 'function') {
            p.then(() => fadeIn(theme, LEVELS[volIndex], FADE_MS))
             .catch(() => {
                 const retry = () => {
                     if (!paused) {
                         theme.play().then(() => fadeIn(theme, LEVELS[volIndex], FADE_MS)).catch(() => {});
                     }
                     window.removeEventListener('keydown', retry);
                     window.removeEventListener('mousedown', retry);
                 };
                 window.addEventListener('keydown', retry);
                 window.addEventListener('mousedown', retry);
             });
        } else {
            fadeIn(theme, LEVELS[volIndex], FADE_MS);
        }
    }

    $('ac-toggle').addEventListener('click', () => setPaused(!paused));
    $('ac-up').addEventListener('click', () => setVolume(volIndex + 1));
    $('ac-down').addEventListener('click', () => setVolume(volIndex - 1));

    window.addEventListener('keydown', (e) => {
        switch (e.key) {
            case 'p': case 'P': case ' ':
                e.preventDefault(); setPaused(!paused); break;
            case 'm': case 'M':
                e.preventDefault(); setVolume(volIndex > 0 ? 0 : lastAudible); break;
            case 'ArrowUp': case '+': case '=':
                e.preventDefault(); setVolume(volIndex + 1); break;
            case 'ArrowDown': case '-': case '_':
                e.preventDefault(); setVolume(volIndex - 1); break;
            default: break;
        }
    });
    paintControls();
}

/* ---- progress: real events when the game sends them ---- */
const barEl = $('bar-fill');
const statusEl = $('status');
const percentEl = $('percent');
const setBar = (pct) => {
    barEl.style.width = `${pct}%`;
    percentEl.textContent = `${Math.round(pct)}%`;
};
show($('progress'), cfg(progress, 'enabled', true));
statusEl.textContent = cfg(progress, 'statusStart', '');
const statuses = progress.statuses || {};
let sawRealProgress = false;

window.addEventListener('message', (e) => {
    const msg = e.data;
    if (!msg || !msg.eventName) return;
    if (msg.eventName === 'loadProgress' && typeof msg.loadFraction === 'number') {
        sawRealProgress = true;
        setBar(Math.min(100, Math.max(0, msg.loadFraction * 100)));
        return;
    }
    if (statuses[msg.eventName]) statusEl.textContent = statuses[msg.eventName];
});

/* if this build never sends loadProgress, creep toward 90% so the bar still
   shows life without ever claiming "done" */
let fake = 0;
const fakeTimer = setInterval(() => {
    if (sawRealProgress) { clearInterval(fakeTimer); return; }
    fake = Math.min(90, fake + Math.random() * 7);
    setBar(fake);
}, 900);
