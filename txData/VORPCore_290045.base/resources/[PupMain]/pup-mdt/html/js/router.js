'use strict';
// Messages from the client, and the ESC / Backspace keys.

const Handlers = {
    setLocale: (m) => { I18N.strings = (m.strings && typeof m.strings === 'object') ? m.strings : {}; },
    openMDT: (m) => {
        if (Pub.kiosk) App.kioskClose(false);
        App.openMDT({ playerData: m.playerData, config: m.config, isLawyer: m.isLawyer });
    },
    closeNUI: () => App.close(false),
    escPressed: (m) => {
        // the page sees ESC itself too; skip the client's echo of a key it already handled
        if (m && Date.now() - (App.escConsumedAt || 0) < 400) return;
        if (Pub.bh) { if (!closeTopLayer()) App.bhClose(true); return; }
        if (Pub.jr) { App.jrClose(true); return; }
        if (Pub.kiosk && !App.open) { if (!closeTopLayer()) App.kioskClose(true); return; }
        App.handleEsc();
    },
    mdtToast: (m) => App.slip(m.message, m.duration),
    receivePlayerData: (m) => { if (m.playerData) App.setPlayer(m.playerData, false); },
    updateSettings: (m) => { if (m.settings) { App.settings = m.settings; if (App.player) App.player.settings = m.settings; if (App.open) App.recheckTabs(); } },
    updateDashboard: (m) => { const t = App.tabs.dashboard; if (m.data && t.push) t.push(m.data); else if (App.current === 'dashboard') t.show(); },
    updateCriminals: () => App.tabs.citizens.push(),
    lawmanStatusChanged: () => App.tabs.roster.push(),
    updateOnlineLawmen: () => App.tabs.roster.push(),
    refreshLawmenList: () => App.tabs.roster.push(),
    updatePrisons: () => App.tabs.prisons.push(),
    updateBail: () => App.tabs.bail.push(),
    updateAppeals: () => App.tabs.appeals.push(),
    updateExpungements: () => App.tabs.expungements.push(),
    updateDefenseCases: () => App.tabs.defense.push(),
    updateTips: () => App.tabs.tips.push(),
    newTip: (m) => App.tabs.tips.newTip(m.tip),
    updatePoliceAlerts: (m) => App.setAlerts(arr(m.alerts)),
    removeAlert: (m) => App.removeAlert(m.alertId),
    clearAllAlerts: () => App.setAlerts([]),
    updateAlertResponses: (m) => App.setAlertResponders(m),
    updateAlertLock: (m) => App.setAlertLock(m),
    updateJailTime: (m) => App.jailTime(m.jailTime),
    clearJailTime: () => App.jailClear(),
    openJailRegister: (m) => App.jrOpen(m),
    closeJailRegister: () => App.jrClose(false),
    openCivilianRecord: (m) => App.kioskOpen(m),
    closeCivilianRecord: () => App.kioskClose(false),
    openBountyHunterBoard: (m) => App.bhOpen(m),
    closeBountyHunterBoard: () => App.bhClose(false),
    bountyTipResult: (m) => App.bhTipResult(m),
    bountyClaimed: (m) => App.bhRemove(m.id),
};

window.addEventListener('message', (e) => {
    const m = e.data;
    if (!m || typeof m !== 'object') return;
    if (resolveWaiter(m)) return;
    const kind = m.action || m.type;
    const fn = Handlers[kind];
    if (!fn) return;
    try { fn(m); } catch (err) { if (App.cfg && App.cfg.nuiDebug) console.log('[pup-mdt] ' + kind + ': ' + err.message); }
});

function inTextField(t) {
    if (!t) return false;
    const tag = t.tagName;
    return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || t.isContentEditable;
}
document.addEventListener('keydown', (e) => {
    const anyOpen = App.open || Pub.kiosk || Pub.bh || Pub.jr;
    if (!anyOpen) return;
    if (e.key === 'Escape') {
        if (e.defaultPrevented) return;
        e.preventDefault();
        Handlers.escPressed();
        App.escConsumedAt = Date.now();
    } else if (e.key === 'Backspace' && !inTextField(e.target)) {
        e.preventDefault();
        Handlers.escPressed();
        App.escConsumedAt = Date.now();
    }
});
