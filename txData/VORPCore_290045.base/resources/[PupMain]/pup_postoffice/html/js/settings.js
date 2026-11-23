/* pup_postoffice | the player's own look: presets, validation, migration and applying it */
'use strict';

const LOOK = (() => {
    const THEMES = [
        { id: 'saddle', label: 'Saddle & Brass', note: 'Dark leather, antique gold', c: ['#0d0a07', '#16110c', '#1e1710', '#2a2017', '#ecdfc4', '#a8977a', '#6c5f4b', '#c9a24d'], light: false },
        { id: 'midnight', label: 'Midnight Ledger', note: 'Near black, pale brass', c: ['#08080a', '#101013', '#17171b', '#212127', '#e6e1d6', '#9d978b', '#5f5b53', '#d4b56c'], light: false },
        { id: 'oxblood', label: 'Oxblood', note: 'Deep red leather, copper', c: ['#0f0706', '#190c0a', '#22110e', '#2f1813', '#f0dccd', '#b08f7f', '#715246', '#c7814a'], light: false },
        { id: 'ironwood', label: 'Ironwood', note: 'Weathered olive, pewter', c: ['#0b0c09', '#13150f', '#1a1d16', '#252920', '#e4e6da', '#9ca08e', '#60645a', '#b9b27a'], light: false },
        { id: 'gunmetal', label: 'Gunmetal', note: 'Charcoal and nickel', c: ['#0a0b0c', '#121416', '#191c1f', '#23272b', '#e3e6e8', '#9aa1a6', '#5d6469', '#b8c2c8'], light: false },
        { id: 'bone', label: 'Bone & Ink', note: 'Light parchment, iron gall ink', c: ['#d9ccb0', '#e8dcc2', '#f1e7d2', '#ded0b2', '#2a2118', '#5f5140', '#8d7d65', '#8a5a22'], light: true },
    ];
    const ACCENTS = ['#c9a24d', '#d8b464', '#b87333', '#a8432e', '#7f9b5a', '#6d8fa8', '#b8c2c8', '#9b6fb0'];

    // the first ten may dress the interface; letters may use all thirteen
    const FONTS = [
        { id: 'lino', label: 'Frontier Serif', stack: "'Alegreya', Georgia, serif" },
        { id: 'garamond', label: 'Garamond', stack: "'EB Garamond', Garamond, Georgia, serif" },
        { id: 'baskerville', label: 'Baskerville', stack: "'Libre Baskerville', Baskerville, Georgia, serif" },
        { id: 'copperplate', label: 'Copperplate', stack: "'Cormorant Garamond', Georgia, serif" },
        { id: 'storybook', label: 'Storybook', stack: "'Crimson Text', Georgia, serif" },
        { id: 'almanac', label: 'Almanac', stack: "'Old Standard TT', Georgia, serif" },
        { id: 'chronicle', label: 'Chronicle', stack: "'Lora', Georgia, serif" },
        { id: 'gazette', label: 'Gazette', stack: "'Spectral', Georgia, serif" },
        { id: 'timber', label: 'Timber', stack: "'Bitter', Georgia, serif" },
        { id: 'fell', label: 'Fell', stack: "'IM Fell English', Georgia, serif" },
        { id: 'typewriter', label: 'Typewriter', stack: "'Courier Prime', 'Courier New', monospace" },
        { id: 'telegram', label: 'Telegram', stack: "'Special Elite', 'Courier New', monospace" },
        { id: 'quill', label: 'Quill Hand', stack: "'Homemade Apple', 'Segoe Script', cursive" },
    ];
    const UI_FONTS = FONTS.slice(0, 10);

    const PAPERS = [
        { id: 'parchment', label: 'Parchment' },
        { id: 'stationery', label: 'Stationery' },
        { id: 'ruled', label: 'Ruled Letter' },
        { id: 'plain', label: 'Plain Sheet' },
        { id: 'crumpled', label: 'Crumpled' },
        { id: 'telegram', label: 'Telegram' },
        { id: 'ledger', label: 'Ledger' },
    ];

    const DEFAULTS = {
        v: 2, theme: 'saddle', accent: '', uiFont: 'lino', letterFont: 'typewriter', paper: '',
        scale: 100, textSize: 100, opacity: 96, dim: 35,
        layout: 'expanded', density: 'comfortable', anchor: 'center', dx: 0, dy: 0, motion: 'full',
        seal: true, ornaments: true, watermark: true, texture: true, favorites: [],
        bubble: 'parchment', enterSends: true,
    };
    const BUBBLES = [
        { id: 'parchment', label: 'Parchment' },
        { id: 'stationery', label: 'Stationery' },
        { id: 'telegram', label: 'Telegram' },
    ];

    const V1_THEME = { parchment: 'saddle', sepia: 'saddle', bone: 'bone', oxblood: 'oxblood', ironwood: 'ironwood', midnight: 'midnight' };
    const V1_CHROME = { ledger: 'lino', storybook: 'storybook', garamond: 'garamond', fell: 'fell', almanac: 'almanac', baskerville: 'baskerville', chronicle: 'chronicle', copperplate: 'copperplate', gazette: 'gazette', timber: 'timber' };

    const ids = list => new Set(list.map(x => x.id));
    const THEME_IDS = ids(THEMES), UI_IDS = ids(UI_FONTS), FONT_IDS = ids(FONTS), PAPER_IDS = ids(PAPERS);
    const HEX = /^#[0-9a-f]{6}$/i;

    function pick(v, allowed, dflt) { return allowed.has(v) ? v : dflt; }
    function range(v, lo, hi, dflt) {
        const n = Number(v);
        if (!Number.isFinite(n)) return dflt;
        return Math.min(hi, Math.max(lo, Math.round(n)));
    }
    function bool(v, dflt) { return typeof v === 'boolean' ? v : dflt; }

    function validate(raw) {
        const r = (raw && typeof raw === 'object') ? raw : {};
        const s = { v: 2 };
        s.theme = pick(r.theme, THEME_IDS, DEFAULTS.theme);
        s.accent = (typeof r.accent === 'string' && HEX.test(r.accent)) ? r.accent.toLowerCase() : '';
        s.uiFont = pick(r.uiFont, UI_IDS, DEFAULTS.uiFont);
        s.letterFont = pick(r.letterFont, FONT_IDS, DEFAULTS.letterFont);
        s.paper = r.paper === '' ? '' : pick(r.paper, PAPER_IDS, '');
        s.scale = range(r.scale, 75, 130, DEFAULTS.scale);
        s.textSize = range(r.textSize, 85, 130, DEFAULTS.textSize);
        s.opacity = range(r.opacity, 60, 100, DEFAULTS.opacity);
        s.dim = range(r.dim, 0, 80, DEFAULTS.dim);
        s.layout = pick(r.layout, new Set(['expanded', 'compact']), DEFAULTS.layout);
        s.density = pick(r.density, new Set(['comfortable', 'compact']), DEFAULTS.density);
        s.anchor = pick(r.anchor, new Set(['center', 'left', 'right']), DEFAULTS.anchor);
        s.dx = range(r.dx, -4000, 4000, 0);
        s.dy = range(r.dy, -3000, 3000, 0);
        s.motion = pick(r.motion, new Set(['full', 'reduced', 'off']), DEFAULTS.motion);
        s.seal = bool(r.seal, true);
        s.ornaments = bool(r.ornaments, true);
        s.watermark = bool(r.watermark, true);
        s.texture = bool(r.texture, true);
        s.bubble = pick(r.bubble, new Set(BUBBLES.map(b => b.id)), DEFAULTS.bubble);
        s.enterSends = bool(r.enterSends, true);
        s.favorites = Array.isArray(r.favorites)
            ? Array.from(new Set(r.favorites.filter(x => typeof x === 'string' || typeof x === 'number').map(String))).slice(0, 500)
            : [];
        return s;
    }

    function migrateV1(r) {
        const out = {};
        if (V1_THEME[r.theme]) out.theme = V1_THEME[r.theme];
        if (V1_CHROME[r.chrome]) out.uiFont = V1_CHROME[r.chrome];
        if (FONT_IDS.has(r.letter)) out.letterFont = r.letter;
        if (PAPER_IDS.has(r.paper)) out.paper = r.paper;
        if (r.scale !== undefined) out.scale = r.scale;
        if (typeof r.desk === 'boolean') out.ornaments = r.desk; // older name of the ornaments switch
        return out;
    }

    function load(rawText) {
        let parsed = null;
        try { parsed = rawText ? JSON.parse(rawText) : null; } catch (e) { parsed = null; }
        if (!parsed || typeof parsed !== 'object') return validate({});
        if (Number(parsed.v) !== 2) return validate(migrateV1(parsed));
        return validate(parsed);
    }

    function serialize(s) {
        const text = JSON.stringify(validate(s));
        return text.length <= 16384 ? text : null;
    }

    function luminance(hex) {
        const n = parseInt(hex.slice(1), 16);
        const ch = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map(v => {
            v /= 255;
            return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        });
        return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2];
    }

    function themeOf(id) { return THEMES.find(t => t.id === id) || THEMES[0]; }
    function fontOf(id) { return FONTS.find(f => f.id === id) || FONTS[0]; }

    /** Effective decoration switches: the server can turn things off, never on. */
    function effective(s, branding) {
        const b = branding || {};
        return {
            seal: s.seal && b.seal !== false,
            ornaments: s.ornaments && b.ornaments !== false,
            watermark: s.watermark && b.watermark !== false && !!b.logo,
            texture: s.texture,
            paper: s.paper || (PAPER_IDS.has(b.paper) ? b.paper : 'parchment'),
        };
    }

    /** Push the look onto the document. */
    function apply(s, branding) {
        const root = document.documentElement;
        const t = themeOf(s.theme);
        const names = ['--bg0', '--bg1', '--bg2', '--bg3', '--tx', '--tx2', '--tx3', '--ac'];
        names.forEach((n, i) => root.style.setProperty(n, t.c[i]));
        const accent = s.accent || t.c[7];
        root.style.setProperty('--ac', accent);
        root.style.setProperty('--on-ac', luminance(accent) > 0.55 ? '#1a140c' : '#fbf6ea');
        root.style.setProperty('--font-ui', fontOf(s.uiFont).stack);
        root.style.setProperty('--font-letter', fontOf(s.letterFont).stack);
        root.style.setProperty('--fs', (15 * s.textSize / 100).toFixed(2) + 'px');
        root.style.setProperty('--win-alpha', String(s.opacity / 100));
        root.style.setProperty('--dim', String(s.dim / 100));
        const eff = effective(s, branding);
        const body = document.body;
        body.classList.toggle('light', t.light);
        body.classList.toggle('compact', s.layout === 'compact');
        body.classList.toggle('dense', s.density === 'compact');
        body.classList.toggle('no-ornaments', !eff.ornaments);
        body.classList.toggle('no-texture', !eff.texture);
        body.classList.toggle('no-seal', !eff.seal);
        body.classList.toggle('no-watermark', !eff.watermark);
        body.dataset.motion = s.motion;
        body.dataset.paper = eff.paper;
        body.dataset.bubble = s.bubble;
        return eff;
    }

    return { THEMES, ACCENTS, FONTS, UI_FONTS, PAPERS, BUBBLES, DEFAULTS, validate, load, serialize, apply, effective, themeOf };
})();
