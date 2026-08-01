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

real_od="$(command -v od)"
readonly real_od

real_mkdir="$(command -v mkdir)"
readonly real_mkdir

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
readonly fixed_suffix="00112233445566778899"
readonly maximum_attempts=64

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

assert_directory_empty() {
	local directory="$1"
	local label="$2"

	if find "${directory}" -mindepth 1 -print -quit | grep -q .; then
		fail "${label} left residual files in ${directory}"
	fi
}

assert_no_candidate_directories() {
	local directory="$1"
	local label="$2"

	if find "${directory}" -mindepth 1 -maxdepth 1 \
		-name 'candidate-codec-interop.*' -print -quit | grep -q .; then
		fail "${label} left or adopted a candidate temporary directory"
	fi
}

assert_no_sentinel() {
	local directory="$1"
	local label="$2"

	if find "${directory}" -name "${sentinel_name}" -print -quit | grep -q .; then
		fail "${label} left or wrote an ownership sentinel"
	fi
}

assert_od_call_count() {
	local call_log="$1"
	local expected="$2"
	local label="$3"
	local -a calls=()

	if [[ -f "${call_log}" ]]; then
		mapfile -t calls <"${call_log}"
	fi
	if (("${#calls[@]}" != expected)); then
		fail "${label} made ${#calls[@]} suffix-generation calls, want ${expected}"
	fi
}

write_od_stub() {
	local destination="$1"

	cat >"${destination}" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if (($# != 5)) ||
	[[ "$1" != "-An" || "$2" != "-N" || "$3" != "10" ||
		"$4" != "-tx1" || "$5" != "/dev/urandom" ]]; then
	printf 'unexpected od invocation\n' >&2
	exit 98
fi
printf 'od\n' >>"${OD_CALL_LOG:?}"
if [[ "${OD_FAIL:-0}" == "1" ]]; then
	exit 71
fi
if [[ -n "${FIXED_SUFFIX:-}" ]]; then
	printf '%s\n' "${FIXED_SUFFIX}"
	exit 0
fi
exec "${REAL_OD:?}" "$@"
STUB
	chmod +x "${destination}"
}

write_mkdir_stub() {
	local destination="$1"

	cat >"${destination}" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if (($# != 3)) ||
	[[ "$1" != "--mode=700" || "$2" != "--" ||
		"$3" != "${EXPECTED_CANDIDATE:?}" ]]; then
	printf 'unexpected mkdir invocation\n' >&2
	exit 98
fi
printf '%s\n' "$3" >>"${MKDIR_CALL_LOG:?}"
if [[ "${MKDIR_FAIL:-0}" == "1" ]]; then
	exit 79
fi
exec "${REAL_MKDIR:?}" "$@"
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

test_random_generation_failure_stops_before_go_build() {
	local scenario_dir="${test_root}/random-generation-failure"
	local fake_bin="${scenario_dir}/bin"
	local target_tmpdir="${scenario_dir}/target-tmp"
	local od_call_log="${scenario_dir}/od-calls"
	local go_marker="${scenario_dir}/go-build-called"
	local output="${scenario_dir}/output"
	local before_state
	local status

	mkdir -p "${fake_bin}" "${target_tmpdir}"
	write_od_stub "${fake_bin}/od"
	write_go_preflight_stub "${fake_bin}/go"
	before_state="$(repository_state)"

	set +e
	GO_BUILD_MARKER="${go_marker}" \
		OD_CALL_LOG="${od_call_log}" \
		OD_FAIL=1 \
		PATH="${fake_bin}:${PATH}" \
		REAL_GO="${real_go}" \
		REAL_OD="${real_od}" \
		TMPDIR="${target_tmpdir}" \
		bash "${target_script}" >"${output}" 2>&1
	status=$?
	set -e

	if ((status == 0)); then
		fail "random generation failure returned success"
	fi
	if [[ -e "${go_marker}" ]]; then
		fail "go build ran after random generation failure"
	fi
	assert_od_call_count "${od_call_log}" 1 "random generation failure"
	assert_directory_empty "${target_tmpdir}" "random generation failure"
	assert_no_candidate_directories "${target_tmpdir}" "random generation failure"
	assert_no_sentinel "${target_tmpdir}" "random generation failure"
	assert_repository_unchanged "${before_state}" "random generation failure"
	printf 'ok - random generation failure stops before mkdir and go build\n'
}

test_preexisting_directory_is_preserved() {
	local variant="$1"
	local scenario_dir="${test_root}/preexisting-${variant}"
	local fake_bin="${scenario_dir}/bin"
	local target_tmpdir="${scenario_dir}/target-tmp"
	local preexisting_dir="${target_tmpdir}/candidate-codec-interop.${fixed_suffix}"
	local foreign_file="${preexisting_dir}/foreign-data"
	local od_call_log="${scenario_dir}/od-calls"
	local go_marker="${scenario_dir}/go-build-called"
	local output="${scenario_dir}/output"
	local before_state
	local directory_metadata
	local foreign_checksum=""
	local file_metadata=""
	local status

	mkdir -p "${fake_bin}" "${preexisting_dir}"
	chmod 700 "${preexisting_dir}"
	if [[ "${variant}" == "data" ]]; then
		printf 'foreign-content-must-survive\n' >"${foreign_file}"
		foreign_checksum="$(sha256sum -- "${foreign_file}")"
		file_metadata="$(stat -c '%u:%g:%a:%s:%y:%z' -- "${foreign_file}")"
	fi
	directory_metadata="$(stat -c '%u:%g:%a:%s:%y:%z' -- "${preexisting_dir}")"

	write_od_stub "${fake_bin}/od"
	write_go_preflight_stub "${fake_bin}/go"
	before_state="$(repository_state)"

	set +e
	FIXED_SUFFIX="${fixed_suffix}" \
		GO_BUILD_MARKER="${go_marker}" \
		OD_CALL_LOG="${od_call_log}" \
		PATH="${fake_bin}:${PATH}" \
		REAL_GO="${real_go}" \
		REAL_OD="${real_od}" \
		TMPDIR="${target_tmpdir}" \
		bash "${target_script}" >"${output}" 2>&1
	status=$?
	set -e

	if ((status == 0)); then
		fail "preexisting ${variant} directory was accepted"
	fi
	if [[ -e "${go_marker}" ]]; then
		fail "go build ran for a preexisting ${variant} directory"
	fi
	if [[ ! -d "${preexisting_dir}" ]]; then
		fail "preexisting ${variant} directory was removed"
	fi
	if [[ -e "${preexisting_dir}/${sentinel_name}" ]]; then
		fail "ownership sentinel was written into preexisting ${variant} directory"
	fi
	if [[ "$(stat -c '%u:%g:%a:%s:%y:%z' -- "${preexisting_dir}")" != "${directory_metadata}" ]]; then
		fail "preexisting ${variant} directory metadata changed"
	fi

	if [[ "${variant}" == "empty" ]]; then
		assert_directory_empty "${preexisting_dir}" "preexisting empty directory"
	else
		if [[ ! -f "${foreign_file}" ||
			"$(sha256sum -- "${foreign_file}")" != "${foreign_checksum}" ||
			"$(stat -c '%u:%g:%a:%s:%y:%z' -- "${foreign_file}")" != "${file_metadata}" ]]; then
			fail "preexisting foreign data or metadata changed"
		fi
	fi

	assert_od_call_count "${od_call_log}" "${maximum_attempts}" \
		"preexisting ${variant} directory"
	assert_repository_unchanged "${before_state}" \
		"preexisting ${variant} directory"
	printf 'ok - preexisting %s directory survives all collision attempts unchanged\n' \
		"${variant}"
}

test_mkdir_failure_stops_without_cleanup() {
	local scenario_dir="${test_root}/mkdir-failure"
	local fake_bin="${scenario_dir}/bin"
	local target_tmpdir="${scenario_dir}/target-tmp"
	local expected_candidate="${target_tmpdir}/candidate-codec-interop.${fixed_suffix}"
	local foreign_dir="${target_tmpdir}/unrelated"
	local foreign_file="${foreign_dir}/foreign-data"
	local od_call_log="${scenario_dir}/od-calls"
	local mkdir_call_log="${scenario_dir}/mkdir-calls"
	local go_marker="${scenario_dir}/go-build-called"
	local output="${scenario_dir}/output"
	local before_state
	local foreign_checksum
	local foreign_metadata
	local status

	mkdir -p "${fake_bin}" "${foreign_dir}"
	printf 'unrelated-data-must-survive\n' >"${foreign_file}"
	foreign_checksum="$(sha256sum -- "${foreign_file}")"
	foreign_metadata="$(stat -c '%u:%g:%a:%s:%y:%z' -- "${foreign_file}")"
	write_od_stub "${fake_bin}/od"
	write_mkdir_stub "${fake_bin}/mkdir"
	write_go_preflight_stub "${fake_bin}/go"
	before_state="$(repository_state)"

	set +e
	EXPECTED_CANDIDATE="${expected_candidate}" \
		FIXED_SUFFIX="${fixed_suffix}" \
		GO_BUILD_MARKER="${go_marker}" \
		MKDIR_CALL_LOG="${mkdir_call_log}" \
		MKDIR_FAIL=1 \
		OD_CALL_LOG="${od_call_log}" \
		PATH="${fake_bin}:${PATH}" \
		REAL_GO="${real_go}" \
		REAL_MKDIR="${real_mkdir}" \
		REAL_OD="${real_od}" \
		TMPDIR="${target_tmpdir}" \
		bash "${target_script}" >"${output}" 2>&1
	status=$?
	set -e

	if ((status == 0)); then
		fail "mkdir failure returned success"
	fi
	if [[ -e "${go_marker}" ]]; then
		fail "go build ran after mkdir failure"
	fi
	if [[ -e "${expected_candidate}" || -L "${expected_candidate}" ]]; then
		fail "mkdir failure left a candidate path"
	fi
	if [[ ! -f "${foreign_file}" ||
		"$(sha256sum -- "${foreign_file}")" != "${foreign_checksum}" ||
		"$(stat -c '%u:%g:%a:%s:%y:%z' -- "${foreign_file}")" != "${foreign_metadata}" ]]; then
		fail "mkdir failure cleaned or modified an unrelated path"
	fi
	assert_od_call_count "${od_call_log}" 1 "mkdir failure"
	if [[ "$(<"${mkdir_call_log}")" != "${expected_candidate}" ]]; then
		fail "mkdir failure stub recorded an unexpected candidate"
	fi
	assert_no_candidate_directories "${target_tmpdir}" "mkdir failure"
	assert_no_sentinel "${target_tmpdir}" "mkdir failure"
	assert_repository_unchanged "${before_state}" "mkdir failure"
	printf 'ok - non-collision mkdir failure stops without cleanup of foreign paths\n'
}

test_preflight_failure_stops_before_go_build() {
	local phase="$1"
	local scenario_dir="${test_root}/${phase}"
	local fake_bin="${scenario_dir}/bin"
	local target_tmpdir="${scenario_dir}/target-tmp"
	local od_call_log="${scenario_dir}/od-calls"
	local go_marker="${scenario_dir}/go-build-called"
	local output="${scenario_dir}/output"
	local go_fail_phase=""
	local before_state
	local status

	mkdir -p "${fake_bin}" "${target_tmpdir}"
	write_od_stub "${fake_bin}/od"
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
	FIXED_SUFFIX="${fixed_suffix}" \
		GO_BUILD_MARKER="${go_marker}" \
		GO_FAIL_PHASE="${go_fail_phase}" \
		OD_CALL_LOG="${od_call_log}" \
		PATH="${fake_bin}:${PATH}" \
		REAL_GIT="${real_git}" \
		REAL_GO="${real_go}" \
		REAL_OD="${real_od}" \
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
	assert_od_call_count "${od_call_log}" 1 "${phase} failure"
	assert_directory_empty "${target_tmpdir}" "${phase} failure"
	assert_no_candidate_directories "${target_tmpdir}" "${phase} failure"
	assert_no_sentinel "${target_tmpdir}" "${phase} failure"
	assert_repository_unchanged "${before_state}" "${phase} failure"
	printf 'ok - %s failure cleans and stops before go build\n' "${phase}"
}

test_external_tmpdir_is_cleaned_after_success() {
	local scenario_dir="${test_root}/external-tmpdir"
	local fake_bin="${scenario_dir}/bin"
	local target_tmpdir="${scenario_dir}/target-tmp"
	local expected_candidate="${target_tmpdir}/candidate-codec-interop.${fixed_suffix}"
	local od_call_log="${scenario_dir}/od-calls"
	local mkdir_call_log="${scenario_dir}/mkdir-calls"
	local output="${scenario_dir}/output"
	local before_state

	mkdir -p "${fake_bin}" "${target_tmpdir}"
	write_od_stub "${fake_bin}/od"
	write_mkdir_stub "${fake_bin}/mkdir"
	before_state="$(repository_state)"

	EXPECTED_CANDIDATE="${expected_candidate}" \
		FIXED_SUFFIX="${fixed_suffix}" \
		MKDIR_CALL_LOG="${mkdir_call_log}" \
		OD_CALL_LOG="${od_call_log}" \
		PATH="${fake_bin}:${PATH}" \
		PYTHONDONTWRITEBYTECODE=1 \
		REAL_MKDIR="${real_mkdir}" \
		REAL_OD="${real_od}" \
		TMPDIR="${target_tmpdir}" \
		bash "${target_script}" >"${output}" 2>&1

	if ! grep -Fq \
		'CANDIDATO NO NORMATIVO | interop | 5/5 seed fixtures matched byte for byte and repeated identically' \
		"${output}"; then
		fail "external TMPDIR scenario did not complete interoperability"
	fi
	assert_od_call_count "${od_call_log}" 1 "external TMPDIR success"
	if [[ "$(<"${mkdir_call_log}")" != "${expected_candidate}" ]]; then
		fail "external TMPDIR used an unexpected mkdir candidate"
	fi
	if [[ -e "${expected_candidate}" || -L "${expected_candidate}" ]]; then
		fail "temporary directory survived successful execution"
	fi
	assert_directory_empty "${target_tmpdir}" "external TMPDIR success"
	assert_no_candidate_directories "${target_tmpdir}" "external TMPDIR success"
	assert_no_sentinel "${target_tmpdir}" "external TMPDIR success"
	assert_repository_unchanged "${before_state}" "external TMPDIR success"
	printf 'ok - non-/tmp TMPDIR uses exclusive mkdir and leaves no residue\n'
}

scenario_count=0

run_scenario() {
	"$@"
	((scenario_count += 1))
}

run_scenario test_random_generation_failure_stops_before_go_build
run_scenario test_preexisting_directory_is_preserved empty
run_scenario test_preexisting_directory_is_preserved data
run_scenario test_mkdir_failure_stops_without_cleanup
run_scenario test_preflight_failure_stops_before_go_build git-rev-parse
run_scenario test_preflight_failure_stops_before_go_build uname
run_scenario test_preflight_failure_stops_before_go_build go-version
run_scenario test_preflight_failure_stops_before_go_build python-version
run_scenario test_preflight_failure_stops_before_go_build go-list
run_scenario test_external_tmpdir_is_cleaned_after_success

printf 'CANDIDATO NO NORMATIVO | shell regression | %d/%d scenarios passed\n' \
	"${scenario_count}" "${scenario_count}"
