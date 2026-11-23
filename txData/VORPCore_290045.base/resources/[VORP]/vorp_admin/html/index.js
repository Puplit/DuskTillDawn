const copyToClipboard = str => {
    const el = document.createElement('textarea');
    el.value = str;
    document.body.appendChild(el);
    el.select();
    document.execCommand('copy');
    document.body.removeChild(el);
 };

window.addEventListener('message', (event) => {
    // guard: only clipboard messages carry .string - panel.js messages (app='panel')
    // must not overwrite the clipboard with "undefined"
    if (typeof event.data.string === 'string') {
        copyToClipboard(event.data.string);
    }
});