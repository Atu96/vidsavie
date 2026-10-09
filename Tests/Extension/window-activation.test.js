const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = f => fs.readFileSync(path.join(__dirname, '../../Sources/VideoBatchDownloader', f), 'utf8');
test('working windows drive Dock presence without quitting background work', () => {
  const source = read('WindowActivationCoordinator.swift');
  for (const contract of ['.regular', '.accessory', 'willCloseNotification', 'didBecomeKeyNotification', 'window.isVisible || window.isMiniaturized', 'weak var window', 'entry.closed = true']) assert.ok(source.includes(contract), contract);
  assert.ok(!source.includes('terminate('));
  assert.ok(!source.includes('didResignKeyNotification'));
  for (const f of ['SettingsWindowView.swift','MediaToolViews.swift','SessionRepairView.swift','CompanionInstallGuideView.swift','FinderQuickActionGuideView.swift']) assert.ok(read(f).includes('WindowActivationCoordinator.shared'), f);
  assert.ok(read('QuitConfirmation.swift').includes('applicationShouldTerminateAfterLastWindowClosed'));
});
