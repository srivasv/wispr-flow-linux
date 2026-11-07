#!/usr/bin/env bats

@test "version tracker: issue reporting skips disabled issues and handles enabled issues" {
	command -v node >/dev/null || skip 'node not installed'
	node - "$BATS_TEST_DIRNAME/../.github/workflows/check-wispr-version.yml" <<'JS'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const AsyncFunction = Object.getPrototypeOf(async () => {}).constructor;
const workflow = fs.readFileSync(process.argv[2], 'utf8');
const scripts = [...workflow.matchAll(/          script: \|\n((?:            .*\n|\n)+)/g)]
	.map(m => m[1].replace(/^            /gm, ''));
assert.equal(scripts.length, 2);
(async () => {
	for (const hasIssues of [false, true]) {
		for (const [index, script] of scripts.entries()) {
			const calls = [];
			const github = {rest: {
				repos: {get: async () => ({data: {has_issues: hasIssues}})},
				issues: Object.fromEntries(['listForRepo', 'create', 'createComment', 'update']
					.map(name => [name, async () => {
						assert.ok(hasIssues, 'must not access issues when disabled');
						calls.push(name);
						return {data: index ? [{number: 156}] : []};
					}]))
			}};
			const context = {repo: {owner: 'test', repo: 'test'},
				serverUrl: 'https://github.com', runId: 1};
			await new AsyncFunction('github', 'context', 'core', script)(
				github, context, {notice() {}});
			assert.deepEqual(calls, !hasIssues ? [] : index
				? ['listForRepo', 'createComment', 'update']
				: ['listForRepo', 'create']);
		}
	}
})().catch(error => { console.error(error); process.exitCode = 1; });
JS
}
