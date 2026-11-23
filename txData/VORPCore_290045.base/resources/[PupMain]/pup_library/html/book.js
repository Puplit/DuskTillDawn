// pup_library | the two-page book: layout, page turning, page tools, closing and saving.
(function () {
    'use strict';

    const PARENT = typeof window.GetParentResourceName === 'function' ? window.GetParentResourceName() : null;
    const PARAMS = new URLSearchParams(window.location.search);
    const PREVIEW = !PARENT && PARAMS.has('debug');

    const BASE_W = 1383;
    const BASE_H = 900;
    const MARGIN = 20;

    // English wording for the browser preview; in game the words come from locale/en.lua
    const DEFAULT_WORDS = {
        placeholder: 'Start your writings', keepEditing: 'Keep editing', closeNoSave: 'Close without saving',
        tooMany: 'This book has too many pages to save.', tooLarge: 'This book is too large to save. Remove some pictures or pages.',
        close: 'Close', closeSave: 'Save and close', turnHint: 'Turn the page',
        toolEdit: 'Write on this page', toolAdd: 'Add a page after this one', toolForward: 'Move this page forward',
        toolBack: 'Move this page back', toolDelete: 'Delete this page',
        undo: 'Undo', redo: 'Redo', style: 'Style', styleP: 'Paragraph', styleH1: 'Large heading', styleH2: 'Medium heading',
        styleH3: 'Small heading', font: 'Font', size: 'Size', bold: 'Bold', italic: 'Italic', underline: 'Underline',
        strike: 'Crossed out', ink: 'Ink colour', highlight: 'Highlight', none: 'None', alignLeft: 'Align left',
        alignCenter: 'Centre', alignRight: 'Align right', alignJustify: 'Justify', bullets: 'Bulleted list',
        numbers: 'Numbered list', outdent: 'Less indent', indent: 'More indent', quote: 'Quote', link: 'Link',
        unlink: 'Remove link', picture: 'Picture', rule: 'Dividing line', clear: 'Clear formatting',
        settings: 'Page settings', done: 'Done', ok: 'OK', cancel: 'Cancel', linkPrompt: 'Link address',
        picturePrompt: 'Picture address', badAddress: 'That address cannot be used.',
        bgLabel: 'Background picture (address)', pageColour: 'Page colour', textColour: 'Text colour',
    };
    const DEFAULT_CHOICES = {
        fonts: [
            { label: 'Georgia', stack: 'Georgia, serif' },
            { label: 'Times New Roman', stack: 'Times New Roman, serif' },
            { label: 'Palatino', stack: 'Palatino Linotype, Palatino, serif' },
            { label: 'Book Antiqua', stack: 'Book Antiqua, serif' },
            { label: 'Courier New', stack: 'Courier New, monospace' },
            { label: 'Lucida Handwriting', stack: 'Lucida Handwriting, cursive' },
            { label: 'Segoe Script', stack: 'Segoe Script, cursive' },
            { label: 'Arial', stack: 'Arial, sans-serif' },
        ],
        sizes: [12, 14, 16, 18, 20, 24, 28, 36, 48, 72],
        ink: ['#2b1d0e', '#5b3a1e', '#8a1c1c', '#a8551a', '#24452b', '#1d3557', '#4a2c5a', '#6b6256', '#000000', '#ffffff'],
        highlight: ['#e8c37a', '#e3a96b', '#d98f8f', '#a9c48f', '#9db8cf', '#c2a8d1', '#ffffff'],
    };

    const TOOL_ICONS = {
        edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m13 7 4 4"/>',
        add: '<path d="M12 5v14M5 12h14"/>',
        forward: '<rect x="3.5" y="6" width="8" height="12" rx="1"/><path d="M14 12h6.5M17.5 9l3 3-3 3"/>',
        back: '<rect x="12.5" y="6" width="8" height="12" rx="1"/><path d="M10 12H3.5M6.5 9l-3 3 3 3"/>',
        delete: '<circle cx="12" cy="12" r="8.5"/><path d="m6 6 12 12"/>',
    };
    const svg = (body, sw) =>
        `<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="${sw || 2}" stroke-linecap="round" stroke-linejoin="round">${body}</svg>`;

    // ---------------------------------------------------------------- DOM

    const $ = (id) => document.getElementById(id);
    const app = $('app');
    const stage = $('stage');
    const bookEl = $('book');
    const halfL = $('half-left');
    const halfR = $('half-right');
    const leaf = $('leaf');
    const leafFront = $('leaf-front');
    const leafBack = $('leaf-back');
    const shadeFront = $('shade-front');
    const shadeBack = $('shade-back');
    const zoneL = $('zone-left');
    const zoneR = $('zone-right');
    const closeBtn = $('close-btn');
    const hint = $('hint');
    const warn = $('warn');
    const warnText = $('warn-text');
    const warnKeep = $('warn-keep');
    const warnDiscard = $('warn-discard');

    closeBtn.innerHTML = svg('<path d="M14 4h6v6"/><path d="m20 4-9 9"/><path d="M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/>');
    hint.innerHTML = svg('<path d="M4 17c3-7 13-9 16-2"/><path d="m20 9.5.2 5.7-5.5-1.3"/><path d="M4 20h7" opacity=".6"/>', 1.8);

    function el(tag, cls, text) {
        const e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text !== undefined) e.textContent = text;
        return e;
    }

    // ---------------------------------------------------------------- state

    let S = null;      // the open book
    let failing = false;

    function post(name, body) {
        if (!PARENT) {
            console.log('[pup_library preview]', name, body || {});
            return;
        }
        fetch(`https://${PARENT}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).catch(() => { /* the game side may already be gone */ });
    }

    function normalisePage(p) {
        const out = { content: typeof p.content === 'string' ? PupClean.html(p.content) : '' };
        const bg = PupClean.background(p.background);
        if (bg) out.background = bg;
        const pc = PupClean.colour(p.backgroundColor);
        if (pc) out.backgroundColor = pc;
        const tc = PupClean.colour(p.color);
        if (tc) out.color = tc;
        return out;
    }

    function loadBook(raw, newPages) {
        let parsed = null;
        try { parsed = JSON.parse(raw); } catch (_) { parsed = null; }
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) parsed = {};
        const list = Array.isArray(parsed.pages) ? parsed.pages : [];
        const pages = list.filter((p) => p && typeof p === 'object').map(normalisePage);
        if (pages.length === 0) for (let i = 0; i < newPages; i++) pages.push({ content: '' });
        const extra = {};
        for (const key of ['frontImage', 'midImage', 'backImage']) {
            if (typeof parsed[key] === 'string') extra[key] = parsed[key];
        }
        return { pages, extra };
    }

    function serialise() {
        return JSON.stringify(Object.assign({}, S.extra, { pages: S.pages }));
    }

    function byteLength(text) {
        return new TextEncoder().encode(text).length;
    }

    // ---------------------------------------------------------------- spreads
    // Page 1 sits alone on the right; then 2|3, 4|5 ... (indexes are 0-based here)

    const leftIdx = (s) => (s === 0 ? null : 2 * s - 1);
    const rightIdx = (s) => (s === 0 ? 0 : 2 * s);
    const spreadOf = (i) => (i <= 0 ? 0 : Math.floor((i + 1) / 2));
    const spreadCount = () => 1 + Math.ceil(Math.max(0, S.pages.length - 1) / 2);

    // ---------------------------------------------------------------- pages

    function buildTools(idx) {
        const w = S.words;
        const tools = el('div', 'page-tools');
        const add = (name, title, disabled, action) => {
            const b = el('button', 'tool');
            b.type = 'button';
            b.title = title;
            b.innerHTML = svg(TOOL_ICONS[name]);
            b.disabled = !!disabled;
            b.addEventListener('click', (e) => {
                e.stopPropagation();
                if (!S || S.turning || PupWriter.isOpen()) return;
                action();
            });
            tools.appendChild(b);
        };
        const last = S.pages.length - 1;
        add('edit', w.toolEdit, false, () => openWriter(idx));
        add('add', w.toolAdd, false, () => addPage(idx));
        add('back', w.toolBack, idx === 0, () => movePage(idx, -1));
        add('forward', w.toolForward, idx === last, () => movePage(idx, 1));
        add('delete', w.toolDelete, last === 0, () => deletePage(idx));
        return tools;
    }

    function buildPage(idx, side, interactive) {
        const page = el('div', 'page ' + side);
        if (idx === null || idx < 0 || idx >= S.pages.length) {
            page.classList.add('endpaper');
            return page;
        }
        const p = S.pages[idx];
        page.classList.add('paper');
        if (p.background) {
            page.classList.add('pictured');
            page.style.backgroundImage = `url("${p.background}")`;
        } else if (p.backgroundColor) {
            page.classList.add('plain');
        }
        if (p.backgroundColor) page.style.backgroundColor = p.backgroundColor;

        const text = el('div', 'page-text');
        if (p.color) text.style.color = p.color;
        text.innerHTML = PupClean.html(p.content || '');
        page.appendChild(text);
        page.appendChild(el('div', 'page-num', String(idx + 1)));
        if (interactive && S.editable) page.appendChild(buildTools(idx));
        return page;
    }

    function render() {
        if (!S) return;
        const s = S.spread;
        halfL.replaceChildren(buildPage(leftIdx(s), 'left', true));
        halfR.replaceChildren(buildPage(rightIdx(s) < S.pages.length ? rightIdx(s) : null, 'right', true));
        zoneL.classList.toggle('hidden', s <= 0);
        zoneR.classList.toggle('hidden', s >= spreadCount() - 1);
    }

    function goTo(idx) {
        S.spread = Math.max(0, Math.min(spreadOf(idx), spreadCount() - 1));
        render();
    }

    // ---------------------------------------------------------------- page tools

    function addPage(idx) {
        const src = S.pages[idx] || {};
        const fresh = { content: '' };
        if (src.background) fresh.background = src.background;
        if (src.backgroundColor) fresh.backgroundColor = src.backgroundColor;
        if (src.color) fresh.color = src.color;
        S.pages.splice(idx + 1, 0, fresh);
        goTo(idx + 1);
    }

    function movePage(idx, dir) {
        const other = idx + dir;
        if (other < 0 || other >= S.pages.length) return;
        const tmp = S.pages[idx];
        S.pages[idx] = S.pages[other];
        S.pages[other] = tmp;
        goTo(other);
    }

    function deletePage(idx) {
        if (S.pages.length <= 1) return;
        S.pages.splice(idx, 1);
        goTo(Math.min(idx, S.pages.length - 1));
    }

    function openWriter(idx) {
        goTo(idx);
        const host = leftIdx(S.spread) === idx ? halfL : halfR;
        bookEl.classList.add('writing');
        PupWriter.open({
            host,
            page: S.pages[idx],
            words: S.words,
            choices: S.choices,
            onDone: (page) => {
                bookEl.classList.remove('writing');
                if (!S) return;
                S.pages[idx] = page;
                goTo(idx);
            },
        });
    }

    // ---------------------------------------------------------------- turning

    const ease = (t) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2);

    function turn(dir) {
        if (!S || S.turning || PupWriter.isOpen() || !warn.classList.contains('hidden')) return;
        const from = S.spread;
        const to = from + dir;
        if (to < 0 || to >= spreadCount()) return;
        S.turning = true;
        hint.classList.add('hidden');
        bookEl.classList.add('turning');

        const forward = dir > 0;
        const pageIdx = (i) => (i !== null && i < S.pages.length ? i : null);
        leaf.className = forward ? 'from-right' : 'from-left';
        leafFront.replaceChildren(buildPage(pageIdx(forward ? rightIdx(from) : leftIdx(from)), forward ? 'right' : 'left', false));
        leafBack.replaceChildren(buildPage(pageIdx(forward ? leftIdx(to) : rightIdx(to)), forward ? 'left' : 'right', false));
        // what lies underneath the turning leaf
        if (forward) halfR.replaceChildren(buildPage(pageIdx(rightIdx(to)), 'right', false));
        else halfL.replaceChildren(buildPage(pageIdx(leftIdx(to)), 'left', false));

        const started = performance.now();
        const step = (now) => {
            if (!S) return;
            const t = Math.min(1, (now - started) / S.turnMs);
            const angle = ease(t) * 180;
            leaf.style.transform = `rotateY(${forward ? -angle : angle}deg)`;
            // each side darkens as it stands upright
            const shade = Math.sin(angle * Math.PI / 180) * 0.5;
            shadeFront.style.opacity = String(shade);
            shadeBack.style.opacity = String(shade);
            if (t < 1) {
                S.raf = requestAnimationFrame(step);
                return;
            }
            leaf.className = 'hidden';
            leaf.style.transform = '';
            leafFront.replaceChildren();
            leafBack.replaceChildren();
            S.spread = to;
            S.turning = false;
            bookEl.classList.remove('turning');
            render();
        };
        S.raf = requestAnimationFrame(step);
    }

    zoneL.addEventListener('click', () => turn(-1));
    zoneR.addEventListener('click', () => turn(1));

    // links on a page are shown but never followed
    bookEl.addEventListener('click', (e) => {
        const a = e.target.closest && e.target.closest('a');
        if (a) e.preventDefault();
    });

    // ---------------------------------------------------------------- closing

    function showWarn(message) {
        warnText.textContent = message;
        warn.classList.remove('hidden');
    }

    function hideWarn() {
        warn.classList.add('hidden');
    }

    // Hide everything and forget the book. Never saves.
    function hideAll() {
        if (S) {
            if (S.raf) cancelAnimationFrame(S.raf);
            clearTimeout(S.deleteTimer);
        }
        PupWriter.discard();
        S = null;
        hideWarn();
        app.classList.add('hidden');
        bookEl.classList.remove('writing', 'turning');
        leaf.className = 'hidden';
        halfL.replaceChildren();
        halfR.replaceChildren();
    }

    function requestClose() {
        if (!S) return;
        if (!S.editable) {
            hideAll();
            post('close');
            return;
        }
        if (PupWriter.isOpen()) PupWriter.finish();
        if (!S) return;
        if (S.pages.length > S.maxPages) { showWarn(S.words.tooMany); return; }
        const json = serialise();
        if (byteLength(json) > S.maxBytes) { showWarn(S.words.tooLarge); return; }
        hideAll();
        post('save', { book: json });
    }

    closeBtn.addEventListener('click', requestClose);
    warnKeep.addEventListener('click', hideWarn);
    warnDiscard.addEventListener('click', () => { hideAll(); post('close'); });

    // ---------------------------------------------------------------- keys

    function cancelDeleteHold() {
        if (S && S.deleteTimer) { clearTimeout(S.deleteTimer); S.deleteTimer = null; }
    }

    document.addEventListener('keydown', (e) => {
        if (!S) return;
        if (e.key === 'Delete' && !e.repeat && !S.deleteTimer) {
            S.deleteTimer = setTimeout(() => { hideAll(); post('unstuck'); }, S.holdMs);
        }
        if (!warn.classList.contains('hidden')) {
            if (e.key === 'Escape') hideWarn();
            return;
        }
        if (PupWriter.isOpen()) {
            if (e.key === 'Escape') PupWriter.closeOverlays();
            return;
        }
        switch (e.key) {
            case 'ArrowRight': case 'PageDown': e.preventDefault(); turn(1); break;
            case 'ArrowLeft': case 'PageUp': e.preventDefault(); turn(-1); break;
            case 'Escape': e.preventDefault(); requestClose(); break;
            default: break;
        }
    });
    document.addEventListener('keyup', (e) => { if (e.key === 'Delete') cancelDeleteHold(); });
    window.addEventListener('blur', cancelDeleteHold);

    // ---------------------------------------------------------------- scale

    function fit() {
        // the extra height keeps the page-turn hint under the book on screen
        const s = Math.min(1, (window.innerWidth - MARGIN * 2) / BASE_W, (window.innerHeight - MARGIN * 2) / (BASE_H + 80));
        stage.style.transform = `translate(-50%, -50%) scale(${Math.max(0.1, s)})`;
    }
    window.addEventListener('resize', fit);

    // ---------------------------------------------------------------- start

    function start(msg) {
        hideAll();
        failing = false;
        const words = Object.assign({}, DEFAULT_WORDS, (msg.words && typeof msg.words === 'object') ? msg.words : {});
        const loaded = loadBook(typeof msg.data === 'string' ? msg.data : '', Number(msg.newPages) || 3);
        S = {
            pages: loaded.pages,
            extra: loaded.extra,
            editable: msg.editable === true,
            maxBytes: Number(msg.maxBytes) || 524288,
            maxPages: Number(msg.maxPages) || 200,
            turnMs: Number(msg.turnMs) || 650,
            holdMs: Number(msg.holdMs) || 1000,
            words,
            choices: (msg.writer && typeof msg.writer === 'object') ? msg.writer : DEFAULT_CHOICES,
            spread: 0,
            turning: false,
            raf: null,
            deleteTimer: null,
        };
        closeBtn.title = S.editable ? words.closeSave : words.close;
        hint.title = words.turnHint;
        warnKeep.textContent = words.keepEditing;
        warnDiscard.textContent = words.closeNoSave;
        bookEl.classList.toggle('editable', S.editable);
        hint.classList.remove('hidden');
        app.classList.remove('hidden');
        fit();
        render();
    }

    // the game may send only these two messages
    window.addEventListener('message', (e) => {
        const m = e.data;
        if (!m || typeof m !== 'object') return;
        if (m.action === 'startBook') start(m);
        else if (m.action === 'stopBook') hideAll();
    });

    // ---------------------------------------------------------------- failure safety

    const OWN_SCRIPT = /\/(book|writer|clean)\.js(\?|$)/;

    function fail() {
        if (!S || failing) return;
        failing = true;
        hideAll();
        post('failed');
    }

    window.addEventListener('error', (e) => {
        const file = (e && e.filename) || '';
        if (file && !OWN_SCRIPT.test(file)) return; // not ours
        fail();
    });
    window.addEventListener('unhandledrejection', () => fail());

    // ---------------------------------------------------------------- browser preview

    if (PREVIEW) {
        document.body.classList.add('preview');
        const sample = {
            pages: [
                { content: '<h1>The Prairie Ledger</h1><p style="text-align:center"><em>A sample book for the preview</em></p><hr><p>Turn the page with the arrow keys, Page Up and Page Down, or the corners of the book.</p>' },
                { content: '<h2>Chapter One</h2><p>The wind came down off the ridge and found every gap in the boards.</p><blockquote>Nobody rides into Valentine without a reason.</blockquote><p>He tied his horse and went in.</p>' },
                { content: '<h3>Accounts</h3><ul><li>Flour, two sacks</li><li>Coffee</li><li>Cartridges, one box</li></ul><ol><li>Pay the smith</li><li>Write home</li></ol>' },
                { content: '<p><span style="background-color:#e8c37a">Highlighted words</span> and <a href="https://example.com">a link that cannot be followed</a>.</p><table><tr><th>Item</th><th>Price</th></tr><tr><td>Book</td><td>$3</td></tr></table>', backgroundColor: '#e9dcc0' },
                { content: '<p style="text-align:right"><font face="Segoe Script, cursive" style="font-size:28px">The End</font></p>', color: '#5b3a1e' },
            ],
        };
        start({
            action: 'startBook',
            data: JSON.stringify(sample),
            editable: PARAMS.has('edit'),
            maxBytes: 524288,
            maxPages: 200,
            newPages: 3,
            turnMs: 650,
            holdMs: 1000,
        });
    }
})();
