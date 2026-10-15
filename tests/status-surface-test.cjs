const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const reports = [];
let queried = '';
let elements = [];
let mutation;
const node = {
    hasAttribute: key => key === 'data-status-window-shape',
    getAttribute: () => null,
    getBoundingClientRect: () => ({left: 10, top: 20, width: 30, height: 40}),
    closest: () => null,
};
const ctx = {
    Map, Set, WeakMap, Promise, Number, Array, String,
    window: {electron: {platform: {os: 'linux'}}, innerWidth: 512, innerHeight: 586,
        addEventListener() {}, removeEventListener() {}},
    document: {body: {}, querySelectorAll(selector) { queried = selector; return elements; },
        addEventListener() {}, removeEventListener() {}},
    getComputedStyle: () => ({display: 'block', visibility: 'visible', opacity: '1', pointerEvents: 'auto'}),
    ResizeObserver: class { observe() {} unobserve() {} disconnect() {} },
    MutationObserver: class { constructor(cb) { mutation = cb; } observe() {} disconnect() {} },
};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8') + '\nglobalThis.collector = Object.values(modules)[0];', ctx);
const exportsObject = {};
function load(id) {
    if (id === 81794) return {useLayoutEffect: fn => fn(), useEffect: fn => fn()};
    if (id === 56961) return {H8: false};
    if (id === 26291) return {EB: {ReportAlphaCatchRects: 'report'}};
    if (id === 82889) return {$: (_channel, _await, payload) => reports.push(payload)};
    throw Error('Unexpected fixture dependency ' + id);
}
load.d = (target, definitions) => {
    for (const [key, getter] of Object.entries(definitions)) Object.defineProperty(target, key, {get: getter});
};
ctx.collector({}, exportsObject, load);
(async () => {
    exportsObject.fq();
    await Promise.resolve(); await Promise.resolve();
    assert.equal(reports.length, 1);
    assert.equal(reports[0].rects.length, 0);
    assert.equal(reports[0].shapeRects.length, 0);
    assert.ok(queried.includes('data-status-window-shape'));
    elements = [node]; mutation();
    await Promise.resolve(); await Promise.resolve(); await Promise.resolve();
    assert.deepEqual(JSON.parse(JSON.stringify(reports.at(-1).shapeRects)), [{x:10,y:20,width:30,height:40}]);
    elements = []; mutation();
    await Promise.resolve(); await Promise.resolve(); await Promise.resolve();
    assert.equal(reports.at(-1).shapeRects.length, 0);
})().catch(error => { console.error(error); process.exitCode = 1; });
