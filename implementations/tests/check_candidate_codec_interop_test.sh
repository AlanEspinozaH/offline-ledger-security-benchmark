#!/usr/bin/env bash
set -euo pipefail

fail() {
	printf 'not ok - %s\n' "$1" >&2
	exit 1
}

real_mktemp="$(command -v mktemp)"
readonly real_mktemp

real_git="$(command -v git)"
readonly real_git

script_dir="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1
	pwd
)"
readonly script_dir

repository_root="$(
	cd -- "${script_dir}/../.." || exit 1
	pwd
)"
readonly repository_root
readonly target_script="${repository_root}/scripts/check_candidate_codec_interop.sh"

readonly external_tmp_parent="${CANDIDATE_CODEC_TEST_TMPDIR:-/var/tmp}"
if [[ "${external_tmp_parent}" == "/tmp" || "${external_tmp_parent}" == /tmp/* ]]; then
	fail "CANDIDATE_CODEC_TEST_TMPDIR must be outside /tmp"
fi
if [[ ! -d "${external_tmp_parent}" || ! -w "${external_tmp_parent}" ]]; then
	fail "external temporary parent is not a writable directory: ${external_tmp_parent}"
fi

test_root="$(
	"${real_mktemp}" -d \
		"${external_tmp_parent%/}/candidate-codec-shell-test.XXXXXXXXXX"
)"
readonly test_root

cleanup_test_root() {
	rm -rf -- "${test_root}"
}
trap cleanup_test_root EXIT

write_go_guard() {
	local destination="$1"

	cat >"${destination}" <<'STUB'
#!/usr/bin/env bash
printf 'go-called\n' >"${GO_MARKER:?}"
exit 97
STUB
	chmod +x "${destination}"
}

write_recording_mktemp() {
	local destination="$1"

	cat >"${destination}" <<'STUB'
#!/usr/bin/env bash
created_dir="$(
	"${REAL_MKTEMP:?}" -d \
		"${TARGET_TMPDIR:?}/candidate-codec-target.XXXXXXXXXX"
)"
printf '%s\n' "${created_dir}" >"${TARGET_TEMP_RECORD:?}"
printf '%s\n' "${created_dir}"
STUB
	chmod +x "${destination}"
}

test_mktemp_failure_stops_before_go() {
	local scenario_dir="${test_root}/mktemp-failure"
	local fake_bin="${scenario_dir}/bin"
	local go_marker="${scenario_dir}/go-called"
	local output="${scenario_dir}/output"
	local status

	mkdir -p "${fake_bin}"

	cat >"${fake_bin}/mktemp" <<'STUB'
#!/usr/bin/env bash
exit 71
STUB
	chmod +x "${fake_bin}/mktemp"
	write_go_guard "${fake_bin}/go"

	set +e
	GO_MARKER="${go_marker}" \
		PATH="${fake_bin}:${PATH}" \
		bash "${target_script}" >"${output}" 2>&1
	status=$?
	set -e

	if ((status == 0)); then
		fail "mktemp failure returned success"
	fi
	if [[ -e "${go_marker}" ]]; then
		fail "go build ran after mktemp failure"
	fi

	printf 'ok - mktemp failure stops before go build\n'
}

test_git_failure_cleans_and_stops_before_go() {
	local scenario_dir="${test_root}/git-failure"
	local fake_bin="${scenario_dir}/bin"
	local target_tmpdir="${scenario_dir}/target-tmp"
	local temp_record="${scenario_dir}/target-temp-path"
	local go_marker="${scenario_dir}/go-called"
	local output="${scenario_dir}/output"
	local status
	local target_temp

	mkdir -p "${fake_bin}" "${target_tmpdir}"
	write_recording_mktemp "${fake_bin}/mktemp"
	write_go_guard "${fake_bin}/go"

	cat >"${fake_bin}/git" <<'STUB'
#!/usr/bin/env bash
if [[ " $* " == *" rev-parse HEAD "* ]]; then
	exit 72
fi
exec "${REAL_GIT:?}" "$@"
STUB
	chmod +x "${fake_bin}/git"

	set +e
	GO_MARKER="${go_marker}" \
		PATH="${fake_bin}:${PATH}" \
		REAL_GIT="${real_git}" \
		REAL_MKTEMP="${real_mktemp}" \
		TARGET_TMPDIR="${target_tmpdir}" \
		TARGET_TEMP_RECORD="${temp_record}" \
		bash "${target_script}" >"${output}" 2>&1
	status=$?
	set -e

	if ((status == 0)); then
		fail "git rev-parse failure returned success"
	fi
	if [[ -e "${go_marker}" ]]; then
		fail "go build ran after git rev-parse failure"
	fi
	if [[ ! -f "${temp_record}" ]]; then
		fail "git failure scenario did not record target temporary directory"
	fi

	target_temp="$(<"${temp_record}")"
	if [[ -e "${target_temp}" ]]; then
		fail "temporary directory survived git rev-parse failure: ${target_temp}"
	fi

	printf 'ok - git rev-parse failure cleans and stops before go build\n'
}

test_external_tmpdir_is_cleaned_after_success() {
	local scenario_dir="${test_root}/external-tmpdir"
	local fake_bin="${scenario_dir}/bin"
	local target_tmpdir="${scenario_dir}/target-tmp"
	local temp_record="${scenario_dir}/target-temp-path"
	local output="${scenario_dir}/output"
	local target_temp

	mkdir -p "${fake_bin}" "${target_tmpdir}"
	write_recording_mktemp "${fake_bin}/mktemp"

	PATH="${fake_bin}:${PATH}" \
		PYTHONDONTWRITEBYTECODE=1 \
		REAL_MKTEMP="${real_mktemp}" \
		TARGET_TMPDIR="${target_tmpdir}" \
		TARGET_TEMP_RECORD="${temp_record}" \
		TMPDIR="${target_tmpdir}" \
		bash "${target_script}" >"${output}" 2>&1

	if ! grep -Fq \
		'CANDIDATO NO NORMATIVO | interop | 5/5 seed fixtures matched byte for byte and repeated identically' \
		"${output}"; then
		fail "external TMPDIR scenario did not complete interoperability"
	fi
	if [[ ! -f "${temp_record}" ]]; then
		fail "external TMPDIR scenario did not record target temporary directory"
	fi

	target_temp="$(<"${temp_record}")"
	if [[ "${target_temp}" != "${target_tmpdir}/"* ]]; then
		fail "target temporary directory did not respect TMPDIR: ${target_temp}"
	fi
	if [[ -e "${target_temp}" ]]; then
		fail "target temporary directory survived successful execution: ${target_temp}"
	fi
	if find "${target_tmpdir}" -mindepth 1 -print -quit | grep -q .; then
		fail "external TMPDIR contains residual files"
	fi

	printf 'ok - non-/tmp TMPDIR succeeds and leaves no residue\n'
}

test_mktemp_failure_stops_before_go
test_git_failure_cleans_and_stops_before_go
test_external_tmpdir_is_cleaned_after_success

printf 'CANDIDATO NO NORMATIVO | shell regression | 3/3 scenarios passed\n'
