// pup-pinboard | drawing notices: written notices on paper, picture notices as prints, the big view
//
// Saved notice format (server/main.lua writes only these fields):
//   text:    { paper = 1..6, section, lines = { { style = 'heading'|'body', align = 'left'|'center'|'right', text = '...' } } }
//   picture: { picture = 'https://...', section }

import { el, L, button, iconButton, openLayer, topLayer, ask } from './shared.js';

// where the writing sits on each paper, in % of the paper (top, bottom, left, right)
export const PAPERS = {
    1: [5, 5, 8, 8],
    2: [3, 3, 12, 12],
    3: [5, 6, 12, 12],
    4: [3, 3, 9, 11],
    5: [4, 4, 12, 11],
    6: [4, 4, 8, 8],
};
export const PAPER_IDS = Object.keys(PAPERS).map(Number);
export const DEFAULT_PAPER = 5;

// the board's sections, in tab order. The ids match server/main.lua; the words come from config/locale.lua.
export const SECTIONS = ['sale', 'buying', 'jobs', 'notices'];
export function sectionOf(item) {
    return SECTIONS.includes(item && item.section) ? item.section : 'notices';
}

// our own drawings (html/img): paper_1..6.svg, and torn_1..3.svg for a picture that will not load
const TORN = [1, 2, 3].map((n) => `img/torn_${n}.svg`);

export function paperId(id) {
    id = Number(id);
    return PAPERS[id] ? id : DEFAULT_PAPER;
}

export function paperUrl(id) {
    return `url(img/paper_${paperId(id)}.svg)`;
}

export function cleanStyle(s) { return s === 'heading' ? 'heading' : 'body'; }
export function cleanAlign(a) { return (a === 'center' || a === 'right') ? a : 'left'; }

// an empty sheet of the given paper; the caller fills .paper__text
export function paperSheet(id) {
    id = paperId(id);
    const sheet = el('div', 'paper');
    const bg = el('div', 'paper__bg');
    bg.style.backgroundImage = paperUrl(id);
    const text = el('div', 'paper__text');
    placeText(text, id);
    sheet.append(bg, text);
    return { sheet, bg, text };
}

export function placeText(textEl, id) {
    const [t, b, l, r] = PAPERS[paperId(id)];
    Object.assign(textEl.style, { top: t + '%', bottom: b + '%', left: l + '%', right: r + '%' });
}

function writtenNotice(content, scroll) {
    const { sheet, text } = paperSheet(content.paper);
    if (scroll) text.classList.add('paper__text--scroll');
    const lines = Array.isArray(content.lines) ? content.lines : [];
    for (const line of lines) {
        if (!line || typeof line.text !== 'string') continue;
        text.appendChild(el('p', `ln ln--${cleanStyle(line.style)} al-${cleanAlign(line.align)}`, line.text));
    }
    return sheet;
}

function pictureNotice(content, full) {
    const frame = el('div', 'photo' + (full ? ' photo--full' : ''));
    const img = el('img');
    img.alt = '';
    img.referrerPolicy = 'no-referrer';
    img.addEventListener('load', () => img.classList.add('is-loaded'), { once: true });
    img.addEventListener('error', () => {
        frame.classList.add('is-torn');
        img.src = TORN[Math.floor(Math.random() * TORN.length)];
    }, { once: true });
    const url = String(content.picture || '');
    const isLink = /^https?:\/\//i.test(url);
    if (!isLink) frame.classList.add('is-torn');
    img.src = isLink ? url : TORN[0];
    frame.appendChild(img);
    return frame;
}

export function noticeBody(item, full) {
    const content = (item && typeof item.content === 'object' && item.content) || {};
    return item.kind === 'picture' ? pictureNotice(content, full) : writtenNotice(content, full);
}

export const SLIPS = 6;

// how many slips are gone from a notice's fringe: a few from the start (so a board never
// looks untouched), plus any this player tore off while the board was open
export function slipsGone(item, tornNow) {
    const id = Number(item.id) || 0;
    return Math.min(SLIPS, ((id * 7) % 3) + (tornNow || 0));
}

// the small notice pinned to the board. tornNow: slips this player took from it this visit.
export function noticeCard(item, isMine, onOpen, tornNow) {
    const card = el('button', 'card');
    card.type = 'button';
    const id = Number(item.id) || 0;
    card.style.setProperty('--tilt', ((id * 37) % 7 - 3) * 0.7 + 'deg');

    // tape across the top in the section's colour
    const tape = el('span', `card__tape sec-${sectionOf(item)}`);
    tape.style.setProperty('--tape-tilt', ((id * 13) % 5 - 2) + 'deg');
    card.appendChild(tape);

    card.appendChild(noticeBody(item, false));
    if (isMine) card.appendChild(el('span', 'card__seal', L('yours')));

    // tear-off slips with the poster's PO box; torn ones leave a stub, from the right
    if (item.poBox) {
        const fringe = el('div', 'fringe');
        const gone = slipsGone(item, tornNow);
        for (let i = 0; i < SLIPS; i++) {
            const slip = el('span', 'fringe__tab' + (i >= SLIPS - gone ? ' is-torn' : ''), L('fringe_slip', item.poBox));
            fringe.appendChild(slip);
        }
        card.appendChild(fringe);
    }

    card.addEventListener('click', onOpen);
    return card;
}

// the big view, with arrows through the notices currently shown on the board
// list: the notices in board order. index: the one to open. canRemove(item).
// onRemove(item) -> Promise<boolean>. onTear(item): a slip was torn off.
export function openDetail(list, index, canRemove, onRemove, onTear) {
    const box = el('div', 'detail');
    const row = el('div', 'detail__row');
    const slot = el('div');
    const bar = el('div', 'bar');
    const count = el('span', 'detail__count');
    // section, "Write to PO Box ...", and a slip to tear off, between the notice and the buttons
    const info = el('div', 'detail__info');
    const infoSection = el('span', 'card__section');
    const infoBox = el('span', 'detail__box');
    const tear = button('btn--small btn--gold', L('tear_slip'), () => {
        const item = list[current];
        if (item && item.poBox && onTear) onTear(item);
    });
    info.append(infoSection, infoBox, tear);
    let layer;
    let current = index;

    const prev = iconButton('btn--round', 'prev', null, () => go(-1));
    const next = iconButton('btn--round', 'next', null, () => go(1));
    const unpin = button('btn--danger', L('unpin'), async () => {
        const item = list[current];
        if (!(await ask(L('unpin_question'), L('unpin_confirm'), L('unpin_cancel'), true))) return;
        unpin.disabled = true;
        const removed = await onRemove(item);
        unpin.disabled = false;
        if (removed) layer.close();
    });
    const close = button('', L('close_notice'), () => layer.close());

    function show() {
        const item = list[current];
        slot.replaceChildren(noticeBody(item, true));
        count.textContent = list.length > 1 ? `${current + 1} / ${list.length}` : '';
        prev.style.visibility = next.style.visibility = list.length > 1 ? 'visible' : 'hidden';
        unpin.classList.toggle('hidden', !canRemove(item));
        const sec = sectionOf(item);
        infoSection.className = `card__section sec-${sec}`;
        infoSection.textContent = L('section_' + sec);
        infoBox.textContent = item.poBox ? L('write_to', item.poBox) : '';
        infoBox.classList.toggle('hidden', !item.poBox);
        tear.classList.toggle('hidden', !item.poBox);
    }

    function go(step) {
        current = (current + step + list.length) % list.length;
        show();
    }

    row.append(prev, slot, next);
    bar.append(unpin, count, close);
    box.append(row, info, bar);
    show();

    const keys = (e) => {
        // only while the big view is on top (not under an "are you sure?")
        if (layer !== topLayer()) return;
        if (e.key === 'ArrowLeft') go(-1);
        else if (e.key === 'ArrowRight') go(1);
    };
    window.addEventListener('keydown', keys);
    layer = openLayer(box);
    const baseClose = layer.close;
    layer.close = () => { window.removeEventListener('keydown', keys); baseClose(); };
    return layer;
}
