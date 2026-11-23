// Fake Lua -> NUI messages to test without a backend (see ui/docs/NUI_CONTRACT.md).
// Each sendTest* pushes an { action, payload } envelope via window.postMessage,
// exactly as the Lua will. These payloads ARE the spec (see ui/docs/NUI_CONTRACT.md).
function send(action, payload) {
  window.postMessage({ action, payload }, '*');
}

// 8-slot wardrobe wheel. Icons = real RDR2 clothing icons (assets/icons).
const WARDROBE_8 = {
  menuId: 'wardrobe',
  title: 'Outfit',
  slots: [
    { id: 'hat', icon: 'hat', label: 'Hat' },
    { id: 'mask', icon: 'mask', label: 'Mask' },
    { id: 'gloves', icon: 'gloves', label: 'Gloves' },
    { id: 'shirt', icon: 'shirt', label: 'Shirt' },
    { id: 'vest', icon: 'vest', label: 'Vest' },
    { id: 'pants', icon: 'pants', label: 'Pants' },
    { id: 'boots', icon: 'boots', label: 'Boots' },
    { id: 'bandana', icon: 'bandana', label: 'Bandana' },
  ],
};

export function sendTestRadial8() { send('nui:radial:open', WARDROBE_8); }

export function sendTestRadial4() {
  send('nui:radial:open', {
    menuId: 'quickActions',
    title: 'Actions',
    slots: [
      { id: 'greet', icon: 'hat', label: 'Greet' },
      { id: 'sit', icon: 'boots', label: 'Sit' },
      { id: 'point', icon: 'gloves', label: 'Point' },
      { id: 'wave', icon: 'bandana', label: 'Wave' },
    ],
  });
}

export function sendTestRadial2() {
  send('nui:radial:open', {
    menuId: 'quick2',
    title: 'Choice',
    slots: [
      { id: 'yes', icon: 'hat', label: 'Yes' },
      { id: 'no', icon: 'mask', label: 'No' },
    ],
  });
}

export function sendTestRadial6() {
  send('nui:radial:open', {
    menuId: 'quick6',
    title: 'Wheel',
    slots: [
      { id: 'hat', icon: 'hat', label: 'Hat' },
      { id: 'mask', icon: 'mask', label: 'Mask' },
      { id: 'gloves', icon: 'gloves', label: 'Gloves' },
      { id: 'boots', icon: 'boots', label: 'Boots' },
      { id: 'pants', icon: 'pants', label: 'Pants' },
      { id: 'bandana', icon: 'bandana', label: 'Bandana' },
    ],
  });
}

export function sendTestRadialSubmenu() {
  send('nui:radial:open', {
    menuId: 'interactions',
    title: 'Interactions',
    slots: [
      {
        id: 'emotes', icon: 'hat', label: 'Emotes',
        children: [
          { id: 'wave', icon: 'bandana', label: 'Wave' },
          { id: 'dance', icon: 'boots', label: 'Dance' },
          { id: 'sit', icon: 'pants', label: 'Sit' },
        ],
      },
      { id: 'inventory', icon: 'vest', label: 'Inventory' },
      {
        id: 'door', icon: 'gloves', label: 'Door',
        children: [
          { id: 'lock', icon: 'mask', label: 'Lock' },
          { id: 'unlock', icon: 'shirt', label: 'Unlock' },
        ],
      },
      { id: 'cancel', icon: 'mask', label: 'Cancel' },
    ],
  });
}

export function sendTestRadialDisabled() {
  send('nui:radial:open', {
    menuId: 'shop',
    title: 'Shop',
    slots: [
      { id: 'buy', icon: 'hat', label: 'Buy' },
      { id: 'sell', icon: 'boots', label: 'Sell', disabled: true },
      { id: 'browse', icon: 'vest', label: 'Browse' },
    ],
  });
}

export function sendTestRadialClose() { send('nui:radial:close', {}); }

// Player picker (slots with target = 'cursor'): Lua opens it with the players
// in range, then streams their screen position every frame. Here three fake
// players drift around until the picker closes (select / cancel / Esc).
let pickerTimer = null;

function stopPickerDemo() {
  if (pickerTimer) { clearInterval(pickerTimer); pickerTimer = null; }
}

export function sendTestPicker() {
  stopPickerDemo();
  const base = [
    { serverId: 12, name: 'Arthur Morgan [12]', x: 0.38, y: 0.42 },
    { serverId: 27, name: 'Sadie Adler [27]', x: 0.61, y: 0.47 },
    { serverId: 3, name: 'Hosea Matthews [3]', x: 0.5, y: 0.3 },
  ];
  const frame = (t) => base.map((p, i) => ({
    ...p,
    x: p.x + Math.sin(t / 900 + i) * 0.02,
    y: p.y + Math.cos(t / 700 + i) * 0.012,
    visible: true,
  }));
  const start = Date.now();
  send('nui:picker:open', { players: frame(0) });
  // No Lua in dev to stop the stream on select / cancel: updates on a closed
  // picker are ignored by App, and the fake stream stops itself after 20 s.
  pickerTimer = setInterval(() => {
    const t = Date.now() - start;
    if (t > 20000) { stopPickerDemo(); return; }
    send('nui:picker:update', { players: frame(t) });
  }, 33);
}

export function sendTestPickerEmpty() {
  stopPickerDemo();
  send('nui:picker:open', { players: [] });
}
