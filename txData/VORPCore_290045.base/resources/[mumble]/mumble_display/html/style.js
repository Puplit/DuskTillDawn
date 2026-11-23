// driven entirely by cl.lua; no jQuery, no external requests
var body = document.body;
var mic1 = document.querySelector('.mic1');       // talking
var mic2 = document.querySelector('.mic2');       // idle
var wave = document.querySelector('.wave3');
var range = document.getElementById('range'); // metre readout

window.addEventListener('message', function (event) {
    var data = event.data || {};

    if (data.visible === false) {
        body.classList.add('hidden');
        return;
    }
    body.classList.remove('hidden');

    if (data.talking) {
        mic1.classList.remove('hide');
        mic2.classList.add('hide');
    } else {
        mic1.classList.add('hide');
        mic2.classList.remove('hide');
    }

    // fill level of the circle, set straight from Lua so adding a voice mode
    // needs no change here
    if (data.fill) wave.style.setProperty('--top', data.fill);

    // same idea for the range: Lua does the metres, this only prints them
    if (range && typeof data.range === 'string') range.textContent = data.range;
});
