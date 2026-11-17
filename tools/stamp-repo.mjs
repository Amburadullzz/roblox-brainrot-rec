// Stamps the repository's own name into the README's make.fun badges.
//
//   node tools/stamp-repo.mjs <owner> <repo>
//
// The bounty wants three live make.fun badges in the README GitHub shows at the submitted commit, the
// rank and reward ones carrying the repository's own owner and name, and no template placeholder left in
// any of them. The README ships with OWNER/REPO in those two URLs; this fills them in, and sets the
// GitHub About (a website on make.fun and the topic makefun) with the gh CLI when it is installed.

import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const [owner, repo] = process.argv.slice(2);
if (!owner || !repo) {
  console.error('usage: node tools/stamp-repo.mjs <owner> <repo>');
  process.exit(1);
}
if (!/^[A-Za-z0-9_.-]+$/.test(owner) || !/^[A-Za-z0-9_.-]+$/.test(repo)) {
  console.error('owner and repo are GitHub names: letters, digits, . _ -');
  process.exit(1);
}

const path = join(root, 'README.md');
const before = readFileSync(path, 'utf8');
const after = before.split('roblox-brainrot-01/OWNER/REPO/').join(`roblox-brainrot-01/${owner}/${repo}/`);
if (after === before) {
  console.log('README.md already stamped: nothing to change');
} else {
  writeFileSync(path, after);
  console.log(`README.md: badges now name ${owner}/${repo}`);
}
if (after.includes('OWNER/REPO')) {
  console.error('README.md still holds OWNER/REPO: the badges would fail the repo_readme check');
  process.exit(1);
}

// The About: a website on make.fun, and the makefun topic. gh writes both.
const site = `https://make.fun/bounty/roblox-brainrot-01`;
try {
  execFileSync('gh', ['repo', 'edit', `${owner}/${repo}`, '--homepage', site, '--add-topic', 'makefun'], { stdio: 'inherit' });
} catch {
  console.error(`gh is not available or refused: set ${owner}/${repo}'s About by hand to ${site} with topic makefun`);
}
