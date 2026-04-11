const fs = require('fs');
const path = require('path');

const yamlPath = '/home/qwerty/.config/sovereign/models.yaml';
const raw = fs.readFileSync(yamlPath, 'utf8');

const __SOV_LOAD_MODELS = (raw) => {
    const models = {};
    const lines = raw.split('\n');
    let curr = null;
    for (const line of lines) {
      const t = line.trim();
      if (!t || t.startsWith('#')) continue;
      const am = line.match(/^\s*-\s*alias:\s*['"]?([^'"]+)['"]?/);
      if (am) {
        curr = { id: '', baseUrl: '', authEnv: '', isDefault: false };
        models[am[1].trim()] = curr;
        // console.log(`New Alias: ${am[1].trim()}`);
        continue;
      }
      if (!curr) continue;
      const kv = t.match(/^([^:]+):\s*(.*)$/);
      if (kv) {
        const k = kv[1].trim();
        let v = kv[2].split('#')[0].trim();
        if (v.startsWith('"') && v.endsWith('"')) v = v.slice(1, -1);
        if (v.startsWith("'") && v.endsWith("'")) v = v.slice(1, -1);
        if (k === 'id') curr.id = v;
        else if (k === 'default_base_url') curr.baseUrl = v;
        else if (k === 'auth_env') curr.authEnv = v;
        else if (k === 'default' && (v === 'true' || v === 'yes')) curr.isDefault = true;
      }
    }
    return models;
};

const models = __SOV_LOAD_MODELS(raw);
console.log('Final models Parsed:', Object.keys(models).length);
console.log(JSON.stringify(models, null, 2));

// Test with tricky YAML (comments, quotes, etc)
const trickyYaml = `
providers:
  - alias: "quoted-alias" # test comment
    id: 'quoted-id'
    default_base_url: https://api.test.com
    default: true
  - alias: unquoted
    id: raw-id
    auth_env: TEST_ENV
`;
const trickyModels = __SOV_LOAD_MODELS(trickyYaml);
console.log('\nTricky YAML Parsed:');
console.log(JSON.stringify(trickyModels, null, 2));
