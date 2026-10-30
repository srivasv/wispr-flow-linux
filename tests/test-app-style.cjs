#!/usr/bin/env node
// Exercise the shipped app classifier without starting Electron or changing prefs.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

if (process.argv.length !== 3) {
	throw new Error('Usage: node tests/test-app-style.cjs <main/index.js>');
}
const source = fs.readFileSync(process.argv[2], 'utf8');
const modules = [...source.matchAll(/(?:^|,)(\d+)\(([\w$]+),([\w$]+),([\w$]+)\)\{/g)];
const candidates = modules.flatMap((match, i) => {
	const start = match.index + (source[match.index] === ',' ? 1 : 0);
	const end = modules[i + 1]?.index ?? source.length;
	const body = source.slice(start, end);
	return body.includes('getAppType:()=>') ? [body] : [];
});
assert.equal(candidates.length, 1, 'expected one exported app classifier');
const factory = candidates[0].replace(/^\d+\(/, 'function(');

for (const isMac of [false, true]) {
	const state = {manuallySetAppType: null};
	const types = {AI: 'ai', Other: 'other', Email: 'email'};
	const dependencies = {
		tD: isMac, RA: state, uC: types, Yt: types, pb: [], C0: () => false,
	};
	const requireModule = () => dependencies;
	requireModule.r = () => {};
	requireModule.d = (target, getters) => {
		for (const [key, get] of Object.entries(getters)) {
			Object.defineProperty(target, key, {get});
		}
	};
	const exported = {};
	vm.runInNewContext(`(${factory})`, {}, {timeout: 1000})(
		{}, exported, requireModule,
	);
	const ids = isMac
		? ['com.microsoft.VSCode', 'com.todesktop.230313mzl4w4u92']
		: ['Code', 'Cursor', 'code.desktop', 'cursor.desktop'];
	for (const id of ids) {
		assert.equal(exported.getAppType(id, ''), 'ai', id);
	}
	assert.equal(exported.getAppType('', ''), 'other');
	assert.equal(exported.getAppType('unknown-window', ''), 'other');
	assert.equal(exported.getAppType('', 'mail.google.com'), 'email');
	if (!isMac) {
		// Test the shipped personalization mapper, not a copy of its rules.
		const mappings = [...source.matchAll(
			/[\w$]+=\(([\w$]+),([\w$]+),([\w$]+)\)=>([^;]+?\.U2\.OTHER)(?=,)/g,
		)].filter(match => match[4].includes('.WORK_MESSAGING_APPS'));
		assert.equal(mappings.length, 1, 'expected one personalization mapper');
		const [, first, second, third, body] = mappings[0];
		const context = {};
		for (const [, name] of body.matchAll(/([\w$]+)\./g)) {
			context[name] = {
				WORK_MESSAGING_APPS: exported.WORK_MESSAGING_APPS,
				isMessagingApp: exported.isMessagingApp, uC: types,
				U2: {EMAIL: 'email', WORK: 'work', PERSONAL: 'personal', OTHER: 'other'},
			};
		}
		const style = vm.runInNewContext(
			`((${first},${second},${third})=>${body})`, context,
		);
		// Run the actual My Voice selector and its app-name/default-voice modules.
		const bodies = new Map(modules.map((match, i) => {
			const start = match.index + (source[match.index] === ',' ? 1 : 0);
			return [Number(match[1]), source.slice(start, modules[i + 1]?.index ?? source.length)];
		}));
		const voiceEntries = [...bodies].filter(([, text]) =>
			text.includes('matchedVoiceType:') && text.includes('.personalizationStyleSettings='));
		assert.equal(voiceEntries.length, 1);
		const [voiceId, voiceBody] = voiceEntries[0];
		const imports = new Map([...voiceBody.matchAll(/([\w$]+)=n\((\d+)\)/g)]
			.map(([, alias, id]) => [alias, Number(id)]));
		const dependency = re => imports.get(voiceBody.match(re)?.[1]);
		for (const platform of ['linux', 'win32', 'darwin']) {
			const prefs = {user: {}};
			const appState = {prefs, persistentAppContext: {}};
			const mocks = new Map([
				[dependency(/([\w$]+)\.RA/), {RA: appState}],
				[dependency(/([\w$]+)\.ZZ/), {ZZ: {}, A0: style}],
				[dependency(/([\w$]+)\.getAppType/), exported],
				[dependency(/([\w$]+)\.Cg/), {Cg: value => value}],
				[dependency(/([\w$]+)\.G1/), {G1: 'default'}],
				[dependency(/([\w$]+)\.wX/), {wX: () => true}],
				[dependency(/([\w$]+)\.TOI/), {TOI: {MyVoice: 'my-voice'}}], // codespell:ignore toi
			]);
			assert(!mocks.has(undefined), 'selector imports changed');
			const cache = new Map(mocks);
			function load(id) {
				if (cache.has(id)) return cache.get(id);
				assert(bodies.has(id), `missing bundled module ${id}`);
				const result = {};
				cache.set(id, result);
				const code = bodies.get(id).replace(/^\d+\(/, 'function(');
				vm.runInNewContext(`(${code})`, {process: {platform}, URL})(
					{}, result, load);
				return result;
			}
			load.d = requireModule.d;
			load.r = requireModule.r;
			const selector = load(voiceId);
			const select = Object.entries(Object.getOwnPropertyDescriptors(selector))
				.map(([, desc]) => desc.get()).find(fn =>
					typeof fn === 'function' && fn.toString().includes('matchedVoiceType:'));
			assert(select, 'My Voice selector export missing');
			for (const [id, url, expected] of [
				['Telegram', '', 'personal'], ['thunderbird', '', 'email'],
				['com.google.Chrome', 'linkedin.com', 'work'],
				['com.google.Chrome', 'web.telegram.org', 'personal'],
			]) {
				appState.persistentAppContext = {lastAppName: id, lastAppBundleID: id, lastAppURL: url};
				assert.equal(select().matchedVoiceType, platform === 'linux' ? expected : 'other',
					`${platform} My Voice ${id}/${url}`);
			}
			for (const [id, url, expected] of [
				['Slack', '', 'work'], ['WhatsApp', '', 'personal'],
				['com.google.Chrome', 'mail.google.com', 'email'],
				['com.google.Chrome', 'app.slack.com', 'work'],
				['com.google.Chrome', 'web.whatsapp.com', 'personal'],
				['com.google.Chrome', '', 'other'], ['unknown-app', '', 'other'],
			]) {
				appState.persistentAppContext = {lastAppName: id, lastAppBundleID: id, lastAppURL: url};
				assert.equal(select().matchedVoiceType, expected);
			}
			prefs.user.userVoices = {custom: {id: 'custom', appNames: ['Telegram'], stylePreference: 'casual'}};
			appState.persistentAppContext = {lastAppName: 'Telegram', lastAppBundleID: 'Telegram', lastAppURL: ''};
			assert.equal(select().matchedVoiceType, 'custom', 'explicit user assignment wins');
			appState.persistentAppContext = {lastAppName: 'Chrome', lastAppBundleID: 'com.google.Chrome', lastAppURL: 'web.telegram.org'};
			assert.equal(select().matchedVoiceType, 'custom', 'explicit website assignment wins');
		}
		const cases = [
			['Slack', '', 'work'], ['com.slack.Slack.desktop', '', 'work'],
			['teams-for-linux', '', 'work'], ['msteams', '', 'work'],
			['WhatsApp', '', 'personal'], ['TelegramDesktop', '', 'personal'],
			['org.telegram.desktop', '', 'other'],
			['thunderbird', '', 'email'], ['org.mozilla.Thunderbird.desktop', '', 'other'],
			['firefox', '', 'other'], ['google-chrome', '', 'other'],
			['firefox', 'mail.google.com', 'email'],
			['firefox', 'app.slack.com', 'work'],
			['firefox', 'linkedin.com', 'work'],
			['firefox', 'web.whatsapp.com', 'personal'],
			['firefox', 'web.telegram.org', 'personal'],
			['Code', '', 'other'], ['Cursor', '', 'other'],
			['', '', 'other'],
		];
		for (const [id, url, expected] of cases) {
			assert.equal(style(exported.getAppType(id, url), id, url), expected,
				`${id} / ${url || 'no URL'}`);
		}
	}
	state.manuallySetAppType = 'manual';
	assert.equal(exported.getAppType(ids[0], ''), 'manual');
}
console.log('PASS: shipped classifier covers IDEs, personal/work/email/other, identifier limits, and manual override');
