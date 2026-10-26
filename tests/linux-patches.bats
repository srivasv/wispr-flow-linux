#!/usr/bin/env bats
#
# linux-patches.bats
# Unit tests for the six renderer/main bundle patches added for the Linux port:
#   * linux-renderer-chrome.sh           -> remaps the <html> platform class linux->win32
#   * linux-window-frame.sh              -> frameless hub/settings window on Linux
#   * linux-hub-focusable.sh             -> hub window focusable/WM-managed on Linux
#   * linux-status-input-shape.sh        -> bounded Status input shape on X11
#   * linux-renderer-treat-as-windows.sh -> widens each renderer's isWindows bind
#                                           (bridge stays honest; no preload touched)
#   * linux-deeplink.sh                  -> cold-start wispr-flow: argv parse on Linux
#
# The real bundle is the proprietary, gitignored app -- not available in CI -- so
# each test drives a hermetic minified-JS FIXTURE carrying the exact anchor the
# patch keys on. Every patch is asserted to: apply (marker + transformation),
# leave unrelated sites alone, produce parseable JS (node --check, skipped if
# node is absent), be idempotent (second run is a no-op, byte-identical), and
# bail non-zero on a fixture whose anchor is absent (never silently no-op).
#

SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
PATCH_DIR="$SCRIPT_DIR/../scripts/patches"

setup() {
	TEST_TMP=$(mktemp -d)
	export TEST_TMP
	FIX="$TEST_TMP/bundle.js"
	export FIX
}

teardown() {
	if [[ -n "${TEST_TMP:-}" && -d "$TEST_TMP" ]]; then
		rm -rf "$TEST_TMP"
	fi
}

# node --check the fixture, but only if node is installed (it is in the build
# env; a bare bats runner may lack it).
node_check() {
	if command -v node >/dev/null; then
		node --check "$1"
	fi
}

# Assert a second run is a no-op and the file is byte-identical to the first run.
assert_idempotent() {
	local script="$1" target="$2" before after
	before=$(md5sum "$target" | cut -d' ' -f1)
	run bash "$script" "$target"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *lready\ patched* ]]
	after=$(md5sum "$target" | cut -d' ' -f1)
	[[ "$before" == "$after" ]]
}

write_status_shape_fixture() {
	cat > "$FIX" <<'JS'
const y={H8:!1},F={replaceWindow(){},setEnabled(){},applyReport(){return!0}},n={setIgnoreMouseEvents(){}},m={cr(){},cM(){},cA(){}};
y.H8?F.replaceWindow(n):n.setIgnoreMouseEvents(!0,{forward:!0});
const s=[{x:-2,y:-2,width:1,height:1}];
class Shape{enabled=!1;everEnabled=!1;latestRects=[];applyShape(){}applyCurrentShape(){this.enabled?this.applyShape(this.latestRects):this.applyShape(this.everEnabled?s:[])}}
function report(e,t){const n={webContents:e};if(n&&e===n.webContents)if(!0){if(y.H8){if(!F.applyReport(e,t))return;(0,m.cr)(n,t.shapeRects)}(0,m.cM)(n,t.rects),(0,m.cA)(n)}else return!1}
const overlay={setIgnoreMouseEvents(){}};overlay.setIgnoreMouseEvents(!0);
JS
}

# =============================================================================
# Helper launch anchors (upstream extracted these into functions in 1.6.x).
# =============================================================================

@test "helper-resolver: overrides a function-returned path with the local logger" {
	cat > "$FIX" <<'JS'
function launch(){const s=(0,f.j)();if(!d().existsSync(s))return l().error("Helper service script path not found",{customAttributes:{serviceScriptPath:s}});return s}
function other(){s().info("Running packaged Windows Helper service")}
JS
	run bash "$PATCH_DIR/helper-resolver.sh" "$FIX"
	[[ "$status" -eq 0 ]]
	grep -qF 'l().info("Running packaged Linux Helper service"' "$FIX"
	node - "$FIX" <<'JS'
const fs=require("fs"),vm=require("vm"),assert=require("assert");
for(const platform of ["linux","win32","darwin"]){
 const result=vm.runInNewContext(fs.readFileSync(process.argv[2],"utf8")+";launch()",{
  process:{platform,resourcesPath:"/resources"},require,
  f:{j:()=>"original-helper"},d:()=>({existsSync:()=>true}),
  l:()=>({info(){},error(){throw Error("unexpected missing helper")}})
 });
 assert.equal(result,platform==="linux"?
  "/resources/Release/wispr-flow-linux-helper":"original-helper");
}
JS
	node_check "$FIX"
	assert_idempotent "$PATCH_DIR/helper-resolver.sh" "$FIX"
}

@test "helper-resolver: keeps the inline resolver supported" {
	cat > "$FIX" <<'JS'
function launch(){const $s=f.tD?E.ty.isHelperProcessRunningManually?"dev-mac":"mac":E.ty.isHelperProcessRunningManually?"dev-win":(l().info("Running packaged Windows Helper service"),`${_.ZI}\\Release\\Wispr Flow Helper.exe`);if(!d().existsSync($s))return void l().error("Helper service script path not found");return $s}
JS
	run bash "$PATCH_DIR/helper-resolver.sh" "$FIX"
	[[ "$status" -eq 0 ]]
	node_check "$FIX"
	assert_idempotent "$PATCH_DIR/helper-resolver.sh" "$FIX"
}

@test "helper-resolver: rejects missing or duplicate helper guards unchanged" {
	printf '%s\n' 'const s=path();if(!fs().existsSync(s))returnValue();' > "$FIX"
	run bash "$PATCH_DIR/helper-resolver.sh" "$FIX"
	[[ "$status" -ne 0 ]]
	cmp "$FIX" "$FIX.orig"
	cat > "$FIX" <<'JS'
function a(){const s=path();if(!fs().existsSync(s))return log().error("Helper service script path not found")}
function b(){const t=path();if(!fs().existsSync(t))return log().error("Helper service script path not found")}
JS
	cp "$FIX" "$FIX.orig"
	run bash "$PATCH_DIR/helper-resolver.sh" "$FIX"
	[[ "$status" -ne 0 ]]
	cmp "$FIX" "$FIX.orig"
}

@test "helper-env: spreads session env before factory values and preserves stdio" {
	cat > "$FIX" <<'JS'
const R=()=>({sentryDSN:"telemetry",DISPLAY:"override"});
const child=spawn(helper,{stdio:["pipe","pipe","pipe","pipe"],env:R()});
JS
	run bash "$PATCH_DIR/helper-env.sh" "$FIX"
	[[ "$status" -eq 0 ]]
	node - "$FIX" <<'JS'
const fs=require("fs"),vm=require("vm"),assert=require("assert");
let options;
vm.runInNewContext(fs.readFileSync(process.argv[2],"utf8"),{
 process:{env:{WAYLAND_DISPLAY:"wayland-0",DISPLAY:":0"}},helper:"helper",
 spawn:(path,opts)=>{options=opts}
});
assert.equal(options.env.WAYLAND_DISPLAY,"wayland-0");
assert.equal(options.env.DISPLAY,"override");
assert.equal(options.env.sentryDSN,"telemetry");
assert.equal(options.stdio.length,4);
JS
	assert_idempotent "$PATCH_DIR/helper-env.sh" "$FIX"
}

@test "helper-env: keeps inline env supported and rejects absent anchors" {
	printf '%s\n' 'spawn(s,{stdio:["pipe","pipe","pipe","pipe"],env:{sentryDSN:b.kL}});' > "$FIX"
	run bash "$PATCH_DIR/helper-env.sh" "$FIX"
	[[ "$status" -eq 0 ]]
	grep -qF '...process.env,sentryDSN:b.kL' "$FIX"
	assert_idempotent "$PATCH_DIR/helper-env.sh" "$FIX"
	printf '%s\n' 'spawn(s,{stdio:["pipe","pipe","pipe"],env:{}});' > "$FIX"
	cp "$FIX" "$FIX.orig"
	run bash "$PATCH_DIR/helper-env.sh" "$FIX"
	[[ "$status" -ne 0 ]]
	cmp "$FIX" "$FIX.orig"
}

@test "window-frame: accepts the added frame property without changing it" {
	cat > "$FIX" <<'JS'
const t={};"win32"===process.platform&&Object.assign(t,{titleBarStyle:"hidden",frame:!1,autoHideMenuBar:!0});
JS
	run bash "$PATCH_DIR/linux-window-frame.sh" "$FIX"
	[[ "$status" -eq 0 ]]
	grep -qF '"win32"===process.platform||"linux"===process.platform' "$FIX"
	grep -qF '{titleBarStyle:"hidden",frame:!1,autoHideMenuBar:!0}' "$FIX"
	node_check "$FIX"
	assert_idempotent "$PATCH_DIR/linux-window-frame.sh" "$FIX"
}

# =============================================================================
# linux-renderer-chrome.sh
# =============================================================================

@test "chrome: remaps every classList.add(...platform.os) site, leaves others" {
	cat > "$FIX" <<'JS'
document.documentElement.classList.add(window.electron.platform.os);
function f(el){el.classList.add(window.electron.platform.os)}
requestAnimationFrame(()=>x.classList.add(Yw.animated));
JS
	run bash "$PATCH_DIR/linux-renderer-chrome.sh" "$FIX"
	[[ "$status" -eq 0 ]]
	grep -q 'WISPR_LINUX_WIN32_CHROME' "$FIX"
	# both platform.os sites became a linux->win32 ternary
	[[ "$(grep -c '"linux"===window.electron.platform.os?"win32"' "$FIX")" -eq 2 ]]
	# the unrelated animated site is untouched
	grep -qF 'classList.add(Yw.animated)' "$FIX"
	node_check "$FIX"
}

@test "chrome: idempotent on second run" {
	cat > "$FIX" <<'JS'
document.documentElement.classList.add(window.electron.platform.os);
JS
	bash "$PATCH_DIR/linux-renderer-chrome.sh" "$FIX"
	assert_idempotent "$PATCH_DIR/linux-renderer-chrome.sh" "$FIX"
}

@test "chrome: bails non-zero when the anchor is absent" {
	cat > "$FIX" <<'JS'
requestAnimationFrame(()=>x.classList.add(Yw.animated));
JS
	run bash "$PATCH_DIR/linux-renderer-chrome.sh" "$FIX"
	[[ "$status" -ne 0 ]]
	! grep -q 'WISPR_LINUX_WIN32_CHROME' "$FIX"
}

# =============================================================================
# linux-window-frame.sh
# =============================================================================

@test "window-frame: widens the win32 hidden-titlebar predicate to include linux" {
	# The 1.5.695 mac branch dropped "hiddenInset" -- it now sets
	# {frame:!1,titleBarStyle:"hidden",trafficLightPosition,...}. The anchor no
	# longer keys on the mac branch, only on the win32 predicate + hidden assign.
	cat > "$FIX" <<'JS'
var s={tD:false},t={};
s.tD?Object.assign(t,{frame:!1,titleBarStyle:"hidden",trafficLightPosition:{x:1e4,y:10},transparent:!0,hasShadow:!0}):"win32"===process.platform&&Object.assign(t,{titleBarStyle:"hidden",autoHideMenuBar:!0});
JS
	run bash "$PATCH_DIR/linux-window-frame.sh" "$FIX"
	[[ "$status" -eq 0 ]]
	grep -q 'WISPR_LINUX_FRAMELESS' "$FIX"
	grep -qF '"win32"===process.platform||"linux"===process.platform' "$FIX"
	# the mac branch is left untouched
	grep -qF 'trafficLightPosition:{x:1e4,y:10}' "$FIX"
	node_check "$FIX"
}

@test "window-frame: idempotent on second run" {
	cat > "$FIX" <<'JS'
var s={tD:false},t={};
s.tD?Object.assign(t,{frame:!1,titleBarStyle:"hidden",trafficLightPosition:{x:1e4,y:10},transparent:!0,hasShadow:!0}):"win32"===process.platform&&Object.assign(t,{titleBarStyle:"hidden",autoHideMenuBar:!0});
JS
	bash "$PATCH_DIR/linux-window-frame.sh" "$FIX"
	assert_idempotent "$PATCH_DIR/linux-window-frame.sh" "$FIX"
}

@test "window-frame: bails non-zero when no matching window config exists" {
	cat > "$FIX" <<'JS'
var t={};Object.assign(t,{titleBarStyle:"default"});
JS
	run bash "$PATCH_DIR/linux-window-frame.sh" "$FIX"
	[[ "$status" -ne 0 ]]
	! grep -q 'WISPR_LINUX_FRAMELESS' "$FIX"
}

# =============================================================================
# linux-hub-focusable.sh
# =============================================================================

@test "hub-focusable: rewrites the Hub focusable:!1, leaves overlays alone" {
	cat > "$FIX" <<'JS'
const t={title:"Flow Hub",center:!0,show:!1,webPreferences:{preload:require("path").resolve(__dirname,"../renderer","hub","preload.js"),devTools:"development"===_.M0||(0,N.Pv)(d.RA.prefs?.user.email||"")},focusable:!1};_.tD?Object.assign(t,{frame:!1,titleBarStyle:"hidden"}):Object.assign(t,{frame:!1,autoHideMenuBar:!0});
const ov=new r.BrowserWindow({show:!1,transparent:!0,frame:!1,hasShadow:!1,focusable:!1,skipTaskbar:!0});
JS
	run bash "$PATCH_DIR/linux-hub-focusable.sh" "$FIX"
	[[ "$status" -eq 0 ]]
	grep -q 'WISPR_LINUX_HUB_FOCUSABLE' "$FIX"
	# the Hub site now gates focusable on the platform
	grep -qF 'focusable:/*WISPR_LINUX_HUB_FOCUSABLE*/"linux"===process.platform}' "$FIX"
	# the overlay's intentional focusable:!1 is untouched (exactly one remains)
	[[ "$(grep -c 'focusable:!1' "$FIX")" -eq 1 ]]
	grep -qF 'hasShadow:!1,focusable:!1,skipTaskbar:!0' "$FIX"
	node_check "$FIX"
}

@test "hub-focusable: idempotent on second run" {
	cat > "$FIX" <<'JS'
const t={title:"Flow Hub",center:!0,show:!1,webPreferences:{preload:require("path").resolve(__dirname,"../renderer","hub","preload.js"),devTools:"development"===_.M0},focusable:!1};
JS
	bash "$PATCH_DIR/linux-hub-focusable.sh" "$FIX"
	assert_idempotent "$PATCH_DIR/linux-hub-focusable.sh" "$FIX"
}

@test "hub-focusable: bails non-zero when the Hub anchor is absent" {
	cat > "$FIX" <<'JS'
const ov=new r.BrowserWindow({show:!1,transparent:!0,frame:!1,hasShadow:!1,focusable:!1,skipTaskbar:!0});
JS
	run bash "$PATCH_DIR/linux-hub-focusable.sh" "$FIX"
	[[ "$status" -ne 0 ]]
	! grep -q 'WISPR_LINUX_HUB_FOCUSABLE' "$FIX"
}

# =============================================================================
# linux-status-input-shape.sh
# =============================================================================

@test "status-shape: uses renderer rectangles only on Linux X11" {
	write_status_shape_fixture
	run bash "$PATCH_DIR/linux-status-input-shape.sh" "$FIX"
	[[ "$status" -eq 0 ]]
	[[ "$(grep -o 'WISPR_LINUX_X11_STATUS_SHAPE' "$FIX" | wc -l)" -eq 4 ]]
	grep -qF '!!process.env.DISPLAY&&!process.env.WAYLAND_DISPLAY' "$FIX"
	grep -qF 'F.replaceWindow(n)' "$FIX"
	grep -qF 'F.setEnabled(!0)' "$FIX"
	grep -qF 'F.applyReport(e,t)' "$FIX"
	grep -qF 'this.latestRects.length' "$FIX"
	grep -qF 'this.latestRects:s' "$FIX"
	# The unrelated overlay keeps its shipped whole-window behavior.
	grep -qF 'overlay.setIgnoreMouseEvents(!0)' "$FIX"
	node_check "$FIX"
}

@test "status-shape: idempotent on second run" {
	write_status_shape_fixture
	bash "$PATCH_DIR/linux-status-input-shape.sh" "$FIX"
	assert_idempotent "$PATCH_DIR/linux-status-input-shape.sh" "$FIX"
}

@test "status-shape: bails when any required anchor is absent" {
	write_status_shape_fixture
	sed -i 's/F\.applyReport(e,t)/F.applyStatusReport(e,t)/' "$FIX"
	run bash "$PATCH_DIR/linux-status-input-shape.sh" "$FIX"
	[[ "$status" -ne 0 ]]
	! grep -q 'WISPR_LINUX_X11_STATUS_SHAPE' "$FIX"
}

# =============================================================================
# linux-renderer-treat-as-windows.sh
# =============================================================================

@test "treat-as-windows: widens the isWindows bind to include linux, honest bridge" {
	cat > "$FIX" <<'JS'
const y="undefined"!=typeof window?window.electron:void 0,$=y?.platform?.isMacOS??!1,x=y?.platform?.isWindows??!1,k="2025-03-01";
const na=x?Yi:Li,delay=x?500:100;
JS
	run bash "$PATCH_DIR/linux-renderer-treat-as-windows.sh" "$FIX"
	[[ "$status" -eq 0 ]]
	grep -q 'WISPR_LINUX_RENDERER_ISWIN' "$FIX"
	# the bind is widened, reusing the SAME window.electron local (y) for the OS check
	grep -qF 'x=((y?.platform?.isWindows??!1)||"linux"===y?.platform?.os)/*WISPR_LINUX_RENDERER_ISWIN*/' "$FIX"
	# isMacOS bind is untouched; the bridge property name itself is never flipped
	grep -qF '$=y?.platform?.isMacOS??!1' "$FIX"
	# downstream consumers (na, delay) are left exactly as-is -- they ride on x
	grep -qF 'na=x?Yi:Li' "$FIX"
	grep -qF 'delay=x?500:100' "$FIX"
	node_check "$FIX"
}

@test "treat-as-windows: idempotent on second run" {
	cat > "$FIX" <<'JS'
const y=window.electron,$=y?.platform?.isMacOS??!1,x=y?.platform?.isWindows??!1;
JS
	bash "$PATCH_DIR/linux-renderer-treat-as-windows.sh" "$FIX"
	assert_idempotent "$PATCH_DIR/linux-renderer-treat-as-windows.sh" "$FIX"
}

@test "treat-as-windows: bails non-zero when the renderer has no isWindows bind" {
	cat > "$FIX" <<'JS'
const y=window.electron,$=y?.platform?.isMacOS??!1;
JS
	run bash "$PATCH_DIR/linux-renderer-treat-as-windows.sh" "$FIX"
	[[ "$status" -ne 0 ]]
	! grep -q 'WISPR_LINUX_RENDERER_ISWIN' "$FIX"
}

# =============================================================================
# linux-deeplink.sh
# =============================================================================

@test "deeplink: widens the cold-start win32 argv guard to include linux" {
	cat > "$FIX" <<'JS'
function L(x){}function B(x){return x}
if(f.H8){const e=B(process.argv.find(e=>e.startsWith("wispr-flow:")||e.startsWith("wispr-flow/")));e&&L(e)}
JS
	run bash "$PATCH_DIR/linux-deeplink.sh" "$FIX"
	[[ "$status" -eq 0 ]]
	grep -q 'WISPR_LINUX_DEEPLINK' "$FIX"
	grep -qF 'if(f.H8||"linux"===process.platform){' "$FIX"
	node_check "$FIX"
}

@test "deeplink: idempotent on second run" {
	cat > "$FIX" <<'JS'
function L(x){}function B(x){return x}
if(f.H8){const e=B(process.argv.find(e=>e.startsWith("wispr-flow:")||e.startsWith("wispr-flow/")));e&&L(e)}
JS
	bash "$PATCH_DIR/linux-deeplink.sh" "$FIX"
	assert_idempotent "$PATCH_DIR/linux-deeplink.sh" "$FIX"
}

@test "deeplink: leaves the cross-platform second-instance handler untouched" {
	# second-instance scans r.find(...), NOT process.argv.find(...) -- the anchor
	# must not match it, so the patch must bail (0 cold-start guards present).
	cat > "$FIX" <<'JS'
function L(x){}function B(x){return x}
app.on("second-instance",(e,r)=>{if(f.H8){const u=B(r.find(e=>e.startsWith("wispr-flow:")));u&&L(u)}});
JS
	run bash "$PATCH_DIR/linux-deeplink.sh" "$FIX"
	[[ "$status" -ne 0 ]]
	! grep -q 'WISPR_LINUX_DEEPLINK' "$FIX"
}

@test "hub-focusable: tolerates keys between preload and devTools (1.6.1264+)" {
	cat > "$FIX" <<'JS'
const t={title:"Flow Hub",show:!1,webPreferences:{...A.g,preload:require("path").resolve(__dirname,"../renderer","hub","preload.js"),webviewTag:(0,x.qK)(),devTools:"development"===w.M0||(0,N.Pv)(p.RA.prefs?.user.email||"")},focusable:!1};
const ov=new r.BrowserWindow({show:!1,transparent:!0,frame:!1,hasShadow:!1,focusable:!1,skipTaskbar:!0});
JS
	run bash "$PATCH_DIR/linux-hub-focusable.sh" "$FIX"
	[[ "$status" -eq 0 ]]
	grep -qF 'webviewTag:(0,x.qK)(),devTools:' "$FIX"
	grep -qF 'focusable:/*WISPR_LINUX_HUB_FOCUSABLE*/"linux"===process.platform}' "$FIX"
	[[ "$(grep -c 'focusable:!1' "$FIX")" -eq 1 ]]
	node_check "$FIX"
}

@test "hub-focusable: never spans a nested object after the preload (near-miss)" {
	# `[^{}]*` is what keeps the match inside webPreferences now that the
	# anchor no longer names devTools; a brace in between must stop it.
	cat > "$FIX" <<'JS'
const t={title:"Flow Hub",webPreferences:{preload:require("path").resolve(__dirname,"../renderer","hub","preload.js"),extra:{x:1},devTools:!1},focusable:!1};
JS
	run bash "$PATCH_DIR/linux-hub-focusable.sh" "$FIX"
	[[ "$status" -ne 0 ]]
	! grep -q 'WISPR_LINUX_HUB_FOCUSABLE' "$FIX"
}

# =============================================================================
# mac-gates.sh
# =============================================================================

@test "mac-gates: gates the Applications-folder guard to darwin" {
	cat > "$FIX" <<'JS'
const i={app:{getAppPath:()=>""}},c={H8:!1};
const w=()=>{if(c.H8)return!1;const e=i.app.getAppPath();return e};
JS
	run bash "$PATCH_DIR/mac-gates.sh" "$FIX"
	[[ "$status" -eq 0 ]]
	grep -qF 'w=()=>{if(c.H8)return!1;if("darwin"!==process.platform)return!1;const e=' "$FIX"
	node_check "$FIX"
}

@test "mac-gates: gates the async guard (1.6.1264+)" {
	cat > "$FIX" <<'JS'
const i={app:{getAppPath:()=>""}},l={H8:!1};
const C=async()=>{if(l.H8)return!1;const e=i.app.getAppPath();return e};
JS
	run bash "$PATCH_DIR/mac-gates.sh" "$FIX"
	[[ "$status" -eq 0 ]]
	grep -qF 'C=async()=>{if(l.H8)return!1;if("darwin"!==process.platform)return!1;const e=' "$FIX"
	node_check "$FIX"
}

@test "mac-gates: idempotent on second run" {
	cat > "$FIX" <<'JS'
const i={app:{getAppPath:()=>""}},l={H8:!1};
const C=async()=>{if(l.H8)return!1;const e=i.app.getAppPath();return e};
JS
	bash "$PATCH_DIR/mac-gates.sh" "$FIX"
	assert_idempotent "$PATCH_DIR/mac-gates.sh" "$FIX"
}

@test "mac-gates: leaves a getAppPath() site without the early-out alone" {
	# Near-miss: the other getAppPath() callers have no `if(<flag>)return!1;`
	# right before the call, so the anchor must not take them.
	cat > "$FIX" <<'JS'
const i={app:{getAppPath:()=>""}};
const u=async()=>{const e=i.app.getAppPath();return e};
JS
	run bash "$PATCH_DIR/mac-gates.sh" "$FIX"
	[[ "$status" -ne 0 ]]
	! grep -q 'darwin' "$FIX"
}

@test "deeplink: widens the guard when it ends a comma sequence (1.6.1264+)" {
	cat > "$FIX" <<'JS'
function L(x){}function B(x){return x}let t;
if(t=app.setAsDefaultProtocolClient("wispr-flow"),app.on("open-url",(e,t)=>{L(t)}),A.H8){const e=B(process.argv.find(e=>e.startsWith("wispr-flow:")||e.startsWith("wispr-flow/")));e&&L(e)}
JS
	run bash "$PATCH_DIR/linux-deeplink.sh" "$FIX"
	[[ "$status" -eq 0 ]]
	grep -qF ',A.H8||"linux"===process.platform){/*WISPR_LINUX_DEEPLINK*/' "$FIX"
	node_check "$FIX"
}

@test "deeplink: refuses a negated guard (near-miss for the anchor)" {
	# `if(!f.H8)` is a different condition; widening it with `||linux` would
	# invert the meaning, so the anchor must not take it.
	cat > "$FIX" <<'JS'
function L(x){}function B(x){return x}
if(!f.H8){const e=B(process.argv.find(e=>e.startsWith("wispr-flow:")||e.startsWith("wispr-flow/")));e&&L(e)}
JS
	run bash "$PATCH_DIR/linux-deeplink.sh" "$FIX"
	[[ "$status" -ne 0 ]]
	! grep -q 'WISPR_LINUX_DEEPLINK' "$FIX"
}

@test "deeplink: refuses a guard that ends an && chain (near-miss for the lead)" {
	# `if(a&&f.H8)` widened to `a&&f.H8||linux` would skip `a` on Linux:
	# only `if(` and `,` are safe leads.
	cat > "$FIX" <<'JS'
function L(x){}function B(x){return x}var a=!0;
if(a&&f.H8){const e=B(process.argv.find(e=>e.startsWith("wispr-flow:")||e.startsWith("wispr-flow/")));e&&L(e)}
JS
	run bash "$PATCH_DIR/linux-deeplink.sh" "$FIX"
	[[ "$status" -ne 0 ]]
	! grep -q 'WISPR_LINUX_DEEPLINK' "$FIX"
}

@test "deeplink: refuses a while( guard (near-miss for the if( lead)" {
	# A bare `(` lead would widen this into valid but different JS.
	cat > "$FIX" <<'JS'
function L(x){}function B(x){return x}
while(f.H8){const e=B(process.argv.find(e=>e.startsWith("wispr-flow:")||e.startsWith("wispr-flow/")));e&&L(e);break}
JS
	run bash "$PATCH_DIR/linux-deeplink.sh" "$FIX"
	[[ "$status" -ne 0 ]]
	! grep -q 'WISPR_LINUX_DEEPLINK' "$FIX"
}

@test "deeplink: a parameter list after a comma fails loudly, file restored" {
	# `,e){` also ends a parameter list; the rewrite there does not parse, so
	# the syntax check must reject it and restore the original bytes.
	cat > "$FIX" <<'JS'
function L(x){}function B(x){return x}
function q(a,e){const t=B(process.argv.find(e=>e.startsWith("wispr-flow:")||e.startsWith("wispr-flow/")));t&&L(t)}
JS
	cp "$FIX" "$FIX.before"
	run bash "$PATCH_DIR/linux-deeplink.sh" "$FIX"
	[[ "$status" -ne 0 ]]
	cmp -s "$FIX" "$FIX.before"
}
