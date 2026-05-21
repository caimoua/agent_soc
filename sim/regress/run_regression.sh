#!/usr/bin/env bash
set -u

suite="smoke"
dry_run=0
keep_going=0
build_software=0
make_cmd="make"
list_path=""

usage() {
  cat <<'USAGE'
Usage: ./regress/run_regression.sh [options]

Options:
  --suite <name>   smoke, core, cache, ahb, mmio, soc, isa, agent, or full. Default: smoke
  --dry-run        Print selected make commands without running VCS
  --keep-going     Continue after a failed test
  --build-software Run make -C software before launching simulations
  --make <cmd>     Make command to use. Default: make
  --list <path>    Regression list path. Default: regress/regression_list.txt
  -h, --help       Show this help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --suite)
      suite="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --keep-going)
      keep_going=1
      shift
      ;;
    --build-software)
      build_software=1
      shift
      ;;
    --make)
      make_cmd="$2"
      shift 2
      ;;
    --list)
      list_path="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sim_dir="$(cd "$script_dir/.." && pwd)"
repo_dir="$(cd "$sim_dir/.." && pwd)"
if [ -z "$list_path" ]; then
  list_path="$script_dir/regression_list.txt"
fi

if [ ! -f "$list_path" ]; then
  echo "ERROR: missing regression list: $list_path" >&2
  exit 2
fi

case "$suite" in
  smoke|core|cache|ahb|mmio|soc|isa|agent|full) ;;
  *)
    echo "ERROR: unsupported suite: $suite" >&2
    exit 2
    ;;
esac

stamp="$(date +%Y%m%d_%H%M%S)"
run_dir="$sim_dir/log/regress/$stamp-$suite"
selected_count="$(awk -F'|' -v suite="$suite" '
  /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
  {
    split($4, tags, ",")
    for (i in tags) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", tags[i])
      if (tags[i] == suite) {
        count++
        break
      }
    }
  }
  END { print count + 0 }
' "$list_path")"

if [ "$selected_count" -eq 0 ]; then
  echo "ERROR: no tests selected for suite '$suite'" >&2
  exit 2
fi

echo "Regression suite : $suite"
echo "Selected tests   : $selected_count"
echo "Simulation dir   : $sim_dir"
echo "Run log dir      : $run_dir"
echo

if [ "$dry_run" -eq 0 ]; then
  mkdir -p "$run_dir"
fi

required_images=(
  "software/bin/ahb_matrix_soc.memh"
  "software/bin/ahb_matrix_apb_soc.memh"
  "software/bin/cached_system_smoke.memh"
  "software/bin/cached_ahb_master.memh"
  "software/bin/cached_uart.memh"
  "software/bin/cached_timer.memh"
  "software/bin/cached_timer_irq.memh"
  "software/bin/cached_access_fault.memh"
  "software/bin/cached_instr_access_fault.memh"
  "software/bin/cached_misaligned_trap.memh"
  "software/bin/pipe_branch_predict.memh"
  "software/bin/pipe_dynamic_branch_predict.memh"
  "software/bin/pipe_branch_predict_param.memh"
  "software/bin/pipe_muldiv.memh"
  "software/bin/isa_basic.memh"
  "software/bin/pipe_core.memh"
  "software/bin/trap_csr.memh"
  "software/bin/core_smoke.memh"
  "software/bin/pipe_icache.memh"
  "software/bin/pipe_dcache.memh"
  "software/bin/pipe_cached_bus.memh"
)

if [ "$build_software" -eq 1 ]; then
  echo "Software build   : $make_cmd -C software"
  if [ "$dry_run" -eq 0 ]; then
    (cd "$repo_dir" && "$make_cmd" -C software check-tools) 2>&1 | tee "$run_dir/software_check_tools.log"
    check_exit="${PIPESTATUS[0]}"
    if [ "$check_exit" -ne 0 ]; then
      echo "ERROR: software toolchain check failed with exit code $check_exit" >&2
      echo "Hint: export PATH to riscv-none-elf-gcc, set TOOLCHAIN_PREFIX/RISCV_CC/RISCV_OBJCOPY, or rerun without --build-software if MEMH files already exist." >&2
      exit "$check_exit"
    fi
    (cd "$repo_dir" && "$make_cmd" -C software) 2>&1 | tee "$run_dir/software_build.log"
    build_exit="${PIPESTATUS[0]}"
    if [ "$build_exit" -ne 0 ]; then
      echo "ERROR: software image build failed with exit code $build_exit" >&2
      exit "$build_exit"
    fi
  fi
  echo
fi

if [ "$dry_run" -eq 0 ]; then
  for image in "${required_images[@]}"; do
    if [ ! -f "$repo_dir/$image" ]; then
      echo "ERROR: missing software image: $image" >&2
      echo "Run with --build-software or run 'make -C software'." >&2
      exit 2
    fi
  done
fi

failures=()
index=0

cd "$sim_dir" || exit 2

while IFS='|' read -r name tb_file top_name suites plusargs; do
  trimmed_name="${name//[[:space:]]/}"
  if [ -z "$trimmed_name" ] || [[ "$trimmed_name" == \#* ]]; then
    continue
  fi

  matched=0
  IFS=',' read -ra tags <<< "$suites"
  for tag in "${tags[@]}"; do
    tag="${tag#"${tag%%[![:space:]]*}"}"
    tag="${tag%"${tag##*[![:space:]]}"}"
    if [ "$tag" = "$suite" ]; then
      matched=1
      break
    fi
  done
  if [ "$matched" -eq 0 ]; then
    continue
  fi

  index=$((index + 1))
  cmd=("$make_cmd" "sim" "TB_FILE=$tb_file" "TOP_NAME=$top_name")
  if [ -n "${plusargs:-}" ]; then
    cmd+=("SIM_PLUSARGS=$plusargs")
  fi

  echo "[$index/$selected_count] $name"
  printf '  '
  printf '%q ' "${cmd[@]}"
  echo

  if [ "$dry_run" -eq 1 ]; then
    continue
  fi

  run_log="$run_dir/$name.run.log"
  "${cmd[@]}" 2>&1 | tee "$run_log"
  exit_code="${PIPESTATUS[0]}"

  [ -f "$sim_dir/log/compile.log" ] && cp "$sim_dir/log/compile.log" "$run_dir/$name.compile.log"
  [ -f "$sim_dir/log/sim.log" ] && cp "$sim_dir/log/sim.log" "$run_dir/$name.sim.log"

  if [ "$exit_code" -ne 0 ]; then
    echo "  FAIL: exit code $exit_code"
    failures+=("$name")
    if [ "$keep_going" -eq 0 ]; then
      break
    fi
  else
    echo "  PASS"
  fi
  echo
done < "$list_path"

echo
if [ "${#failures[@]}" -eq 0 ]; then
  if [ "$dry_run" -eq 1 ]; then
    echo "Dry run complete. No simulations were launched."
  else
    echo "Regression PASS: $suite"
    echo "Logs: $run_dir"
  fi
  exit 0
fi

echo "Regression FAIL: $suite"
echo "Failed tests:"
for failure in "${failures[@]}"; do
  echo "  $failure"
done
echo "Logs: $run_dir"
exit 1
