#!/usr/bin/env bats

setup() {
	repo_root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
	resolver="$repo_root/scripts/setup/resolve-installer-url.sh"
	tmp_dir=$(mktemp -d)
	valid_sha='8c416030ca04936b96492a02a23fc7fee33ddc97ce75548de8b4a3dd662b984a'
}

teardown() {
	rm -rf "$tmp_dir"
}

write_manifest() {
	local schema="$1" url="$2" sha256="$3"
	{
		printf '{"schemaVersion":%s,"windows":{"x64":' "$schema"
		printf '{"url":"%s","sha256":"%s","size":354737528}}}\n' \
			"$url" "$sha256"
	} > "$tmp_dir/latest.json"
}

@test "resolves a validated installer manifest" {
	write_manifest 1 \
		'https://cdn.example/Wispr%20Flow%20Setup-v1.6.606.exe' \
		"$valid_sha"

	run "$resolver" --latest-url "file://$tmp_dir/latest.json"

	[ "$status" -eq 0 ]
	[[ "$output" == *'VERSION=1.6.606'* ]]
	[[ "$output" == *"SHA256=$valid_sha"* ]]
}

@test "rejects an unsupported manifest schema" {
	write_manifest 2 \
		'https://cdn.example/Wispr%20Flow%20Setup-v1.6.606.exe' \
		"$valid_sha"

	run "$resolver" --latest-url "file://$tmp_dir/latest.json"

	[ "$status" -ne 0 ]
	[[ "$output" == *'unsupported schemaVersion'* ]]
}

@test "rejects a non-HTTPS installer URL" {
	write_manifest 1 \
		'http://cdn.example/Wispr%20Flow%20Setup-v1.6.606.exe' \
		"$valid_sha"

	run "$resolver" --latest-url "file://$tmp_dir/latest.json"

	[ "$status" -ne 0 ]
	[[ "$output" == *'installer URL must use HTTPS'* ]]
}

@test "rejects an installer URL without a versioned Setup filename" {
	write_manifest 1 'https://cdn.example/WisprFlowInstaller.exe' \
		"$valid_sha"

	run "$resolver" --latest-url "file://$tmp_dir/latest.json"

	[ "$status" -ne 0 ]
	[[ "$output" == *'installer URL has no versioned Setup filename'* ]]
}

@test "rejects an invalid installer checksum" {
	write_manifest 1 \
		'https://cdn.example/Wispr%20Flow%20Setup-v1.6.606.exe' 'not-a-hash'

	run "$resolver" --latest-url "file://$tmp_dir/latest.json"

	[ "$status" -ne 0 ]
	[[ "$output" == *'invalid installer SHA-256'* ]]
}
