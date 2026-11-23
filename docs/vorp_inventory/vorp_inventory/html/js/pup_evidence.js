/* Evidence locker - "Add to Evidence Log" on a searched player's items.
   Presentation only: the server re-checks job, duty and both distances before
   it moves anything. Binds off the grid-refresh message rather than wrapping
   BIND_ITEM_DATA, which other scripts already wrap. */
(function () {
    'use strict';

    window.pupEvidence = { station: null, label: 'Add to Evidence Log' };
    window.pupEvidenceStats = { binds: 0, cells: 0 };

    // anything can be booked in; what matters is who took it and from whom
    function canSeize(item) {
        if (typeof type === 'undefined' || type !== 'steal') return false;
        if (!window.pupEvidence.station) return false;
        return !!(item && item.name);
    }

    function seize(item) {
        $.post('https://' + GetParentResourceName() + '/PupEvidenceSeize', JSON.stringify({
            item: {
                id: item.id,
                name: item.name,
                label: item.label,
                type: item.type,
                metadata: item.metadata || {},
            },
        }));
    }

    function bindAll() {
        if (typeof type === 'undefined' || type !== 'steal') return;
        var $cells = $('#secondInventoryElement').children('.item');
        window.pupEvidenceStats.cells = $cells.length;

        $cells.each(function () {
            var $cell = $(this);
            if (!$cell.data('item')) return;

            // the plugin stacks on 'contextmenu' and pup_storagebox bound a
            // handler that refuses steal, so the earlier ones have to go
            $cell.off('contextmenu');
            window.pupEvidenceStats.binds++;

            $cell.contextMenu(
                function () {
                    var current = $(this).data('item');
                    return [[{
                        text: window.pupEvidence.label,
                        action: function () { seize(current); },
                    }]];
                },
                {
                    offsetX: 1,
                    offsetY: 1,
                    beforeShow: function () { return canSeize($(this).data('item')); },
                }
            );
        });
    }

    window.addEventListener('message', function (event) {
        var data = event.data || {};

        if (data.action === 'pupEvidenceDebug') {
            $.post('https://' + GetParentResourceName() + '/PupEvidenceDebug', JSON.stringify({
                station: window.pupEvidence.station,
                type: typeof type !== 'undefined' ? String(type) : 'UNDEFINED',
                stealid: typeof stealid !== 'undefined' ? String(stealid) : 'UNDEFINED',
                bound: $('#secondInventoryElement').children('.item').length,
                plugin: typeof $.fn.contextMenu === 'function',
                binds: window.pupEvidenceStats.binds,
                cells: window.pupEvidenceStats.cells,
            }));
            return;
        }

        // rebind after the grid is rebuilt or a row changes
        if (data.action === 'setSecondInventoryItems' ||
            data.action === 'secondaryItemAdded' ||
            data.action === 'secondaryItemRemoved' ||
            data.action === 'secondaryItemUpdated') {
            setTimeout(bindAll, 60);
            return;
        }

        if (data.action !== 'pupEvidenceState') return;

        if (typeof data.label === 'string' && data.label) window.pupEvidence.label = data.label;
        // undefined leaves the station alone; null/false clears it
        if (data.station !== undefined) {
            window.pupEvidence.station = data.station || null;
            // the station can land after the grid was drawn
            if (window.pupEvidence.station) setTimeout(bindAll, 60);
        }
    });
})();
