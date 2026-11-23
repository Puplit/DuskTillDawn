// pup_library | on-screen cleaning of page HTML. The server cleans again on save.
(function () {
    'use strict';

    const ALLOWED_TAGS = new Set([
        'p', 'br', 'span', 'div', 'strong', 'b', 'em', 'i', 'u', 's', 'strike', 'del', 'ins', 'sub', 'sup',
        'small', 'big', 'mark', 'font', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote', 'pre', 'code',
        'ul', 'ol', 'li', 'hr', 'a', 'img', 'figure', 'figcaption', 'table', 'thead', 'tbody', 'tfoot',
        'tr', 'th', 'td', 'colgroup', 'col', 'caption',
    ]);

    const DROP_WITH_CONTENT = new Set([
        'script', 'style', 'iframe', 'frame', 'frameset', 'object', 'embed', 'noscript', 'template',
        'svg', 'math', 'textarea', 'select', 'option', 'button', 'input', 'form', 'link', 'meta', 'base',
        'title', 'head', 'audio', 'video', 'source', 'track', 'canvas',
    ]);

    const ALLOWED_ATTRS = new Set([
        'style', 'class', 'colspan', 'rowspan', 'align', 'width', 'height', 'alt', 'title',
        'href', 'src', 'color', 'face', 'size',
    ]);

    const BAD_STYLE = ['url(', 'expression', 'javascript', '@import', 'behavior', '\\', '&#', '<'];

    function url(value) {
        if (typeof value !== 'string') return null;
        const v = value.replace(/^\s+/, '');
        const low = v.toLowerCase();
        if (low.startsWith('http://') || low.startsWith('https://') || low.startsWith('nui://')) return v;
        if (/^data:image\/(png|jpeg|jpg|gif|webp);base64,[a-z0-9+/=\s]*$/i.test(v)) return v;
        return null;
    }

    function style(value) {
        if (typeof value !== 'string') return null;
        const low = value.toLowerCase();
        for (const bad of BAD_STYLE) if (low.includes(bad)) return null;
        return value;
    }

    function background(value) {
        if (typeof value !== 'string' || value === '' || value.length > 2048) return null;
        if (/[\s"'()[\]{}<>\\]/.test(value)) return null;
        return url(value);
    }

    function colour(value) {
        if (typeof value !== 'string' || value === '' || value.length > 40) return null;
        if (/[^A-Za-z0-9 #(),.%]/.test(value)) return null;
        const low = value.toLowerCase();
        if (low.includes('url') || low.includes('expression')) return null;
        return value;
    }

    function cleanAttributes(el) {
        for (const attr of Array.from(el.attributes)) {
            const name = attr.name.toLowerCase();
            if (!ALLOWED_ATTRS.has(name)) { el.removeAttribute(attr.name); continue; }
            let ok = attr.value;
            if (name === 'href' || name === 'src') ok = url(attr.value);
            else if (name === 'style') ok = style(attr.value);
            if (ok === null) el.removeAttribute(attr.name);
        }
    }

    function cleanChildren(parent) {
        for (const child of Array.from(parent.childNodes)) {
            if (child.nodeType === Node.TEXT_NODE) continue;
            if (child.nodeType !== Node.ELEMENT_NODE) { child.remove(); continue; }
            const tag = child.localName.toLowerCase();
            if (DROP_WITH_CONTENT.has(tag)) { child.remove(); continue; }
            cleanChildren(child);
            if (!ALLOWED_TAGS.has(tag)) {
                while (child.firstChild) parent.insertBefore(child.firstChild, child);
                child.remove();
                continue;
            }
            cleanAttributes(child);
        }
    }

    // The parse happens in a detached document: nothing in it runs or loads.
    function html(source) {
        if (typeof source !== 'string' || source === '') return '';
        const doc = new DOMParser().parseFromString('<!doctype html><html><body></body></html>', 'text/html');
        const holder = doc.createElement('div');
        holder.innerHTML = source;
        cleanChildren(holder);
        return holder.innerHTML;
    }

    window.PupClean = { html, url, style, background, colour };
})();
