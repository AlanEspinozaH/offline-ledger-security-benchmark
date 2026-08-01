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

real_go="$(command -v go)"
readonly real_go

real_python="$(command -v python3)"
readonly real_python

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
readonly sentinel_name=".candidate-codec-interop-owner"

external_tmp_parent="${CANDIDATE_CODEC_TEST_TMPDIR:-/var/tmp}"
while [[ "${external_tmp_parent}" != "/" && "${external_tmp_parent}" == */ ]]; do
	external_tmp_parent="${external_tmp_parent%/}"
done
readonly external_tmp_parent

if [[ "${external_tmp_parent}" == "/tmp" ||
	"${external_tmp_parent}" == /tmp/* ]]; then
	fail "CANDIDATE_CODEC_TEST_TMPDIR must be outside /tmp"
fi
if [[ ! -d "${external_tmp_parent}" ||
	! -w "${external_tmp_parent}" ||
	-L "${external_tmp_parent}" ]]; then
	fail "external temporary parent is not a writable, non-symlink directory: ${external_tmp_parent}"
fi

test_root="$(
	"${real_mktemp}" -d \
		"${external_tmp_parent}/candidate-codec-shell-test.XXXXXXXXXX"
)"
readonly test_root

cleanup_test_root() {
	rm -rf -- "${test_root}"
}
trap cleanup_test_root EXIT

repository_state() {
	"${real_git}" -C "${repository_root}" \
		status --porcelain --untracked-files=all
}

assert_repository_unchanged() {
	local expected="$1"
	local label="$2"
	local actual

	actual="$(repository_state)"
	if [[ "${actual}" != "${expected}" ]]; then
		fail "${label} modified the repository working tree"
	fi
}

write_recording_mktemp() {
	local destination="$1"

	cat >"${destination}" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\0' "$@" >"${MKTEMP_ARGS_RECORD:?}"
created_dir="$("${REAL_MKTEMP:?}" "$@")"
printf '%s\0' "${created_dir}" >"${MKTEMP_RESULT_RECORD:?}"
printf '%s\n' "${created_dir}"
STUB
	chmod +x "${destination}"
}

write_go_preflight_stub() {
	local destination="$1"

	cat >"${destination}" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
	version)
		if [[ "${GO_FAIL_PHASE:-}" == "version" ]]; then
			exit 74
		fi
		exec "${REAL_GO:?}" "$@"
		;;
	list)
		if [[ "${GO_FAIL_PHASE:-}" == "list" ]]; then
			exit 75
		fi
		exec "${REAL_GO:?}" "$@"
		;;
	build)
		printf 'go-build-called\n' >"${GO_BUILD_MARKER:?}"
		exit 97
		;;
	*)
		exec "${REAL_GO:?}" "$@"
		;;
esac
STUB
	chmod +x "${destination}"
}

write_git_failure_stub() {
	local destination="$1"

	cat >"${destination}" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
args=("$@")
for ((index = 0; index + 1 < ${#args[@]}; index++)); do
	if [[ "${args[index]}" == "rev-parse" &&
		"${args[index + 1]}" == "HEAD" ]]; then
		exit 72
	fi
done
exec "${REAL_GIT:?}" "$@"
STUB
	chmod +x "${destination}"
}

write_uname_failure_stub() {
	local destination="$1"

	cat >"${destination}" <<'STUB'
#!/usr/bin/env bash
exit 73
STUB
	chmod +x "${destination}"
}

write_python_failure_stub() {
	local destination="$1"

	cat >"${destination}" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" -eq 1 && "$1" == "--version" ]]; then
	exit 76
fi
exec "${REAL_PYTHON:?}" "$@"
STUB
	chmod +x "${destination}"
}

observed_temporary_dir=""

assert_mktemp_contract() {
	local args_record="$1"
	local result_record="$2"
	local configured_tmpdir="$3"
	local label="$4"
	local expected_template="${configured_tmpdir}/candidate-codec-interop.XXXXXXXXXX"
	local -a received_args=()

	if [[ ! -f "${args_record}" || ! -f "${result_record}" ]]; then
		fail "${label} did not record mktemp arguments and result"
	fi

	mapfile -d '' -t received_args <"${args_record}"
	if ((${#received_args[@]} != 2)); then
		fail "${label} passed ${#received_args[@]} arguments to mktemp, want 2"
	fi
	if [[ "${received_args[0]}" != "-d" ]]; then
		fail "${label} did not pass -d to mktemp"
	fi
	if [[ "${received_args[1]}" != "${expected_template}" ]]; then
		fail "${label} passed an unexpected mktemp template: ${received_args[1]}"
	fi
	if [[ "${received_args[1]}" == /tmp/* ]]; then
		fail "${label} forced the mktemp template under /tmp"
	fi

	observed_temporary_dir=""
	IFS= read -r -d '' observed_temporary_dir <"${result_record}" ||
		fail "${label} recorded an ambiguous mktemp result"
	if [[ "${observed_temporary_dir}" != "${configured_tmpdir}/"* ]]; then
		fail "${label} mktemp result escaped configured TMPDIR: ${observed_temporary_dir}"
	fi
}

assert_directory_empty() {
	local directory="$1"
	local label="$2"

	if find "${directory}" -mindepth 1 -print -quit | grep -q .; then
		fail "${label} left residual files in ${directory}"
	fi
}

test_mktemp_failure_stops_before_go_build() {
	local scenario_dir="${test_root}/mktemp-failure"
	local fake_bin="${scenario_dir}/bin"
	local target_tmpdir="${scenario_dir}/target-tmp"
	local go_marker="${scenario_dir}/go-build-called"
	local output="${scenario_dir}/output"
	local before_state
	local status

	mkdir -p "${fake_bin}" "${target_tmpdir}"
	cat >"${fake_bin}/mktemp" <<'STUB'
#!/usr/bin/env bash
exit 71
STUB
	chmod +x "${fake_bin}/mktemp"
	write_go_preflight_stub "${fake_bin}/go"
	before_state="$(repository_state)"

	set +e
	GO_BUILD_MARKER="${go_marker}" \
		PATH="${fake_bin}:${PATH}" \
		REAL_GO="${real_go}" \
		TMPDIR="${target_tmpdir}" \
		bash "${target_script}" >"${output}" 2>&1
	status=$?
	set -e

	if ((status == 0)); then
		fail "mktemp failure returned success"
	fi
	if [[ -e "${go_marker}" ]]; then
		fail "go build ran after mktemp failure"
	fi
	assert_directory_empty "${target_tmpdir}" "mktemp failure"
	assert_repository_unchanged "${before_state}" "mktemp failure"
	printf 'ok - mktemp failure stops before go build\n'
}

test_preexisting_mktemp_directory_is_preserved() {
	local scenario_dir="${test_root}/mktemp-preexisting"
	local fake_bin="${scenario_dir}/bin"
	local target_tmpdir="${scenario_dir}/target-tmp"
	local preexisting_dir="${target_tmpdir}/candidate-codec-interop.ABCDEFGHIJ"
	local foreign_file="${preexisting_dir}/foreign-data"
	local args_record="${scenario_dir}/mktemp-args"
	local result_record="${scenario_dir}/mktemp-result"
	local go_marker="${scenario_dir}/go-build-called"
	local output="${scenario_dir}/output"
	local before_state
	local directory_metadata
	local file_metadata
	local foreign_content
	local status

	mkdir -p "${fake_bin}" "${preexisting_dir}"
	chmod 700 "${preexisting_dir}"
	printf 'foreign-content-must-survive\n' >"${foreign_file}"
	directory_metadata="$(stat -c '%u:%g:%a:%s:%y:%z' -- "${preexisting_dir}")"
	file_metadata="$(stat -c '%u:%g:%a:%s:%y:%z' -- "${foreign_file}")"
	foreign_content="$(<"${foreign_file}")"

	cat >"${fake_bin}/mktemp" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\0' "$@" >"${MKTEMP_ARGS_RECORD:?}"
printf '%s\0' "${PREEXISTING_DIR:?}" >"${MKTEMP_RESULT_RECORD:?}"
printf '%s\n' "${PREEXISTING_DIR}"
STUB
	chmod +x "${fake_bin}/mktemp"
	write_go_preflight_stub "${fake_bin}/go"
	before_state="$(repository_state)"

	set +e
	GO_BUILD_MARKER="${go_marker}" \
		MKTEMP_ARGS_RECORD="${args_record}" \
		MKTEMP_RESULT_RECORD="${result_record}" \
		PATH="${fake_bin}:${PATH}" \
		PREEXISTING_DIR="${preexisting_dir}" \
		REAL_GO="${real_go}" \
		TMPDIR="${target_tmpdir}" \
		bash "${target_script}" >"${output}" 2>&1
	status=$?
	set -e

	if ((status == 0)); then
		fail "preexisting mktemp directory was accepted"
	fi
	if [[ -e "${go_marker}" ]]; then
		fail "go build ran for a preexisting mktemp directory"
	fi
	if [[ ! -d "${preexisting_dir}" || ! -f "${foreign_file}" ]]; then
		fail "preexisting mktemp directory or foreign file was removed"
	fi
	if [[ -e "${preexisting_dir}/${sentinel_name}" ]]; then
		fail "ownership sentinel was written into preexisting directory"
	fi
	if [[ "$(<"${foreign_file}")" != "${foreign_content}" ||
	"$(stat -c '%u:%g:%a:%s:%y:%z' -- "${foreign_file}")" != "${file_metadata}" ||
	"$(stat -c '%u:%g:%a:%s:%y:%z' -- "${preexisting_dir}")" != "${directory_metadata}" ]]; then
		fail "preexisting directory data or metadata changed"
	fi
	assert_mktemp_contract \
		"${args_record}" "${result_record}" "${target_tmpdir}" \
		"preexisting mktemp directory"
	if [[ "${observed_temporary_dir}" != "${preexisting_dir}" ]]; then
		fail "preexisting mktemp stub returned an unexpected path"
	fi
	assert_repository_unchanged "${before_state}" "preexisting mktemp directory"
	printf 'ok - preexisting mktemp directory and foreign data are preserved\n'
}

test_preflight_failure_stops_before_go_build() {
	local phase="$1"
	local scenario_dir="${test_root}/${phase}"
	local fake_bin="${scenario_dir}/bin"
	local target_tmpdir="${scenario_dir}/target-tmp"
	local args_record="${scenario_dir}/mktemp-args"
	local result_record="${scenario_dir}/mktemp-result"
	local go_marker="${scenario_dir}/go-build-called"
	local output="${scenario_dir}/output"
	local go_fail_phase=""
	local before_state
	local status

	mkdir -p "${fake_bin}" "${target_tmpdir}"
	write_recording_mktemp "${fake_bin}/mktemp"
	write_go_preflight_stub "${fake_bin}/go"

	case "${phase}" in
	git-rev-parse)
		write_git_failure_stub "${fake_bin}/git"
		;;
	uname)
		write_uname_failure_stub "${fake_bin}/uname"
		;;
	go-version)
		go_fail_phase="version"
		;;
	python-version)
		write_python_failure_stub "${fake_bin}/python3"
		;;
	go-list)
		go_fail_phase="list"
		;;
	*)
		fail "unknown preflight failure phase: ${phase}"
		;;
	esac

	before_state="$(repository_state)"
	set +e
	GO_BUILD_MARKER="${go_marker}" \
		GO_FAIL_PHASE="${go_fail_phase}" \
		MKTEMP_ARGS_RECORD="${args_record}" \
		MKTEMP_RESULT_RECORD="${result_record}" \
		PATH="${fake_bin}:${PATH}" \
		REAL_GIT="${real_git}" \
		REAL_GO="${real_go}" \
		REAL_MKTEMP="${real_mktemp}" \
		REAL_PYTHON="${real_python}" \
		TMPDIR="${target_tmpdir}" \
		bash "${target_script}" >"${output}" 2>&1
	status=$?
	set -e

	if ((status == 0)); then
		fail "${phase} failure returned success"
	fi
	if [[ -e "${go_marker}" ]]; then
		fail "go build ran after ${phase} failure"
	fi
	assert_mktemp_contract \
		"${args_record}" "${result_record}" "${target_tmpdir}" \
		"${phase} failure"
	if [[ -e "${observed_temporary_dir}" ]]; then
		fail "temporary directory survived ${phase} failure: ${observed_temporary_dir}"
	fi
	assert_directory_empty "${target_tmpdir}" "${phase} failure"
	assert_repository_unchanged "${before_state}" "${phase} failure"
	printf 'ok - %s failure cleans and stops before go build\n' "${phase}"
}

test_external_tmpdir_is_cleaned_after_success() {
	local scenario_dir="${test_root}/external-tmpdir"
	local fake_bin="${scenario_dir}/bin"
	local target_tmpdir="${scenario_dir}/target-tmp"
	local args_record="${scenario_dir}/mktemp-args"
	local result_record="${scenario_dir}/mktemp-result"
	local output="${scenario_dir}/output"
	local before_state

	mkdir -p "${fake_bin}" "${target_tmpdir}"
	write_recording_mktemp "${fake_bin}/mktemp"
	before_state="$(repository_state)"

	MKTEMP_ARGS_RECORD="${args_record}" \
		MKTEMP_RESULT_RECORD="${result_record}" \
		PATH="${fake_bin}:${PATH}" \
		PYTHONDONTWRITEBYTECODE=1 \
		REAL_MKTEMP="${real_mktemp}" \
		TMPDIR="${target_tmpdir}" \
		bash "${target_script}" >"${output}" 2>&1

	if ! grep -Fq \
		'CANDIDATO NO NORMATIVO | interop | 5/5 seed fixtures matched byte for byte and repeated identically' \
		"${output}"; then
		fail "external TMPDIR scenario did not complete interoperability"
	fi
	assert_mktemp_contract \
		"${args_record}" "${result_record}" "${target_tmpdir}" \
		"external TMPDIR success"
	if [[ -e "${observed_temporary_dir}" ]]; then
		fail "temporary directory survived successful execution: ${observed_temporary_dir}"
	fi
	assert_directory_empty "${target_tmpdir}" "external TMPDIR success"
	assert_repository_unchanged "${before_state}" "external TMPDIR success"
	printf 'ok - non-/tmp TMPDIR uses exact mktemp arguments and leaves no residue\n'
}

scenario_count=0

run_scenario() {
	"$@"
	((scenario_count += 1))
}

run_scenario test_mktemp_failure_stops_before_go_build
run_scenario test_preexisting_mktemp_directory_is_preserved
run_scenario test_preflight_failure_stops_before_go_build git-rev-parse
run_scenario test_preflight_failure_stops_before_go_build uname
run_scenario test_preflight_failure_stops_before_go_build go-version
run_scenario test_preflight_failure_stops_before_go_build python-version
run_scenario test_preflight_failure_stops_before_go_build go-list
run_scenario test_external_tmpdir_is_cleaned_after_success

printf 'CANDIDATO NO NORMATIVO | shell regression | %d/%d scenarios passed\n' \
	"${scenario_count}" "${scenario_count}"
