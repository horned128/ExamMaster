// Reads the ipa web app's ES data files and prints them as one JSON object.
// Usage: node extract_ipa.js <ipa-dir>
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const root = process.argv[2];
if (!root) { console.error('usage: node extract_ipa.js <ipa-dir>'); process.exit(2); }

const questions = [];
const sandbox = {
  window: {},
  addQuestions(set, items) {
    items.forEach((q, i) => questions.push({ set, no: i + 1, ...q }));
  },
};
vm.createContext(sandbox);
for (let set = 1; set <= 12; set++) {
  vm.runInContext(fs.readFileSync(path.join(root, 'es', `part${set}.js`), 'utf8'), sandbox);
}
vm.runInContext(fs.readFileSync(path.join(root, 'common', 'glossary.js'), 'utf8'), sandbox);
vm.runInContext(fs.readFileSync(path.join(root, 'es', 'layers-data.js'), 'utf8'), sandbox);

const w = sandbox.window;
const chipIDs = [];
for (const row of w.LAYER_ROWS || []) {
  for (const key of Object.keys(row)) {
    if (Array.isArray(row[key])) row[key].forEach((t) => t && t.id && chipIDs.push(t.id));
  }
}
const layersSource = fs.readFileSync(path.join(root, 'es', 'layers-data.js'), 'utf8');
const sourceChipIDs = [...layersSource.matchAll(/^\s*\{\s*id:\s*'([^']+)'/gm)].map((m) => m[1]);
const journeyIDs = (w.JOURNEYS || []).map((j) => j.id).filter(Boolean);

// The 全体図 page draws timing charts with its own chart(); run it here to get the SVG.
const layersPage = fs.readFileSync(path.join(root, 'es', 'layers.html'), 'utf8');
const chartStart = layersPage.indexOf('var chartSeq = 0;');
const chartEnd = layersPage.indexOf('\n  var cur = ', chartStart);
const escSource = (layersPage.match(/function esc\(s\)[^\n]*/) || [''])[0];
if (chartStart < 0 || chartEnd < 0 || !escSource) { console.error('chart() not found in layers.html'); process.exit(1); }
vm.runInContext(escSource + '\n' + layersPage.slice(chartStart, chartEnd) + '\nthis.__chart = chart;', sandbox);
const journeys = (w.JOURNEYS || []).map((j) => ({
  ...j,
  phys: (j.phys || []).map((b) => (b.chart ? { chart: sandbox.__chart(b.chart), title: b.chart.title || '' } : b)),
}));

w.CHEATSHEET = [];
vm.runInContext(fs.readFileSync(path.join(root, 'es', 'cheatsheet.js'), 'utf8'), sandbox);

process.stdout.write(JSON.stringify({
  questions,
  glossary: w.GLOSSARY,
  chipIDs: [...new Set(chipIDs.concat(sourceChipIDs))],
  journeyIDs,
  layers: { zones: w.ZONES, rows: w.LAYER_ROWS, terms: w.TERMS, journeys },
  cheatsheet: w.CHEATSHEET,
}));
