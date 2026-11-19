#!/usr/bin/env bats

setup() {
	TEST_TMP=$(mktemp -d)
	local root="$BATS_TEST_DIRNAME/.."
	mkdir -p "$TEST_TMP/scripts/packaging" "$TEST_TMP/bin" \
		"$TEST_TMP/dist/resources/Release"
	cp "$root/scripts/packaging/appimage.sh" "$TEST_TMP/scripts/packaging/"
	cp "$root/scripts/launcher-common.sh" "$root/scripts/doctor.sh" \
		"$TEST_TMP/scripts/"
	touch "$TEST_TMP/dist/resources/app.asar"
	printf '#!/bin/sh\nexit 0\n' > "$TEST_TMP/dist/wispr-flow"
	cp "$TEST_TMP/dist/wispr-flow" \
		"$TEST_TMP/dist/resources/Release/wispr-flow-linux-helper"
	chmod +x "$TEST_TMP/dist/wispr-flow" \
		"$TEST_TMP/dist/resources/Release/wispr-flow-linux-helper"
	cat > "$TEST_TMP/bin/appimagetool" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$TEST_TMP/args"
printf 'fixture AppImage\n' > "${@: -1}"
SH
	cat > "$TEST_TMP/bin/zsyncmake" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$TEST_TMP/zsync-args"
[[ ${ZSYNC_FAIL:-0} == 0 ]] || exit 1
[[ ${ZSYNC_MISSING:-0} == 0 ]] || exit 0
if [[ ${ZSYNC_EMPTY:-0} == 1 ]]; then
	touch "$4"
	exit 0
fi
[[ $1 == -u && $3 == -o && -f $5 ]] || exit 2
printf 'URL: %s\n' "$2" > "$4"
SH
	chmod +x "$TEST_TMP/bin/appimagetool" "$TEST_TMP/bin/zsyncmake"
	export TEST_TMP
}

teardown() {
	rm -rf "$TEST_TMP"
}

@test "AppImage updater follows the publishing repository" {
	for repo in srivasv/wispr-flow-linux wispr-flow-linux/wispr-flow-linux; do
		run env PATH="$TEST_TMP/bin:$PATH" GITHUB_ACTIONS=true \
			GITHUB_REPOSITORY="$repo" \
			bash "$TEST_TMP/scripts/packaging/appimage.sh" \
			"$TEST_TMP/dist" 1.0.9 x86_64
		[[ $status -eq 0 ]]
		grep -qxF "gh-releases-zsync|${repo/\//|}|latest|wispr-flow-*-x86_64.AppImage.zsync" "$TEST_TMP/args"
	done
}

@test "Local AppImages carry no release updater metadata" {
	run env PATH="$TEST_TMP/bin:$PATH" GITHUB_ACTIONS=false \
		bash "$TEST_TMP/scripts/packaging/appimage.sh" \
		"$TEST_TMP/dist" 1.0.9 x86_64
	[[ $status -eq 0 ]]
	! grep -qF -- '--updateinformation' "$TEST_TMP/args"
}

@test "Release sidecars are collected for both architectures from another cwd" {
	mkdir -p "$TEST_TMP/caller"
	cd "$TEST_TMP/caller"
	for arch in x86_64 aarch64; do
		run env PATH="$TEST_TMP/bin:$PATH" GITHUB_ACTIONS=true \
			bash "$TEST_TMP/scripts/packaging/appimage.sh" \
			"$TEST_TMP/dist" 1.0.9 "$arch"
		[[ $status -eq 0 ]]
		local name="wispr-flow-1.0.9-$arch.AppImage"
		local out="$TEST_TMP/build-linux/appimage/$name"
		[[ -s "$out.zsync" ]]
		grep -qxF "URL: $name" "$out.zsync"
		[[ $(sed -n '4p' "$TEST_TMP/zsync-args") == "$out.zsync" ]]
		[[ $(sed -n '5p' "$TEST_TMP/zsync-args") == "$out" ]]
		[[ ! -e "$TEST_TMP/caller/$name.zsync" ]]
	done
}

@test "Release fails when sidecar generation fails or produces no file" {
	for mode in ZSYNC_FAIL ZSYNC_EMPTY ZSYNC_MISSING; do
		run env PATH="$TEST_TMP/bin:$PATH" GITHUB_ACTIONS=true "$mode=1" \
			bash "$TEST_TMP/scripts/packaging/appimage.sh" \
			"$TEST_TMP/dist" 1.0.9 x86_64
		[[ $status -ne 0 ]]
		[[ $output == *sidecar* ]]
	done
}

@test "Local builds do not call zsyncmake" {
	run env PATH="$TEST_TMP/bin:$PATH" GITHUB_ACTIONS=false ZSYNC_FAIL=1 \
		bash "$TEST_TMP/scripts/packaging/appimage.sh" \
		"$TEST_TMP/dist" 1.0.9 x86_64
	[[ $status -eq 0 ]]
	[[ ! -e "$TEST_TMP/zsync-args" ]]
}

@test "Real zsyncmake writes a valid sidecar beside the release AppImage" {
	local real_zsync
	real_zsync=$(command -v zsyncmake) || skip 'zsyncmake not installed'
	cp "$real_zsync" "$TEST_TMP/bin/zsyncmake"
	mkdir -p "$TEST_TMP/caller"
	cd "$TEST_TMP/caller"
	run env PATH="$TEST_TMP/bin:$PATH" GITHUB_ACTIONS=true \
		bash "$TEST_TMP/scripts/packaging/appimage.sh" \
		"$TEST_TMP/dist" 1.0.9 x86_64
	[[ $status -eq 0 ]]
	local name='wispr-flow-1.0.9-x86_64.AppImage'
	local out="$TEST_TMP/build-linux/appimage/$name"
	grep -aqxF "URL: $name" "$out.zsync"
	grep -aqxF "Length: $(wc -c < "$out")" "$out.zsync"
	grep -aqxF "SHA-1: $(sha1sum "$out" | cut -d ' ' -f 1)" "$out.zsync"
	[[ ! -e "$TEST_TMP/caller/$name.zsync" ]]
}
