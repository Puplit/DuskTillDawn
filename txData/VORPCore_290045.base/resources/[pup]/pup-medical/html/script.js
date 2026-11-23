// pup-medical | death screen. Display only: the Lua side owns every rule.
(function () {
    'use strict';

    const root = document.getElementById('down');
    const title = document.getElementById('down-title');
    const count = document.getElementById('down-count');
    const hint = document.getElementById('down-hint');

    let timer = null;
    let left = 0;
    let label = 'Respawn in';

    function text(value) {
        return value === undefined || value === null ? '' : String(value);
    }

    function stopTimer() {
        if (timer !== null) {
            clearInterval(timer);
            timer = null;
        }
    }

    function drawCount() {
        count.textContent = left > 0 ? `${label} ${left}` : '';
    }

    function show(data) {
        stopTimer();
        title.textContent = text(data.title);
        hint.textContent = text(data.hint);
        label = text(data.label) || label;
        left = Math.max(0, Math.floor(Number(data.seconds) || 0));
        drawCount();
        if (left > 0) {
            timer = setInterval(() => {
                left -= 1;
                if (left <= 0) {
                    left = 0;
                    stopTimer();
                }
                drawCount();
            }, 1000);
        }
        root.classList.remove('shown');
        void root.offsetWidth; // restart the fade
        root.classList.add('shown');
    }

    function hide() {
        stopTimer();
        root.classList.remove('shown');
        title.textContent = '';
        count.textContent = '';
        hint.textContent = '';
    }

    window.addEventListener('message', (event) => {
        const data = event.data;
        if (!data || typeof data !== 'object') return;
        switch (data.action) {
            case 'deathShow':
                show(data);
                break;
            case 'deathHint':
                hint.textContent = text(data.hint);
                break;
            case 'deathHide':
                hide();
                break;
            default:
                break;
        }
    });
})();
