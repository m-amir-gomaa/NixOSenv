const fs = require('fs');
const path = require('path');

const yamlPath = '/home/qwerty/.config/sovereign/models.yaml';
const raw = fs.readFileSync(yamlPath, 'utf8');

const __SOV_LOAD_MODELS = (raw) => {
  const models = {};
  const chunks = raw.split(/\n\s*-\s*alias:/);
  console.log(`Chunks count: ${chunks.length}`);
  for (const p of chunks.slice(1)) {
    const alias = p.split('\n')[0].trim();
    const id = (p.match(/id:\s*(\S+)/) || [])[1];
    const baseUrl = (p.match(/default_base_url:\s*(\S+)/) || [])[1];
    const authEnv = (p.match(/auth_env:\s*(\S+)/) || [])[1];
    if (alias && id) {
        models[alias] = { id, baseUrl, authEnv, isDefault: p.includes('default: true') };
        console.log(`Loaded: ${alias} -> ${id}`);
    } else {
        console.log(`Failed to load chunk starting with: ${p.slice(0, 20)}...`);
    }
  }
  return models;
};

const models = __SOV_LOAD_MODELS(raw);
console.log('Final models:', models);
