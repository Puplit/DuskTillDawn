/* pup_ranchero | minigame pictures, drawn for this resource as inline SVG (5:6, transparent).
   Static markup only: nothing from the game or from players is ever put into these strings. */
'use strict';

(function () {
    const pail = (x, y, s) => `
<g transform="translate(${x} ${y}) scale(${s})">
  <path d="M-15 -38 Q0 -62 15 -38" fill="none" stroke="#5e656b" stroke-width="2.4"/>
  <path d="M-17 -30 L17 -30 L13 8 L-13 8 Z" fill="url(#rgPail)" stroke="#4d555c" stroke-width="1.6"/>
  <path d="M-15.5 -18 L15.5 -18" stroke="#7b848c" stroke-width="1.4"/>
  <path d="M-14 -4 L14 -4" stroke="#7b848c" stroke-width="1.4"/>
  <ellipse cx="0" cy="-30" rx="17" ry="4.6" fill="#b9c1c8" stroke="#4d555c" stroke-width="1.6"/>
  <ellipse cx="0" cy="-30" rx="14.6" ry="3.4" fill="#fbfaf3"/>
  <ellipse cx="-4" cy="-31" rx="5" ry="1.1" fill="#ffffff"/>
  <circle cx="-17" cy="-30" r="1.6" fill="#4d555c"/><circle cx="17" cy="-30" r="1.6" fill="#4d555c"/>
  <path d="M-11 -26 L-9 4" stroke="#ffffff" stroke-opacity="0.45" stroke-width="2.4"/>
</g>`;

    const egg = (x, y, r) => `
<g transform="translate(${x} ${y}) rotate(${r})">
  <ellipse cx="0" cy="0" rx="7.4" ry="9.6" fill="url(#rgEgg)" stroke="#6e3f1d" stroke-width="1.2"/>
  <ellipse cx="-2.4" cy="-3.6" rx="2" ry="3" fill="#ffffff" fill-opacity="0.55"/>
</g>`;

    const defs = `
<defs>
  <linearGradient id="rgStraw" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#ffe773"/><stop offset="0.55" stop-color="#f1c232"/><stop offset="1" stop-color="#c7901b"/>
  </linearGradient>
  <linearGradient id="rgSack" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#5f6b28"/><stop offset="0.45" stop-color="#8b9a3f"/><stop offset="1" stop-color="#55601f"/>
  </linearGradient>
  <linearGradient id="rgStave" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#b9561a"/><stop offset="0.4" stop-color="#f39236"/><stop offset="1" stop-color="#b14d14"/>
  </linearGradient>
  <linearGradient id="rgWater" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#7cc8f2"/><stop offset="1" stop-color="#2a7fc4"/>
  </linearGradient>
  <linearGradient id="rgPail" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#8f979e"/><stop offset="0.35" stop-color="#e3e7ea"/><stop offset="1" stop-color="#7b838a"/>
  </linearGradient>
  <linearGradient id="rgWicker" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#f2c45a"/><stop offset="1" stop-color="#b9801f"/>
  </linearGradient>
  <radialGradient id="rgEgg" cx="0.4" cy="0.35" r="0.7">
    <stop offset="0" stop-color="#e2a878"/><stop offset="1" stop-color="#a5643a"/>
  </radialGradient>
  <linearGradient id="rgDung" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#8d5a2b"/><stop offset="1" stop-color="#5e3815"/>
  </linearGradient>
</defs>`;

    const bale = (dy) => `
<g transform="translate(0 ${dy})">
  <path d="M10 26 L20 16 L96 16 L88 26 Z" fill="#ffef9a" stroke="#a87414" stroke-width="1.4"/>
  <path d="M88 26 L96 16 L96 56 L88 66 Z" fill="#c99219" stroke="#a87414" stroke-width="1.4"/>
  <rect x="10" y="26" width="78" height="40" rx="3" fill="url(#rgStraw)" stroke="#a87414" stroke-width="1.4"/>
  <path d="M16 34 l9 2 M40 31 l10 1 M60 40 l11 -1 M20 50 l8 3 M46 55 l10 -2 M70 58 l9 1 M30 43 l7 -2"
        stroke="#b98316" stroke-width="1.3" stroke-linecap="round"/>
  <path d="M28 26 L34 26 L42 16 L36 16 Z M28 26 h6 v40 h-6 Z" fill="#7d6f5c" stroke="#4f4434" stroke-width="1"/>
  <path d="M64 26 L70 26 L78 16 L72 16 Z M64 26 h6 v40 h-6 Z" fill="#7d6f5c" stroke="#4f4434" stroke-width="1"/>
  <ellipse cx="30" cy="31" rx="14" ry="2.6" fill="#ffffff" fill-opacity="0.4"/>
</g>`;

    window.RANCH_ART = {
        bales: `<svg viewBox="0 0 100 120" xmlns="http://www.w3.org/2000/svg">${defs}${bale(44)}${bale(4)}</svg>`,

        dung: `<svg viewBox="0 0 100 120" xmlns="http://www.w3.org/2000/svg">${defs}
  <ellipse cx="50" cy="98" rx="40" ry="16" fill="url(#rgDung)" stroke="#2f1b0b" stroke-width="3.2"/>
  <ellipse cx="50" cy="79" rx="30" ry="13" fill="url(#rgDung)" stroke="#2f1b0b" stroke-width="3.2"/>
  <ellipse cx="50" cy="62" rx="20" ry="10" fill="url(#rgDung)" stroke="#2f1b0b" stroke-width="3.2"/>
  <path d="M44 54 Q46 38 58 36 Q54 44 60 50 Q54 56 44 54 Z" fill="#7a4a22" stroke="#2f1b0b" stroke-width="3.2" stroke-linejoin="round"/>
  <ellipse cx="34" cy="93" rx="7" ry="3" fill="#ffffff" fill-opacity="0.45"/>
  <ellipse cx="38" cy="75" rx="5" ry="2.4" fill="#ffffff" fill-opacity="0.45"/>
  <ellipse cx="44" cy="59" rx="3.4" ry="1.8" fill="#ffffff" fill-opacity="0.5"/>
  <circle cx="68" cy="97" r="1.8" fill="#ffffff" fill-opacity="0.35"/>
</svg>`,

        sack: `<svg viewBox="0 0 100 120" xmlns="http://www.w3.org/2000/svg">${defs}
  <path d="M22 40 Q12 72 19 104 Q50 117 81 104 Q88 72 78 40 Z" fill="url(#rgSack)" stroke="#3e4614" stroke-width="2"/>
  <ellipse cx="50" cy="39" rx="29" ry="8.5" fill="#4b5519" stroke="#3e4614" stroke-width="2"/>
  <ellipse cx="50" cy="37" rx="23" ry="5.6" fill="#e9c76c"/>
  <path d="M30 37 Q40 26 50 30 Q60 25 70 37 Z" fill="#f0d27d"/>
  <g fill="#e2bb59" stroke="#b58a2c" stroke-width="0.6">
    <ellipse cx="26" cy="47" rx="2.2" ry="1.4"/><ellipse cx="22" cy="54" rx="2" ry="1.3"/>
    <ellipse cx="25" cy="61" rx="2.2" ry="1.4"/><ellipse cx="19" cy="68" rx="2" ry="1.3"/>
    <ellipse cx="16" cy="108" rx="2.2" ry="1.4"/><ellipse cx="10" cy="111" rx="2" ry="1.3"/>
  </g>
  <g fill="#c8702a" stroke="#7d3f10" stroke-width="1.2">
    <ellipse cx="42" cy="70" rx="8" ry="5.4" transform="rotate(-20 42 70)"/>
    <ellipse cx="60" cy="78" rx="8" ry="5.4" transform="rotate(15 60 78)"/>
    <ellipse cx="46" cy="90" rx="8" ry="5.4" transform="rotate(5 46 90)"/>
  </g>
  <path d="M36 72 q6 -1 11 -4 M54 79 q6 0 12 3 M40 90 q6 1 12 -1" stroke="#7d3f10" stroke-width="1" fill="none"/>
  <path d="M30 50 Q26 76 30 98" stroke="#ffffff" stroke-opacity="0.25" stroke-width="4" fill="none" stroke-linecap="round"/>
</svg>`,

        hay: `<svg viewBox="0 0 100 120" xmlns="http://www.w3.org/2000/svg">${defs}
  <g stroke="#4a2d14" stroke-width="3" stroke-linecap="round">
    <line x1="90" y1="8" x2="56" y2="66" stroke-width="9"/>
    <line x1="90" y1="8" x2="56" y2="66" stroke="#c6372a" stroke-width="5"/>
    <path d="M48 62 L64 72" stroke-width="5"/>
    <path d="M48 62 L64 72" stroke="#9aa2a8" stroke-width="2.6"/>
    <path d="M48 62 L38 82 M56 67 L46 87 M64 72 L54 92" stroke="#9aa2a8" stroke-width="2.8"/>
  </g>
  <path d="M6 110 Q10 76 34 64 Q56 52 76 68 Q96 82 94 110 Z" fill="#d8b467" stroke="#4a2d14" stroke-width="4" stroke-linejoin="round"/>
  <path d="M18 98 l10 -14 M30 102 l6 -20 M44 100 l2 -22 M58 102 l-2 -24 M72 100 l-6 -18 M84 102 l-8 -14 M38 78 l12 -6 M62 74 l10 4"
        stroke="#9c7633" stroke-width="2" stroke-linecap="round"/>
  <path d="M22 80 Q34 66 50 64" stroke="#f3dc9a" stroke-width="3" fill="none" stroke-linecap="round"/>
  <path d="M74 32 L84 16" stroke="#ffffff" stroke-opacity="0.5" stroke-width="1.6" stroke-linecap="round"/>
</svg>`,

        bucket: `<svg viewBox="0 0 100 120" xmlns="http://www.w3.org/2000/svg">${defs}
  <rect x="11" y="24" width="10" height="22" rx="2" fill="url(#rgStave)" stroke="#6b2c08" stroke-width="1.6"/>
  <rect x="79" y="24" width="10" height="22" rx="2" fill="url(#rgStave)" stroke="#6b2c08" stroke-width="1.6"/>
  <circle cx="16" cy="30" r="2" fill="#3b2410"/><circle cx="84" cy="30" r="2" fill="#3b2410"/>
  <path d="M16 42 L84 42 L75 108 Q50 114 25 108 Z" fill="url(#rgStave)" stroke="#6b2c08" stroke-width="2"/>
  <path d="M30 43 L33 110 M42 44 L43 112 M54 44 L54 112 M66 43 L64 111" stroke="#a54511" stroke-width="1.4"/>
  <path d="M18.6 56 L81.4 56 L80.4 63 L19.6 63 Z" fill="#33343a" stroke="#18181c" stroke-width="1"/>
  <path d="M22.6 90 L77.4 90 L76.4 97 L23.6 97 Z" fill="#33343a" stroke="#18181c" stroke-width="1"/>
  <circle cx="24" cy="59.5" r="1.3" fill="#9a9ca4"/><circle cx="76" cy="59.5" r="1.3" fill="#9a9ca4"/>
  <ellipse cx="50" cy="42" rx="34" ry="9.5" fill="#8a3a0d" stroke="#6b2c08" stroke-width="2"/>
  <ellipse cx="50" cy="42.5" rx="30" ry="7.4" fill="url(#rgWater)"/>
  <path d="M30 42 q5 -3 10 0 t10 0 M52 44 q5 -3 10 0 t8 0 M38 46 q4 -2 8 0" stroke="#d6f0ff" stroke-width="1.4" fill="none" stroke-linecap="round"/>
  <path d="M26 50 L30 104" stroke="#ffffff" stroke-opacity="0.35" stroke-width="3" stroke-linecap="round"/>
</svg>`,

        pails: `<svg viewBox="0 0 100 120" xmlns="http://www.w3.org/2000/svg">${defs}
  ${pail(28, 74, 0.82)}${pail(72, 74, 0.82)}${pail(50, 104, 1.0)}
</svg>`,

        basket: `<svg viewBox="0 0 100 120" xmlns="http://www.w3.org/2000/svg">${defs}
  <path d="M18 70 Q50 2 82 70" fill="none" stroke="#7a4c10" stroke-width="10" stroke-linecap="round"/>
  <path d="M18 70 Q50 2 82 70" fill="none" stroke="#e3ad42" stroke-width="6" stroke-linecap="round"/>
  <path d="M24 60 Q50 10 76 60" fill="none" stroke="#a9741c" stroke-width="1.2" stroke-dasharray="3 3"/>
  ${egg(34, 64, -18)}${egg(50, 60, 4)}${egg(66, 64, 16)}${egg(28, 70, -8)}${egg(44, 69, 10)}${egg(60, 70, -6)}
  <path d="M10 70 Q12 106 50 110 Q88 106 90 70 Z" fill="url(#rgWicker)" stroke="#7a4c10" stroke-width="2.2"/>
  <path d="M14 80 Q50 88 86 80 M16 90 Q50 98 84 90 M22 100 Q50 106 78 100" stroke="#9b6716" stroke-width="2" fill="none"/>
  <path d="M24 72 L22 106 M36 74 L34 109 M50 75 L50 110 M64 74 L66 109 M76 72 L78 106" stroke="#9b6716" stroke-width="1.6" fill="none"/>
  <ellipse cx="50" cy="70" rx="40" ry="6" fill="none" stroke="#7a4c10" stroke-width="5"/>
  <ellipse cx="50" cy="70" rx="40" ry="6" fill="none" stroke="#f0bf55" stroke-width="2.6"/>
  <path d="M18 80 Q22 96 34 104" stroke="#ffffff" stroke-opacity="0.35" stroke-width="3" fill="none" stroke-linecap="round"/>
</svg>`,
    };
}());
