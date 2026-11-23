/* pup_postoffice | emoji picker: one small popover shared by chats, thread replies and letters */
'use strict';

const EMOJI = (() => {
    const { h } = U;

    // Emoji 12 and older only, so every glyph draws with the emoji font Windows 10 ships
    const SETS = [
        { key: 'frontier', label: 'Frontier', icon: '🤠', list: '🤠 🐎 🐴 🏇 🌵 🏜️ ⛺ 🔥 🪓 🔫 🏹 🗡️ 💰 💵 💎 🥃 🍺 🍷 🚬 🃏 🎲 🎩 👢 🧭 🗺️ ⚓ 🚂 🛤️ ⛏️ 🐄 🐂 🐖 🐑 🐓 🦅 🐺 🐻 🐍 🦌 🐟 🎣 ⚰️ 💀 ☠️ ⭐ 🌙 ☀️ ⛈️ 🌧️ ❄️ 🌾 🌲 🏔️ 📜 ✉️ 📯 🕯️ 🔔 ⚖️ 🔒 🔑 ⛪ 🏠 🏚️' },
        { key: 'faces', label: 'Faces', icon: '😀', list: '😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 😉 😍 😘 😋 😛 😜 🤪 🤔 🤨 😐 😑 😶 🙄 😏 😬 😌 😔 😪 😴 😷 🤒 🤕 🤢 🤮 🥵 🥶 😵 🤯 😎 🤓 🧐 😕 😟 🙁 😮 😯 😲 😳 🥺 😦 😧 😨 😰 😥 😢 😭 😱 😖 😣 😞 😓 😩 😫 😤 😡 😠 🤬 😈 👿 💩 🤡 👻' },
        { key: 'people', label: 'Hands and people', icon: '👍', list: '👍 👎 👌 ✌️ 🤞 🤝 👏 🙌 🙏 💪 👋 🤙 👉 👈 👆 👇 ☝️ ✋ 🤚 🖐️ ✊ 👊 🤷 🤦 🙋 🙅 🙆 💃 🕺 👀 👂 👃 👄 🧔 👩 👨 👵 👴 👶' },
        { key: 'food', label: 'Food and drink', icon: '🍖', list: '🍖 🥩 🍗 🥓 🍞 🥖 🧀 🥚 🍳 🥔 🥕 🌽 🍎 🍏 🍐 🍑 🍒 🍓 🍇 🍉 🥧 🍰 🍯 🥛 ☕ 🍵 🧂' },
        { key: 'symbols', label: 'Symbols', icon: '❤️', list: '❤️ 🧡 💛 💚 💙 💜 🖤 🤍 💔 ❣️ 💕 💯 ✅ ❌ ❗ ❓ ⚠️ 🚫 💤 💢 💥 💫 💦 💨 ✨ 🎉 🎶 ♠️ ♥️ ♦️ ♣️ ➡️ ⬅️ ⬆️ ⬇️ 🔴 🟢 🔵 ⚪ ⚫' },
    ].map(s => Object.assign(s, { list: s.list.split(' ').filter(Boolean) }));

    const RECENT_KEY = 'pup_postoffice.emojiRecent';
    const RECENT_MAX = 24;

    function recent() {
        try {
            const v = JSON.parse(localStorage.getItem(RECENT_KEY) || '[]');
            return Array.isArray(v) ? v.filter(e => typeof e === 'string' && e.length <= 16).slice(0, RECENT_MAX) : [];
        } catch (e) { return []; }
    }
    function remember(e) {
        try { localStorage.setItem(RECENT_KEY, JSON.stringify([e].concat(recent().filter(x => x !== e)).slice(0, RECENT_MAX))); } catch (err) { /* private storage: no recents */ }
    }

    let current = null; // { node, anchor, cleanup }

    function close() {
        if (!current) return false;
        const c = current;
        current = null;
        c.cleanup();
        if (c.node.parentNode) c.node.parentNode.removeChild(c.node);
        return true;
    }

    /** Place a popover under (or above) its anchor, inside the mail window. */
    function place(node, anchor, host) {
        const hr = host.getBoundingClientRect();
        const ar = anchor.getBoundingClientRect();
        const w = node.offsetWidth, ht = node.offsetHeight;
        let left = ar.right - hr.left - w;
        left = Math.max(8, Math.min(left, hr.width - w - 8));
        let top = ar.top - hr.top - ht - 6;
        if (top < 8) top = ar.bottom - hr.top + 6;
        top = Math.max(8, Math.min(top, hr.height - ht - 8));
        node.style.left = left + 'px';
        node.style.top = top + 'px';
    }

    function open(anchor, node) {
        const host = document.getElementById('win') || document.body;
        close();
        host.appendChild(node);
        place(node, anchor, host);
        const outside = e => { if (!node.contains(e.target) && !anchor.contains(e.target)) close(); };
        // a click that opened it must not close it straight away
        setTimeout(() => document.addEventListener('mousedown', outside, true), 0);
        current = { node, anchor, cleanup: () => document.removeEventListener('mousedown', outside, true) };
    }

    /** The full picker. onPick(emoji) runs for every emoji clicked; the picker stays open until clicked away. */
    function picker(anchor, onPick) {
        if (current && current.anchor === anchor) { close(); return; }
        let tab = recent().length ? 'recent' : 'frontier';
        const grid = h('div', { class: 'emo-grid' });
        const tabs = h('div', { class: 'emo-tabs' });
        const title = h('div', { class: 'emo-title' });
        const node = h('div', { class: 'emo-pop', on: { mousedown: e => { if (!e.target.closest('input')) e.preventDefault(); } } }, tabs, title, grid);
        const sets = () => [{ key: 'recent', label: 'Recently used', icon: '🕘', list: recent() }].concat(SETS);
        const draw = () => {
            U.clear(tabs); U.clear(grid);
            const all = sets();
            all.forEach(s => tabs.appendChild(h('button', {
                class: 'emo-tab emo' + (s.key === tab ? ' on' : ''), type: 'button', title: s.label,
                on: { click: () => { tab = s.key; draw(); } },
            }, s.icon)));
            const set = all.find(s => s.key === tab) || all[1];
            title.textContent = set.label;
            if (!set.list.length) grid.appendChild(h('div', { class: 'emo-none' }, 'Nothing used yet'));
            set.list.forEach(e => grid.appendChild(h('button', {
                class: 'emo-btn emo', type: 'button', title: e,
                on: { click: () => { remember(e); onPick(e); } },
            }, e)));
        };
        draw();
        open(anchor, node);
    }

    /** A small row of reactions. onPick(emoji) runs once and the row closes. */
    function quick(anchor, list, onPick) {
        if (current && current.anchor === anchor) { close(); return; }
        const node = h('div', { class: 'emo-pop quick', on: { mousedown: e => e.preventDefault() } },
            list.map(e => h('button', { class: 'emo-btn emo', type: 'button', title: e, on: { click: () => { close(); onPick(e); } } }, e)));
        open(anchor, node);
    }

    /** Put text at the caret of a textarea or input, as if it was typed. */
    function insertInto(input, text) {
        const max = input.maxLength > 0 ? input.maxLength : Infinity;
        const start = typeof input.selectionStart === 'number' ? input.selectionStart : input.value.length;
        const end = typeof input.selectionEnd === 'number' ? input.selectionEnd : start;
        if (input.value.length - (end - start) + text.length > max) return false;
        input.focus();
        input.setRangeText(text, start, end, 'end');
        input.dispatchEvent(new Event('input', { bubbles: true }));
        return true;
    }

    /** The emoji button for a textarea or input. */
    function buttonFor(input, cls) {
        const btn = h('button', { class: 'mini emo-open' + (cls ? ' ' + cls : ''), type: 'button', title: 'Emoji' }, h('span', { class: 'emo' }, '🙂'));
        btn.addEventListener('mousedown', e => e.preventDefault()); // keep the caret where it is
        // a chat redraw replaces the box while the picker is open: write into the one on screen now
        const target = () => {
            if (document.contains(input) || !input.dataset.k) return input;
            return document.querySelector(`[data-k="${input.dataset.k}"]`) || input;
        };
        btn.addEventListener('click', () => picker(btn, e => insertInto(target(), e)));
        return btn;
    }

    /** The emoji button for a rich-text editor (contentEditable). The caret is remembered while the picker has focus. */
    function buttonForEditor(editor, after) {
        let saved = null;
        const keep = () => {
            const sel = window.getSelection();
            if (sel && sel.rangeCount && editor.contains(sel.anchorNode)) saved = sel.getRangeAt(0).cloneRange();
        };
        ['keyup', 'mouseup', 'input', 'blur'].forEach(ev => editor.addEventListener(ev, keep));
        const btn = h('button', { class: 'mini emo-open', type: 'button', title: 'Emoji' }, h('span', { class: 'emo' }, '🙂'));
        btn.addEventListener('mousedown', e => e.preventDefault());
        btn.addEventListener('click', () => picker(btn, e => {
            editor.focus();
            const sel = window.getSelection();
            if (saved && sel) { sel.removeAllRanges(); sel.addRange(saved); }
            document.execCommand('insertText', false, e);
            keep();
            if (after) after();
        }));
        return btn;
    }

    return { picker, quick, close, insertInto, buttonFor, buttonForEditor, isOpen: () => !!current };
})();
