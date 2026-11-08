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

process.stdout.write(JSON.stringify({
  questions,
  glossary: w.GLOSSARY,
  chipIDs: [...new Set(chipIDs.concat(sourceChipIDs))],
  journeyIDs,
}));
