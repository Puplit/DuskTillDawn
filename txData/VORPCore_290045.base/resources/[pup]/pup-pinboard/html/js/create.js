// pup-pinboard | the two forms: writing a notice, and pinning a picture

import { el, L, button, iconButton, segmented, shake, toast, openLayer } from './shared.js';
import { PAPER_IDS, DEFAULT_PAPER, SECTIONS, paperSheet, paperUrl, placeText } from './notices.js';

// ---------- step one: which section, and what kind of notice ----------
// opts: { section (preselected, or null), canText, canPicture, onPick(section, kind) }

export function openPinChooser(opts) {
    const box = el('div', 'chooser');
    box.appendChild(el('h2', 'chooser__title', L('choose_section')));

    let picked = SECTIONS.includes(opts.section) ? opts.section : null;
    const grid = el('div', 'chooser__grid');
    const tiles = SECTIONS.map((id) => {
        const tile = el('button', `chooser__tile sec-${id}` + (id === picked ? ' is-on' : ''));
        tile.type = 'button';
        tile.appendChild(el('span', 'chooser__name', L('section_' + id)));
        tile.appendChild(el('span', 'chooser__hint', L('section_' + id + '_hint')));
        tile.addEventListener('click', () => {
            picked = id;
            tiles.forEach((t) => t.classList.toggle('is-on', t === tile));
            kinds.classList.remove('is-waiting');
        });
        grid.appendChild(tile);
        return tile;
    });
    box.appendChild(grid);

    box.appendChild(el('h2', 'chooser__title', L('choose_kind')));
    const kinds = el('div', 'bar chooser__kinds' + (picked ? '' : ' is-waiting'));
    let layer;
    const go = (kind) => {
        if (!picked) { shake(grid); return; }
        layer.close();
        opts.onPick(picked, kind);
    };
    const text = button('btn--gold', L('kind_text'), () => go('text'));
    const picture = button('btn--gold', L('kind_image'), () => go('picture'));
    text.disabled = !opts.canText;
    picture.disabled = !opts.canPicture;
    kinds.append(text, picture, button('', L('cancel'), () => layer.close()));
    box.appendChild(kinds);

    layer = openLayer(box);
    return layer;
}

// the coloured "Pinning under: For Sale" line at the top of both forms
function sectionLine(section) {
    const line = el('div', 'pinning');
    line.appendChild(el('span', `card__section sec-${section}`, L('pinning_under', L('section_' + section))));
    return line;
}

const MAX_LINES = 10;
const MAX_HEADING = 120;
const MAX_BODY = 1200;
const MAX_URL = 1024; // server/main.lua refuses longer links

// "This board only / Every board", for those allowed to pin to every board
function scopeChoice() {
    const row = el('div', 'scope');
    row.appendChild(el('span', null, L('scope_question')));
    const seg = segmented([
        ['here', L('scope_here')],
        ['all', L('scope_all')],
    ], 'here', null, true);
    row.appendChild(seg.el);
    return { el: row, allBoards: () => seg.get() === 'all' };
}

// ---------- a written notice ----------
// opts: { allBoardsAllowed, onSave(content) -> Promise<boolean> }

export function openWriteForm(opts) {
    const box = el('div', 'compose');
    let paperIndex = Math.max(0, PAPER_IDS.indexOf(DEFAULT_PAPER));
    const { sheet, bg, text } = paperSheet(PAPER_IDS[paperIndex]);
    text.classList.add('paper__text--scroll');

    const lines = [];   // { style, align, wrap, area }
    let current = null;

    // tools that act on the line being written
    const tools = el('div', 'tools');
    const styleSeg = segmented([['heading', L('style_heading')], ['body', L('style_body')]], 'body', (val) => {
        if (!current) return;
        current.style = val;
        styleLine(current);
    }, true);
    const alignButtons = {};
    const alignBox = el('div', 'bar');
    for (const a of ['left', 'center', 'right']) {
        alignButtons[a] = iconButton('btn--small', a, L('align_' + a), () => {
            if (!current) return;
            current.align = a;
            styleLine(current);
        });
        alignBox.appendChild(alignButtons[a]);
    }
    const addBtn = button('btn--small', L('add_line'), () => addLine('body', 'left', current));
    const removeBtn = button('btn--small', L('remove_line'), () => removeLine(current));
    const paperPrev = iconButton('btn--small', 'prev', null, () => turnPaper(-1));
    const paperNext = iconButton('btn--small', 'next', null, () => turnPaper(1));
    const paperLabel = el('span', 'scope', L('paper'));
    tools.append(paperPrev, paperLabel, paperNext, el('span', 'tools__sep'), styleSeg.el,
        el('span', 'tools__sep'), alignBox, el('span', 'tools__sep'), addBtn, removeBtn);

    function turnPaper(step) {
        paperIndex = (paperIndex + step + PAPER_IDS.length) % PAPER_IDS.length;
        const id = PAPER_IDS[paperIndex];
        bg.style.backgroundImage = paperUrl(id);
        placeText(text, id);
    }

    function grow(area) {
        area.style.height = 'auto';
        area.style.height = area.scrollHeight + 'px';
    }

    // the style goes on the wrapper; the box inside inherits its font and alignment
    function styleLine(line) {
        line.wrap.className = `edit ln ln--${line.style} al-${line.align}` + (line === current ? ' is-current' : '');
        line.area.maxLength = line.style === 'heading' ? MAX_HEADING : MAX_BODY;
        line.area.placeholder = line.style === 'heading' ? L('heading_hint') : L('body_hint');
        grow(line.area);
        if (line === current) refreshTools();
    }

    function refreshTools() {
        styleSeg.set(current ? current.style : 'body');
        for (const a in alignButtons) alignButtons[a].classList.toggle('btn--gold', !!current && current.align === a);
        addBtn.disabled = lines.length >= MAX_LINES;
        removeBtn.disabled = lines.length <= 1;
    }

    function select(line) {
        if (current) current.wrap.classList.remove('is-current');
        current = line;
        if (line) line.wrap.classList.add('is-current');
        refreshTools();
    }

    function addLine(style, align, after) {
        if (lines.length >= MAX_LINES) return null;
        const wrap = el('div', 'edit');
        const area = el('textarea');
        area.rows = 1;
        area.spellcheck = false;
        const line = { style, align, wrap, area };
        area.addEventListener('focus', () => select(line));
        area.addEventListener('input', () => grow(area));
        wrap.appendChild(area);
        const at = after ? lines.indexOf(after) + 1 : lines.length;
        if (after && after.wrap.nextSibling) text.insertBefore(wrap, after.wrap.nextSibling);
        else text.appendChild(wrap);
        lines.splice(at, 0, line);
        styleLine(line);
        area.focus();
        return line;
    }

    function removeLine(line) {
        if (!line || lines.length <= 1) return;
        const i = lines.indexOf(line);
        lines.splice(i, 1);
        line.wrap.remove();
        const nextLine = lines[Math.min(i, lines.length - 1)];
        select(nextLine);
        nextLine.area.focus();
    }

    // bar
    const scope = opts.allBoardsAllowed ? scopeChoice() : null;
    const bar = el('div', 'bar');
    let layer;
    const discard = button('btn--danger', L('discard'), () => layer.close());
    const pin = button('btn--gold', L('pin'), async () => {
        const written = lines
            .map((l) => ({ style: l.style, align: l.align, text: l.area.value.trim() }))
            .filter((l) => l.text !== '');
        if (written.length === 0) {
            shake(sheet);
            toast(L('write_first'), true);
            return;
        }
        pin.disabled = discard.disabled = true;
        const ok = await opts.onSave({
            paper: PAPER_IDS[paperIndex],
            lines: written,
            section: opts.section,
            allBoards: scope ? scope.allBoards() : false,
        });
        pin.disabled = discard.disabled = false;
        if (ok) layer.close();
    });
    bar.append(discard, pin);

    box.append(sectionLine(opts.section), sheet, tools);
    if (scope) box.appendChild(scope.el);
    box.appendChild(bar);

    // Esc and clicks beside the form do nothing here: typed text is only thrown away with Discard
    layer = openLayer(box, { escCloses: false, clickOutsideCloses: false });

    const first = addLine('heading', 'center', null);
    addLine('body', 'left', first);
    first.area.focus();
    return layer;
}

// ---------- a picture notice ----------
// opts: { allBoardsAllowed, refusedHosts: string[], onSave(content) -> Promise<boolean> }

export function openPictureForm(opts) {
    const box = el('div', 'sheet');
    const form = el('div', 'sheet__form');
    const label = el('label', 'sheet__label', L('link_label'));
    const row = el('div', 'sheet__row');
    const input = el('input', 'sheet__input');
    input.type = 'text';
    input.spellcheck = false;
    input.autocomplete = 'off';
    input.maxLength = MAX_URL;
    const check = button('btn--small', L('link_check'), () => checkLink());
    row.append(input, check);
    form.append(label, row, el('p', 'sheet__help', L('link_help')));

    const preview = el('div', 'sheet__preview', L('picture_placeholder'));
    let approved = '';

    const scope = opts.allBoardsAllowed ? scopeChoice() : null;
    const bar = el('div', 'bar');
    let layer;
    const discard = button('btn--danger', L('discard'), () => layer.close());
    const pin = button('btn--gold', L('pin'), async () => {
        if (!approved) return;
        pin.disabled = discard.disabled = true;
        const ok = await opts.onSave({ picture: approved, section: opts.section, allBoards: scope ? scope.allBoards() : false });
        discard.disabled = false;
        pin.disabled = !approved;
        if (ok) layer.close();
    });
    pin.disabled = true;
    bar.append(discard, pin);

    function refuse(key) {
        approved = '';
        pin.disabled = true;
        shake(input);
        toast(L(key), true);
        input.focus();
    }

    function checkLink() {
        const url = input.value.trim();
        if (url === '') return refuse('link_missing');
        const path = url.split(/[?#]/)[0];
        if (url.length > MAX_URL || /\s/.test(url) || !/^https?:\/\/[^/]+\/.+\.(png|jpe?g|gif|webp)$/i.test(path)) {
            return refuse('link_invalid');
        }
        const low = url.toLowerCase();
        if ((opts.refusedHosts || []).some((h) => h && low.includes(String(h).toLowerCase()))) {
            return refuse('link_blocked');
        }
        const img = el('img');
        img.alt = '';
        img.referrerPolicy = 'no-referrer';
        img.addEventListener('load', () => {
            if (input.value.trim() !== url) return; // the link changed while it loaded
            approved = url;
            pin.disabled = false;
            preview.replaceChildren(img);
        }, { once: true });
        img.addEventListener('error', () => {
            preview.replaceChildren(document.createTextNode(L('picture_placeholder')));
            refuse('link_broken');
        }, { once: true });
        preview.replaceChildren(document.createTextNode(L('loading')));
        img.src = url;
    }

    input.addEventListener('input', () => { approved = ''; pin.disabled = true; });
    input.addEventListener('keydown', (e) => { if (e.key === 'Enter') checkLink(); });

    box.append(sectionLine(opts.section), form, preview);
    if (scope) box.appendChild(scope.el);
    box.appendChild(bar);

    layer = openLayer(box, { escCloses: false, clickOutsideCloses: false });
    input.focus();
    return layer;
}
