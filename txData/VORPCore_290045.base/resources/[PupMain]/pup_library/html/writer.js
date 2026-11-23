// pup_library | the writer: rich-text editing directly on a page.
// Built on contenteditable with its own undo history, drop-downs and address row.
(function () {
    'use strict';

    const SVG = (body, extra) =>
        `<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"${extra || ''}>${body}</svg>`;
    const letter = (ch, style) =>
        SVG(`<text x="12" y="17.5" text-anchor="middle" font-family="Georgia, serif" font-size="16" fill="currentColor" stroke="none" ${style || ''}>${ch}</text>`);

    const ICONS = {
        undo: SVG('<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H12"/>'),
        redo: SVG('<path d="m15 14 5-5-5-5"/><path d="M20 9H9.5a5.5 5.5 0 0 0 0 11H12"/>'),
        style: SVG('<path d="M10 4v16M15 4v16M18 4H9.5a4 4 0 0 0 0 8H15"/>'),
        font: SVG('<path d="m3 20 6-16 6 16M5.3 14h7.4"/><path d="M17 20v-7a2.5 2.5 0 0 1 4 0v7M17 16.5h4"/>'),
        size: SVG('<path d="M3 7V5h11v2M8.5 5v14M6.5 19h4M14 12v-1.5h7V12M17.5 10.5V19M16 19h3"/>'),
        bold: letter('B', 'font-weight="700"'),
        italic: letter('I', 'font-style="italic"'),
        underline: SVG('<text x="12" y="15.5" text-anchor="middle" font-family="Georgia, serif" font-size="15" fill="currentColor" stroke="none">U</text><path d="M6 20h12"/>'),
        strike: SVG('<text x="12" y="17.5" text-anchor="middle" font-family="Georgia, serif" font-size="16" fill="currentColor" stroke="none">S</text><path d="M5 12h14"/>'),
        ink: SVG('<path d="M12 3.5s6 6.8 6 10.8a6 6 0 0 1-12 0c0-4 6-10.8 6-10.8z"/>'),
        highlight: SVG('<path d="m14.5 4.5 5 5-8.5 8.5H6v-5z"/><path d="M4 21h16"/>'),
        alignLeft: SVG('<path d="M4 6h16M4 10h10M4 14h16M4 18h10"/>'),
        alignCenter: SVG('<path d="M4 6h16M7 10h10M4 14h16M7 18h10"/>'),
        alignRight: SVG('<path d="M4 6h16M10 10h10M4 14h16M10 18h10"/>'),
        alignJustify: SVG('<path d="M4 6h16M4 10h16M4 14h16M4 18h16"/>'),
        bullets: SVG('<path d="M9 6h11M9 12h11M9 18h11"/><circle cx="4.5" cy="6" r="1.2" fill="currentColor"/><circle cx="4.5" cy="12" r="1.2" fill="currentColor"/><circle cx="4.5" cy="18" r="1.2" fill="currentColor"/>'),
        numbers: SVG('<path d="M10 6h10M10 12h10M10 18h10"/><path d="M4 4.5 5.3 4v4" stroke-width="1.4"/><path d="M3.6 11c.3-.8 2.4-.8 2.4.3 0 .9-2.4 1.6-2.4 2.7H6" stroke-width="1.4"/><path d="M3.6 16.4H6l-1.2 1.4c1.4 0 1.5 2.4 0 2.4-.6 0-1-.2-1.2-.5" stroke-width="1.4"/>'),
        outdent: SVG('<path d="M4 5h16M11 10h9M11 14h9M4 19h16"/><path d="m8 9-3 3 3 3"/>'),
        indent: SVG('<path d="M4 5h16M11 10h9M11 14h9M4 19h16"/><path d="m5 9 3 3-3 3"/>'),
        quote: SVG('<path d="M5 11h4v6H5zM5 11c0-3 1.2-5 4-6M14 11h4v6h-4zM14 11c0-3 1.2-5 4-6"/>'),
        link: SVG('<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>'),
        picture: SVG('<rect x="3.5" y="5" width="17" height="14" rx="1.5"/><path d="m4 17 5-5 4 4 2-2 5 5"/><circle cx="15.5" cy="9.5" r="1.3"/>'),
        rule: SVG('<path d="M3 12h18"/><path d="M7 7.5h10M7 16.5h10" opacity=".45"/>'),
        clear: SVG('<path d="M5 5h11M10.5 5 8 19"/><path d="m14 14 6 6M20 14l-6 6"/>'),
        settings: SVG('<circle cx="12" cy="12" r="3.5"/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1"/>'),
        done: SVG('<path d="m5 12.5 4.5 4.5L19 7"/>', ' stroke-width="2.6"'),
        close: SVG('<path d="m7 7 10 10M17 7 7 17"/>', ' stroke-width="2.4"'),
    };

    let state = null; // the open writer, or null

    function el(tag, cls, text) {
        const e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text !== undefined) e.textContent = text;
        return e;
    }

    function exec(cmd, value) {
        return document.execCommand(cmd, false, value === undefined ? null : value);
    }

    // ---------------------------------------------------------------- selection

    function selectionInEditor() {
        const sel = window.getSelection();
        if (!sel || sel.rangeCount === 0) return null;
        const range = sel.getRangeAt(0);
        if (!state.editor.contains(range.commonAncestorContainer)) return null;
        return range;
    }

    function saveSelection() {
        const r = selectionInEditor();
        state.saved = r ? r.cloneRange() : null;
    }

    function restoreSelection() {
        state.editor.focus();
        const sel = window.getSelection();
        sel.removeAllRanges();
        if (state.saved) sel.addRange(state.saved);
        else caretToEnd();
    }

    function caretToEnd() {
        state.editor.focus();
        const range = document.createRange();
        range.selectNodeContents(state.editor);
        range.collapse(false);
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
    }

    function ancestor(tagSet) {
        const r = selectionInEditor();
        if (!r) return null;
        let node = r.startContainer;
        while (node && node !== state.editor) {
            if (node.nodeType === 1 && tagSet.has(node.localName)) return node;
            node = node.parentNode;
        }
        return null;
    }

    function unwrap(node) {
        const parent = node.parentNode;
        while (node.firstChild) parent.insertBefore(node.firstChild, node);
        parent.removeChild(node);
    }

    // ---------------------------------------------------------------- history

    const HISTORY_MAX = 120;

    function snapshot() {
        const html = state.editor.innerHTML;
        if (state.history[state.pos] === html) return;
        state.history = state.history.slice(0, state.pos + 1);
        state.history.push(html);
        if (state.history.length > HISTORY_MAX) state.history.shift();
        state.pos = state.history.length - 1;
        refreshButtons();
    }

    function scheduleSnapshot() {
        clearTimeout(state.snapTimer);
        state.snapTimer = setTimeout(() => { if (state) snapshot(); }, 450);
    }

    function stepHistory(dir) {
        clearTimeout(state.snapTimer);
        snapshot();
        const next = state.pos + dir;
        if (next < 0 || next >= state.history.length) return;
        state.pos = next;
        state.editor.innerHTML = state.history[next];
        caretToEnd();
        updateEmpty();
        refreshButtons();
    }

    // run an editing change as one undo step
    function change(fn) {
        clearTimeout(state.snapTimer);
        snapshot();
        fn();
        snapshot();
        updateEmpty();
        refreshButtons();
    }

    // ---------------------------------------------------------------- toolbar state

    function updateEmpty() {
        const e = state.editor;
        const empty = e.textContent.trim() === '' && !e.querySelector('img,hr,li,table');
        e.classList.toggle('empty', empty);
    }

    function refreshButtons() {
        if (!state) return;
        const b = state.buttons;
        b.undo.disabled = state.pos <= 0 && state.history[state.pos] === state.editor.innerHTML;
        b.redo.disabled = state.pos >= state.history.length - 1;
        const inEditor = !!selectionInEditor();
        const q = (cmd) => { try { return inEditor && document.queryCommandState(cmd); } catch (_) { return false; } };
        b.bold.classList.toggle('lit', q('bold'));
        b.italic.classList.toggle('lit', q('italic'));
        b.underline.classList.toggle('lit', q('underline'));
        b.strike.classList.toggle('lit', q('strikeThrough'));
        b.bullets.classList.toggle('lit', q('insertUnorderedList'));
        b.numbers.classList.toggle('lit', q('insertOrderedList'));
        b.quote.classList.toggle('lit', inEditor && !!ancestor(new Set(['blockquote'])));
        const inLink = inEditor && !!ancestor(new Set(['a']));
        b.link.classList.toggle('lit', inLink);
        b.link.title = inLink ? state.words.unlink : state.words.link;
    }

    // ---------------------------------------------------------------- popups

    function closePopup() {
        if (state.popup) {
            state.popup.remove();
            state.popup = null;
            state.popupFor = null;
        }
    }

    function openPopup(button, build) {
        if (state.popupFor === button) { closePopup(); return; }
        closePopup();
        saveSelection();
        const pop = el('div', 'w-popup');
        build(pop);
        state.root.appendChild(pop);
        // under the toolbar, lined up with the button, kept inside the page
        const rootBox = state.root.getBoundingClientRect();
        const btnBox = button.getBoundingClientRect();
        const scale = rootBox.width / state.root.offsetWidth || 1;
        const barBottom = (state.toolbar.getBoundingClientRect().bottom - rootBox.top) / scale;
        let left = (btnBox.left - rootBox.left) / scale;
        const maxLeft = state.root.offsetWidth - pop.offsetWidth - 6;
        left = Math.max(6, Math.min(left, maxLeft));
        pop.style.left = left + 'px';
        pop.style.top = (barBottom + 4) + 'px';
        state.popup = pop;
        state.popupFor = button;
    }

    function popupItem(pop, label, onPick, styleFn) {
        const item = el('button', 'w-popup-item', label);
        item.type = 'button';
        if (styleFn) styleFn(item);
        item.addEventListener('mousedown', (e) => e.preventDefault());
        item.addEventListener('click', () => {
            closePopup();
            restoreSelection();
            onPick();
        });
        pop.appendChild(item);
    }

    function swatchGrid(pop, colours, onPick, noneLabel) {
        const grid = el('div', 'w-swatches');
        for (const c of colours) {
            const sw = el('button', 'w-swatch');
            sw.type = 'button';
            sw.style.background = c;
            sw.title = c;
            sw.addEventListener('mousedown', (e) => e.preventDefault());
            sw.addEventListener('click', () => { closePopup(); restoreSelection(); onPick(c); });
            grid.appendChild(sw);
        }
        pop.appendChild(grid);
        if (noneLabel) popupItem(pop, noneLabel, () => onPick(null));
    }

    // ---------------------------------------------------------------- commands

    function applyBlock(tag) {
        change(() => exec('formatBlock', '<' + tag + '>'));
    }

    function applyFont(stack) {
        change(() => {
            exec('styleWithCSS', false);
            exec('fontName', stack);
            exec('styleWithCSS', true);
        });
    }

    function applySize(px) {
        change(() => {
            exec('styleWithCSS', false);
            exec('fontSize', '7');
            exec('styleWithCSS', true);
            for (const f of state.editor.querySelectorAll('font[size="7"]')) {
                f.removeAttribute('size');
                for (const inner of f.querySelectorAll('[style]')) inner.style.fontSize = '';
                f.style.fontSize = px + 'px';
            }
        });
    }

    function applyInk(colour) {
        change(() => { exec('styleWithCSS', true); exec('foreColor', colour); });
    }

    function applyHighlight(colour) {
        change(() => { exec('styleWithCSS', true); exec('hiliteColor', colour || 'transparent'); });
    }

    function toggleQuote() {
        const bq = ancestor(new Set(['blockquote']));
        change(() => {
            if (bq) unwrap(bq);
            else exec('formatBlock', '<blockquote>');
        });
    }

    function insertRule() {
        change(() => exec('insertHTML', '<hr><p><br></p>'));
    }

    function clearFormatting() {
        change(() => exec('removeFormat'));
    }

    // ---------------------------------------------------------------- address row

    function normaliseAddress(raw) {
        let v = (raw || '').trim();
        if (v === '') return null;
        if (!/^[a-z][a-z0-9+.-]*:/i.test(v)) v = 'https://' + v;
        return PupClean.url(v);
    }

    function openAddress(mode) {
        closePopup();
        closeAddress();
        saveSelection();
        const row = el('div', 'w-address');
        const input = el('input', 'w-address-input');
        input.type = 'text';
        input.placeholder = mode === 'link' ? state.words.linkPrompt : state.words.picturePrompt;
        const ok = el('button', 'w-btn-text', state.words.ok);
        ok.type = 'button';
        const cancel = el('button', 'w-btn-text', state.words.cancel);
        cancel.type = 'button';
        row.append(input, ok, cancel);
        state.root.appendChild(row);
        row.style.top = (state.toolbar.offsetHeight + 4) + 'px';
        state.address = row;

        const submit = () => {
            const address = normaliseAddress(input.value);
            if (!address) {
                input.value = '';
                input.placeholder = state.words.badAddress;
                input.focus();
                return;
            }
            closeAddress();
            restoreSelection();
            if (mode === 'link') insertLink(address);
            else change(() => exec('insertImage', address));
        };
        const abort = () => { closeAddress(); restoreSelection(); };
        ok.addEventListener('click', submit);
        cancel.addEventListener('click', abort);
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') { e.preventDefault(); submit(); }
            else if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); abort(); }
        });
        setTimeout(() => input.focus(), 0);
    }

    function closeAddress() {
        if (state.address) {
            state.address.remove();
            state.address = null;
        }
    }

    function insertLink(address) {
        const r = selectionInEditor();
        change(() => {
            if (r && !r.collapsed) {
                exec('createLink', address);
            } else {
                const a = document.createElement('a');
                a.href = address;
                a.textContent = address;
                exec('insertHTML', a.outerHTML);
            }
        });
    }

    function linkButton() {
        const a = ancestor(new Set(['a']));
        if (a) change(() => unwrap(a));
        else openAddress('link');
    }

    // ---------------------------------------------------------------- page settings

    function applyLook() {
        const p = state.page;
        const sheet = state.sheet;
        sheet.classList.toggle('plain', !!p.backgroundColor && !p.background);
        sheet.classList.toggle('pictured', !!p.background);
        sheet.style.backgroundImage = p.background ? `url("${p.background}")` : '';
        sheet.style.backgroundColor = p.backgroundColor || '';
        state.editor.style.color = p.color || '';
    }

    function openSettings() {
        closePopup();
        closeAddress();
        if (state.settings) { state.settings.remove(); state.settings = null; return; }
        saveSelection();
        const card = el('div', 'w-settings');
        const x = el('button', 'w-settings-close');
        x.type = 'button';
        x.innerHTML = ICONS.close;
        x.title = state.words.close || '';
        x.addEventListener('click', () => { card.remove(); state.settings = null; restoreSelection(); });
        card.appendChild(x);

        const field = (label, key, rule) => {
            const wrap = el('label', 'w-field');
            wrap.appendChild(el('span', 'w-field-label', label));
            const input = el('input', 'w-field-input');
            input.type = 'text';
            input.value = state.page[key] || '';
            input.addEventListener('change', () => {
                const ok = rule(input.value.trim());
                if (ok) state.page[key] = ok;
                else { delete state.page[key]; input.value = ''; }
                applyLook();
            });
            wrap.appendChild(input);
            card.appendChild(wrap);
        };
        field(state.words.bgLabel, 'background', PupClean.background);
        field(state.words.pageColour, 'backgroundColor', PupClean.colour);
        field(state.words.textColour, 'color', PupClean.colour);
        state.root.appendChild(card);
        state.settings = card;
    }

    // ---------------------------------------------------------------- paste

    const PICTURE_TYPES = new Set(['image/png', 'image/jpeg', 'image/gif', 'image/webp']);

    function onPaste(e) {
        e.preventDefault();
        const cd = e.clipboardData;
        if (!cd) return;
        for (const file of Array.from(cd.files || [])) {
            if (PICTURE_TYPES.has(file.type)) {
                const reader = new FileReader();
                reader.onload = () => {
                    if (!state) return;
                    const address = PupClean.url(String(reader.result || ''));
                    if (address) { restoreSelection(); change(() => exec('insertImage', address)); }
                };
                saveSelection();
                reader.readAsDataURL(file);
                return;
            }
        }
        const html = cd.getData('text/html');
        if (html) { change(() => exec('insertHTML', PupClean.html(html))); return; }
        const text = cd.getData('text/plain');
        if (text) change(() => exec('insertText', text));
    }

    // ---------------------------------------------------------------- building

    function button(name, title, onClick, extraClass) {
        const b = el('button', 'w-tool' + (extraClass ? ' ' + extraClass : ''));
        b.type = 'button';
        b.title = title;
        b.innerHTML = ICONS[name];
        b.addEventListener('mousedown', (e) => e.preventDefault()); // keep the text selection
        b.addEventListener('click', (e) => { e.preventDefault(); onClick(b); });
        state.buttons[name] = b;
        return b;
    }

    function sep() { return el('span', 'w-sep'); }

    function buildToolbar() {
        const w = state.words;
        const c = state.choices;
        const bar = el('div', 'w-toolbar');
        const left = el('div', 'w-tools');
        left.append(
            button('undo', w.undo, () => stepHistory(-1)),
            button('redo', w.redo, () => stepHistory(1)),
            sep(),
            button('style', w.style, (b) => openPopup(b, (pop) => {
                popupItem(pop, w.styleP, () => applyBlock('p'), (i) => i.classList.add('as-p'));
                popupItem(pop, w.styleH1, () => applyBlock('h1'), (i) => i.classList.add('as-h1'));
                popupItem(pop, w.styleH2, () => applyBlock('h2'), (i) => i.classList.add('as-h2'));
                popupItem(pop, w.styleH3, () => applyBlock('h3'), (i) => i.classList.add('as-h3'));
            })),
            button('font', w.font, (b) => openPopup(b, (pop) => {
                for (const f of c.fonts || []) popupItem(pop, f.label, () => applyFont(f.stack), (i) => { i.style.fontFamily = f.stack; });
            })),
            button('size', w.size, (b) => openPopup(b, (pop) => {
                pop.classList.add('w-popup-sizes');
                for (const s of c.sizes || []) popupItem(pop, s + ' px', () => applySize(s));
            })),
            sep(),
            button('bold', w.bold, () => change(() => exec('bold'))),
            button('italic', w.italic, () => change(() => exec('italic'))),
            button('underline', w.underline, () => change(() => exec('underline'))),
            button('strike', w.strike, () => change(() => exec('strikeThrough'))),
            sep(),
            button('ink', w.ink, (b) => openPopup(b, (pop) => swatchGrid(pop, c.ink || [], applyInk))),
            button('highlight', w.highlight, (b) => openPopup(b, (pop) => swatchGrid(pop, c.highlight || [], applyHighlight, w.none))),
            sep(),
            button('alignLeft', w.alignLeft, () => change(() => exec('justifyLeft'))),
            button('alignCenter', w.alignCenter, () => change(() => exec('justifyCenter'))),
            button('alignRight', w.alignRight, () => change(() => exec('justifyRight'))),
            button('alignJustify', w.alignJustify, () => change(() => exec('justifyFull'))),
            sep(),
            button('bullets', w.bullets, () => change(() => exec('insertUnorderedList'))),
            button('numbers', w.numbers, () => change(() => exec('insertOrderedList'))),
            button('outdent', w.outdent, () => change(() => exec('outdent'))),
            button('indent', w.indent, () => change(() => exec('indent'))),
            button('quote', w.quote, toggleQuote),
            sep(),
            button('link', w.link, linkButton),
            button('picture', w.picture, () => openAddress('picture')),
            button('rule', w.rule, insertRule),
            button('clear', w.clear, clearFormatting),
        );
        const right = el('div', 'w-tools w-tools-end');
        right.append(
            button('settings', w.settings, openSettings),
            button('done', w.done, () => finish(), 'w-done'),
        );
        bar.append(left, right);
        return bar;
    }

    // Opens the writer over `host`. page: { content, background, backgroundColor, color }.
    function open(opts) {
        if (state) finish();
        const root = el('div', 'writer');
        state = {
            root,
            page: Object.assign({}, opts.page),
            words: opts.words,
            choices: opts.choices || {},
            onDone: opts.onDone,
            buttons: {},
            history: [],
            pos: -1,
            popup: null,
            popupFor: null,
            address: null,
            settings: null,
            saved: null,
            snapTimer: null,
        };
        const toolbar = buildToolbar();
        state.toolbar = toolbar;

        const sheet = el('div', 'w-sheet paper');
        const editor = el('div', 'w-editor page-text');
        editor.contentEditable = 'true';
        editor.spellcheck = false;
        editor.dataset.placeholder = state.words.placeholder;
        editor.innerHTML = PupClean.html(state.page.content || '');
        sheet.appendChild(editor);
        root.append(toolbar, sheet);
        opts.host.appendChild(root);
        state.sheet = sheet;
        state.editor = editor;

        applyLook();
        exec('styleWithCSS', true);
        exec('defaultParagraphSeparator', 'p');

        editor.addEventListener('input', () => { updateEmpty(); scheduleSnapshot(); refreshButtons(); });
        editor.addEventListener('paste', onPaste);
        editor.addEventListener('drop', (e) => e.preventDefault());
        editor.addEventListener('click', (e) => {
            if (e.target.closest && e.target.closest('a')) e.preventDefault();
        });
        editor.addEventListener('keydown', (e) => {
            const k = e.key.toLowerCase();
            if ((e.ctrlKey || e.metaKey) && k === 'z') { e.preventDefault(); stepHistory(e.shiftKey ? 1 : -1); }
            else if ((e.ctrlKey || e.metaKey) && k === 'y') { e.preventDefault(); stepHistory(1); }
            else if ((e.ctrlKey || e.metaKey) && (k === 'b' || k === 'i' || k === 'u')) {
                e.preventDefault();
                change(() => exec(k === 'b' ? 'bold' : k === 'i' ? 'italic' : 'underline'));
            }
        });
        // clicking empty page space puts the cursor at the end of the text
        sheet.addEventListener('mousedown', (e) => {
            if (e.target === sheet) { e.preventDefault(); caretToEnd(); return; }
            if (e.target === editor) {
                const last = editor.lastElementChild || editor.lastChild;
                const bottom = last && last.getBoundingClientRect ? last.getBoundingClientRect().bottom : 0;
                if (!last || e.clientY > bottom) { e.preventDefault(); caretToEnd(); }
            }
        });
        state.onDocMouse = (e) => {
            if (state && state.popup && !state.popup.contains(e.target) && !(state.popupFor && state.popupFor.contains(e.target))) closePopup();
        };
        document.addEventListener('mousedown', state.onDocMouse, true);
        state.onSelChange = () => refreshButtons();
        document.addEventListener('selectionchange', state.onSelChange);

        state.history = [editor.innerHTML];
        state.pos = 0;
        updateEmpty();
        caretToEnd();
        refreshButtons();
    }

    function teardown() {
        if (!state) return;
        clearTimeout(state.snapTimer);
        document.removeEventListener('mousedown', state.onDocMouse, true);
        document.removeEventListener('selectionchange', state.onSelChange);
        state.root.remove();
        state = null;
    }

    // Keeps the page (cleaned) and closes. Returns the page.
    function finish() {
        if (!state) return null;
        const page = state.page;
        const editor = state.editor;
        const empty = editor.textContent.trim() === '' && !editor.querySelector('img,hr,li,table');
        page.content = empty ? '' : PupClean.html(editor.innerHTML);
        const onDone = state.onDone;
        teardown();
        if (onDone) onDone(page);
        return page;
    }

    // Closes without keeping anything (the book is closing without saving).
    function discard() { teardown(); }

    window.PupWriter = {
        open,
        finish,
        discard,
        isOpen: () => state !== null,
        busy: () => !!(state && (state.popup || state.address || state.settings)),
        closeOverlays: () => {
            if (!state) return;
            closePopup();
            if (state.address) { closeAddress(); restoreSelection(); }
            if (state.settings) { state.settings.remove(); state.settings = null; }
        },
    };
})();
