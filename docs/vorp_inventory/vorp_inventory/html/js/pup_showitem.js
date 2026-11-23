/* SHOW ITEM - holds an item up so nearby players see what it is.
   The client sends one batched message per frame with screen coords already
   resolved, same shape pup-ui's world pills use. Cards are keyed by player id
   and reused, so only the transform moves between frames. */

(() => {
    const wrap = document.getElementById('showItemWrap');
    if (!wrap) return;

    const cards = {}; // serverId -> element

    function render(data) {
        const items = (data && data.items) || [];
        const seen = {};

        items.forEach((p) => {
            seen[p.id] = true;
            let el = cards[p.id];
            if (!el) {
                el = document.createElement('div');
                el.className = 'showitem-card';
                el.innerHTML =
                    '<div class="showitem-img"><img alt=""></div>' +
                    '<div class="showitem-name"></div>';
                cards[p.id] = el;
                wrap.appendChild(el);
            }

            // only rewrite when it actually changed - this runs every frame
            if (el.dataset.label !== p.label) {
                el.dataset.label = p.label;
                el.querySelector('.showitem-name').textContent = p.label || '';
            }
            // the server resolves the image key (metadata.image, else the item
            // name); sanitise it the same way the inventory tooltips do
            if (el.dataset.img !== p.img) {
                el.dataset.img = p.img;
                const key = (typeof UTILS !== 'undefined' && UTILS.SAFE_ITEM_IMAGE)
                    ? UTILS.SAFE_ITEM_IMAGE(p.img)
                    : String(p.img || 'placeholder').replace(/[^a-zA-Z0-9._-]/g, '_');
                const img = el.querySelector('img');
                img.onerror = function () { this.onerror = null; this.src = 'img/items/placeholder.png'; };
                img.src = 'img/items/' + key + '.png';
            }

            el.style.transform =
                'translate(-50%,-100%) translate(' + (p.x * 100) + 'vw,' + (p.y * 100) + 'vh)';
            el.style.opacity = p.a != null ? p.a : 1;
        });

        for (const id in cards) {
            if (!seen[id]) { cards[id].remove(); delete cards[id]; }
        }
    }

    function hide() {
        for (const id in cards) { cards[id].remove(); delete cards[id]; }
    }

    window.addEventListener('message', (e) => {
        const d = e.data || {};
        if (d.action === 'pupShowItem') render(d.data);
        else if (d.action === 'pupShowItemHide') hide();
    });
})();
