/* Copyright (c) 2026 kewe87. Licensed under LGPL-2.1-or-later. */
// MKV Dolby Vision Patcher – Homebrew Channel app. All work is done by payload/ctl.sh,
// which runs as root through the Homebrew Channel's exec service.
'use strict';

var EXEC = 'luna://org.webosbrew.hbchannel.service/exec';
var APP_DIR = location.pathname.replace(/\/[^/]*$/, '');
var CTL = 'sh ' + APP_DIR + '/payload/ctl.sh';

var TEXT = {
  en: {
    subtitle: 'Patch for the webOS 22 system player (GStreamer)',
    intro: 'Makes MKV files play in real Dolby Vision instead of HDR10 – in every app (Emby, Plex, media ' +
      'player, USB, DLNA). Your files are not changed: the patcher puts an improved MKV demuxer over the one ' +
      'in LG\'s system player at startup, in RAM only; the firmware stays untouched. ' +
      'Requires a rooted TV with the Homebrew Channel.',
    footer: '© 2026 kewe87 · LGPL-2.1-or-later · Use at your own risk, no warranty · ' +
      'github.com/kewe87/webos22-mkv-dolbyvision',
    disclaimer: 'Disclaimer: this patcher changes how your TV\'s system player plays videos. It is an ' +
      'unofficial community project, not affiliated with LG or Dolby, and comes without any warranty. You use ' +
      'it at your own risk – no liability is accepted for damage to the device, data loss or loss of warranty.',
    accept: 'I understand',
    quit: 'Exit',
    retry: 'Check again',
    dRoot: 'Root',
    rootOk: 'ok',
    loading: 'Reading status…',
    noRoot: 'Root service not reachable',
    noRootText: 'This app needs a rooted TV with the Homebrew Channel ("Root status: ok" in its settings). ' +
      'Without root nothing can be changed.',
    active: 'Active',
    activeText: 'Dolby Vision from MKV is on and starts automatically with the TV. This app is no longer ' +
      'needed for that: it can be uninstalled, the patch stays active.',
    off: 'Off',
    offText: 'LG\'s original demuxer is used. MKV files play Dolby Vision as HDR10.',
    rebootOn: 'Restart required',
    rebootOnText: 'The new version becomes active after a TV restart (a video was playing).',
    rebootOff: 'Restart required',
    rebootOffText: 'Switched off. LG\'s original is back after a TV restart (a video was playing).',
    notActivated: 'Not activated',
    unknownText: 'This TV\'s LG demuxer has not been tested with this build. Run the check, then switch on.',
    failedText: 'Switched on, but the boot script did not activate it: ',
    update: 'Update ready',
    updateText: 'The app contains a newer build than the one installed.',
    enable: 'Switch on',
    disable: 'Switch off',
    install: 'Install update',
    p7on: 'Profile 7 → 8.1: on',
    p7off: 'Profile 7 → 8.1: off',
    check: 'Run compatibility check',
    showLog: 'Show log',
    hideLog: 'Hide log',
    reboot: 'Restart TV',
    uninstall: 'Remove everything',
    yes: 'Yes',
    no: 'Cancel',
    confirmForce: 'This TV\'s LG demuxer is not on the tested list. The check loaded the build without errors. Switch on anyway? You can switch off again at any time.',
    confirmReboot: 'Restart the TV now?',
    confirmUninstall: 'Switch off and delete all installed files?',
    checkOk: 'Check passed: the build loads on this TV.',
    checkFailed: 'Check failed – the build does not load on this TV. Do not switch on.',
    p7Later: 'Takes effect from the next video on.',
    working: 'Please wait…',
    error: 'Error: ',
    dState: 'Running build',
    dInstalled: 'Installed build',
    dApp: 'Build in this app',
    dOriginal: 'LG original',
    dKnown: { official: 'tested', local: 'accepted on this TV', unknown: 'not tested' },
    dSystem: 'webOS / GStreamer',
    dBoot: 'Boot script',
    none: '–'
  },
  de: {
    subtitle: 'Patch für den Systemplayer von webOS 22 (GStreamer)',
    intro: 'Lässt MKV-Dateien in echtem Dolby Vision statt HDR10 laufen – in allen Apps (Emby, Plex, ' +
      'Mediaplayer, USB, DLNA). Deine Dateien werden nicht verändert: Der Patcher legt beim Start einen ' +
      'verbesserten MKV-Baustein über den in LGs Systemplayer, nur im Arbeitsspeicher; die Firmware bleibt ' +
      'unverändert. Benötigt einen gerooteten TV mit Homebrew Channel.',
    footer: '© 2026 kewe87 · LGPL-2.1-or-later · Nutzung auf eigene Gefahr, ohne Gewähr · ' +
      'github.com/kewe87/webos22-mkv-dolbyvision',
    disclaimer: 'Haftungsausschluss: Dieser Patcher verändert, wie der Systemplayer deines TVs Videos abspielt. ' +
      'Er ist ein inoffizielles Community-Projekt, nicht von LG oder Dolby, und wird ohne jede Gewähr ' +
      'bereitgestellt. Die Nutzung erfolgt auf eigene Gefahr – für Schäden am Gerät, Datenverlust oder den ' +
      'Verlust der Garantie wird keine Haftung übernommen.',
    accept: 'Verstanden',
    quit: 'Beenden',
    retry: 'Erneut prüfen',
    dRoot: 'Root',
    rootOk: 'ok',
    loading: 'Status wird gelesen…',
    noRoot: 'Root-Dienst nicht erreichbar',
    noRootText: 'Die App braucht einen gerooteten TV mit Homebrew Channel (in dessen Einstellungen ' +
      '„Root status: ok“). Ohne Root lässt sich nichts verändern.',
    active: 'Aktiv',
    activeText: 'Dolby Vision aus MKV ist an und startet automatisch mit dem TV. Dafür wird diese App nicht ' +
      'mehr gebraucht: Sie kann deinstalliert werden, der Patch bleibt aktiv.',
    off: 'Aus',
    offText: 'LGs Original wird verwendet. MKV-Dateien laufen mit Dolby Vision nur als HDR10.',
    rebootOn: 'Neustart nötig',
    rebootOnText: 'Die neue Version wird nach einem Neustart des TVs aktiv (es lief gerade ein Video).',
    rebootOff: 'Neustart nötig',
    rebootOffText: 'Abgeschaltet. LGs Original ist nach einem Neustart des TVs zurück (es lief gerade ein Video).',
    notActivated: 'Nicht aktiv',
    unknownText: 'Der MKV-Baustein dieses TVs ist mit diesem Build nicht getestet. Erst prüfen, dann einschalten.',
    failedText: 'Eingeschaltet, aber das Boot-Skript hat nicht aktiviert: ',
    update: 'Update bereit',
    updateText: 'Die App enthält einen neueren Build als den installierten.',
    enable: 'Einschalten',
    disable: 'Ausschalten',
    install: 'Update installieren',
    p7on: 'Profil 7 → 8.1: an',
    p7off: 'Profil 7 → 8.1: aus',
    check: 'Verträglichkeit prüfen',
    showLog: 'Protokoll anzeigen',
    hideLog: 'Protokoll ausblenden',
    reboot: 'TV neu starten',
    uninstall: 'Alles entfernen',
    yes: 'Ja',
    no: 'Abbrechen',
    confirmForce: 'Der MKV-Baustein dieses TVs steht nicht auf der getesteten Liste. Die Prüfung hat den Build fehlerfrei geladen. Trotzdem einschalten? Ausschalten geht jederzeit.',
    confirmReboot: 'TV jetzt neu starten?',
    confirmUninstall: 'Ausschalten und alle installierten Dateien löschen?',
    checkOk: 'Prüfung bestanden: Der Build lässt sich auf diesem TV laden.',
    checkFailed: 'Prüfung fehlgeschlagen – der Build lädt auf diesem TV nicht. Bitte nicht einschalten.',
    p7Later: 'Gilt ab dem nächsten Video.',
    working: 'Bitte warten…',
    error: 'Fehler: ',
    dState: 'Laufender Build',
    dInstalled: 'Installierter Build',
    dApp: 'Build in dieser App',
    dOriginal: 'LG-Original',
    dKnown: { official: 'getestet', local: 'auf diesem TV freigegeben', unknown: 'nicht getestet' },
    dSystem: 'webOS / GStreamer',
    dBoot: 'Boot-Skript',
    none: '–'
  }
};
// launch parameters, used for the README screenshots: {"lang": "en", "show": "status" | "disclaimer" | "log"}
var LP = {};
try { LP = JSON.parse((window.PalmSystem && PalmSystem.launchParams) || '{}') || {}; } catch (e) { LP = {}; }
var T = TEXT[LP.lang] || TEXT[(navigator.language || 'en').slice(0, 2)] || TEXT.en;

var $ = function (id) { return document.getElementById(id); };
var tvState = null; // not "status": that is window.status, a string
var busy = false;
var rooted = false;
var bridges = [];

// ---- luna / ctl.sh ----------------------------------------------------------

function luna(uri, params) {
  return new Promise(function (resolve, reject) {
    var bridge = new PalmServiceBridge();
    bridges.push(bridge); // keep a reference until the callback has run
    bridge.onservicecallback = function (msg) {
      bridges.splice(bridges.indexOf(bridge), 1);
      var res;
      try { res = JSON.parse(msg); } catch (e) { reject(new Error(msg)); return; }
      if (res.returnValue === false) reject(new Error(res.errorText || msg));
      else resolve(res);
    };
    bridge.call(uri, JSON.stringify(params));
  });
}

function sh(command) {
  return luna(EXEC, { command: command }).then(function (r) { return r.stdoutString || ''; });
}

function ctl(args) {
  return sh(CTL + ' ' + args).then(function (out) {
    var res = JSON.parse(out.trim().split('\n').pop());
    if (!res.ok) {
      var err = new Error(res.error + (res.detail ? ': ' + res.detail : ''));
      err.code = res.error;
      throw err;
    }
    return res;
  });
}

// ---- UI ---------------------------------------------------------------------

function setState(cls, title, text) {
  $('state').className = 'card ' + cls;
  $('state-title').textContent = title;
  $('state-text').textContent = text;
}

function message(text) {
  $('message').textContent = text || '';
  $('message').hidden = !text;
}

function short(md5) { return md5 ? md5.slice(0, 12) + '…' : T.none; }

function render() {
  var s = tvState;
  $('version').textContent = s.version ? 'v' + s.version : '';

  var wanted = s.linked && !s.disabledFlag;
  var stale = s.active && s.runningMd5 && s.runningMd5 !== s.installedMd5;
  if (s.active && !wanted) setState('warn', T.rebootOff, T.rebootOffText);
  else if (stale) setState('warn', T.rebootOn, T.rebootOnText);
  else if (s.active && s.updateAvailable) setState('warn', T.update, T.updateText);
  else if (s.active) setState('ok', T.active, T.activeText);
  else if (s.originalKnown === 'unknown') setState('bad', T.notActivated, T.unknownText);
  else if (wanted) setState('bad', T.notActivated, T.failedText + s.autostartLog);
  else setState('', T.off, T.offText);

  var buttons = [];
  if (s.active && wanted) {
    if (s.updateAvailable) buttons.push([T.install, enable]);
    buttons.push([T.disable, disable]);
  } else {
    buttons.push([T.enable, enable]);
  }
  if (s.installed) buttons.push([s.p7 ? T.p7on : T.p7off, toggleP7]);
  buttons.push([T.check, check]);
  buttons.push([$('log').hidden ? T.showLog : T.hideLog, toggleLog]);
  if ((s.active && !wanted) || stale) buttons.push([T.reboot, reboot]);
  if (s.installed) buttons.push([T.uninstall, uninstall, 'danger']);

  var focused = document.activeElement && document.activeElement.dataset.idx;
  var box = $('actions');
  box.innerHTML = '';
  buttons.forEach(function (b, i) {
    var el = document.createElement('button');
    el.textContent = b[0];
    el.dataset.idx = i;
    if (b[2]) el.className = b[2];
    el.addEventListener('click', function () { run(b[1]); });
    box.appendChild(el);
  });
  var target = box.children[Math.min(focused || 0, box.children.length - 1)];
  if ($('dialog').hidden && target) target.focus();

  var known = T.dKnown[s.originalKnown] || s.originalKnown;
  var rows = [
    [T.dRoot, T.rootOk],
    [T.dState, short(s.runningMd5), true],
    [T.dInstalled, short(s.installedMd5) + (s.installedVersion ? ' (v' + s.installedVersion + ')' : ''), true],
    [T.dApp, short(s.bundledMd5) + (s.version ? ' (v' + s.version + ')' : ''), true],
    [T.dOriginal, short(s.original) + ' – ' + known, true],
    // libgstreamer-1.0.so.0.1802.0 -> 1.18.2
    [T.dSystem, (s.webosRelease || '?') + ' / ' +
      (s.gstreamer || '?').replace(/^(\d+)(\d\d)\.\d+$/, function (m, a, b) { return '1.' + a + '.' + Number(b); })],
    [T.dBoot, s.autostartLog || T.none]
  ];
  $('details').innerHTML = '';
  rows.forEach(function (r) {
    var tr = document.createElement('tr');
    var a = document.createElement('td');
    var b = document.createElement('td');
    a.textContent = r[0];
    b.textContent = r[1];
    if (r[2]) b.className = 'mono';
    tr.appendChild(a);
    tr.appendChild(b);
    $('details').appendChild(tr);
  });
}

function confirmDialog(text, yesLabel, noLabel) {
  return new Promise(function (resolve) {
    var prev = document.activeElement;
    $('dialog-text').textContent = text;
    $('dialog-yes').textContent = yesLabel || T.yes;
    $('dialog-no').textContent = noLabel || T.no;
    $('dialog').hidden = false;
    (yesLabel ? $('dialog-yes') : $('dialog-no')).focus();
    function done(answer) {
      $('dialog').hidden = true;
      $('dialog-yes').onclick = $('dialog-no').onclick = null;
      closeDialog = null;
      if (prev) prev.focus();
      resolve(answer);
    }
    $('dialog-yes').onclick = function () { done(true); };
    $('dialog-no').onclick = function () { done(false); };
    closeDialog = function () { done(false); };
  });
}
var closeDialog = null;

// ---- actions ----------------------------------------------------------------

// Nothing can be changed unless the Homebrew Channel's exec service really runs as root;
// ctl.sh refuses to work without root as well.
function refresh() {
  return sh('id -u').catch(function () { return ''; }).then(function (uid) {
    rooted = uid.trim() === '0';
    if (!rooted) { noRoot(); return; }
    return ctl('status').then(function (s) { tvState = s; render(); });
  });
}

function noRoot() {
  tvState = null;
  setState('bad', T.noRoot, T.noRootText);
  $('details').innerHTML = '';
  var box = $('actions');
  box.innerHTML = '';
  var el = document.createElement('button');
  el.textContent = T.retry;
  el.addEventListener('click', function () { run(null); });
  box.appendChild(el);
  if ($('dialog').hidden) el.focus();
}

function run(action) {
  if (busy) return;
  if (!rooted) action = null; // without root only "check again" works
  busy = true;
  message(T.working);
  Promise.resolve()
    .then(action || undefined)
    .then(function (msg) { message(msg || ''); })
    .catch(function (e) { message(T.error + e.message); })
    .then(refresh)
    .catch(function (e) { message(T.error + e.message); })
    .then(function () { busy = false; });
}

function enable() {
  return ctl('enable').catch(function (e) {
    if (e.code !== 'unknown-original') throw e;
    return ctl('check')
      .catch(function () { throw new Error(T.checkFailed); })
      .then(function () { message(''); return confirmDialog(T.confirmForce); })
      .then(function (yes) { if (yes) return ctl('enable --force'); });
  }).then(function (r) {
    return r && r.result === 'reboot-required' ? T.rebootOnText : '';
  });
}

function disable() {
  return ctl('disable').then(function (r) {
    return r.result === 'reboot-required' ? T.rebootOffText : '';
  });
}

function toggleP7() {
  return ctl('p7 ' + (tvState.p7 ? 'off' : 'on')).then(function () { return T.p7Later; });
}

function check() {
  return ctl('check').then(function () { return T.checkOk; }, function () { return T.checkFailed; });
}

function toggleLog() {
  if (!$('log').hidden) { showLog(false); return; }
  return sh(CTL + ' log').then(function (out) {
    $('log').textContent = out;
    showLog(true);
  });
}

// the log takes the place of the details table
function showLog(on) {
  $('log').hidden = !on;
  $('details').hidden = on;
}

function reboot() {
  return confirmDialog(T.confirmReboot).then(function (yes) {
    if (yes) return sh('reboot');
  });
}

function uninstall() {
  return confirmDialog(T.confirmUninstall).then(function (yes) {
    if (!yes) return;
    return ctl('uninstall').then(function (r) {
      return r.result === 'reboot-required' ? T.rebootOffText : '';
    });
  });
}

// ---- remote control ---------------------------------------------------------

document.addEventListener('keydown', function (e) {
  var key = e.keyCode;
  if (key === 461 || key === 8) { // Back
    e.preventDefault();
    if (closeDialog) closeDialog();
    else if (!$('log').hidden) { showLog(false); if (tvState) render(); }
    else window.close();
    return;
  }
  var dir = { 37: -1, 38: -1, 39: 1, 40: 1 }[key];
  if (!dir) return;
  e.preventDefault();
  var list = closeDialog
    ? [$('dialog-yes'), $('dialog-no')]
    : Array.prototype.slice.call($('actions').children);
  var i = list.indexOf(document.activeElement);
  var next = list[Math.max(0, Math.min(list.length - 1, i + dir))];
  if (next) next.focus();
});

document.addEventListener('webOSRelaunch', function () { run(function () {}); });
document.addEventListener('visibilitychange', function () {
  if (!document.hidden && !busy) refresh().catch(function () {});
});

// first start: the disclaimer has to be accepted before anything else
function disclaimer() {
  var accepted = false;
  try { accepted = localStorage.getItem('mkvdv.disclaimer') === '1'; } catch (e) { /* no storage */ }
  if (LP.show === 'status' || LP.show === 'log') accepted = true; // screenshots only
  if (accepted && LP.show !== 'disclaimer') return Promise.resolve();
  return confirmDialog(T.disclaimer, T.accept, T.quit).then(function (yes) {
    if (!yes) { window.close(); throw new Error('declined'); }
    try { localStorage.setItem('mkvdv.disclaimer', '1'); } catch (e) { /* no storage */ }
  });
}

$('subtitle').textContent = T.subtitle;
$('intro').textContent = T.intro;
$('footer').textContent = T.footer;
setState('', T.loading, '');
busy = true;
refresh()
  .catch(function (e) { noRoot(); message(T.error + e.message); })
  .then(function () { busy = false; return disclaimer(); })
  .then(function () { if (LP.show === 'log' && rooted) run(toggleLog); })
  .catch(function () {});
