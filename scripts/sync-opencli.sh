#!/usr/bin/env bash
set -euo pipefail

MODE="copy"
CLEAN="0"
REPO_ROOT=""
SOURCE_DIR=""
TARGET_DIR=""

log() {
  printf '[gequhai-sync] %s\n' "$1"
}

usage() {
  cat <<'EOF'
用法:
  bash ./scripts/sync-opencli.sh [--mode copy|symlink] [--clean] [--repo-root PATH] [--source-dir PATH] [--target-dir PATH]

参数:
  --mode        同步模式，默认 copy，可选 symlink
  --clean       copy 模式下先清空目标目录再同步
  --repo-root   指定仓库根目录；默认自动推导为脚本上一级目录
  --source-dir  指定 gequhai CLI 源目录；默认 <repo-root>/opencli/clis/gequhai
  --target-dir  指定 opencli 目标目录；默认 $HOME/.opencli/clis/gequhai
  -h, --help    显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --clean)
      CLEAN="1"
      shift
      ;;
    --repo-root)
      REPO_ROOT="${2:-}"
      shift 2
      ;;
    --source-dir)
      SOURCE_DIR="${2:-}"
      shift 2
      ;;
    --target-dir)
      TARGET_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf '未知参数: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$MODE" in
  copy|symlink) ;;
  *)
    printf '不支持的模式: %s\n' "$MODE" >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
fi
if [[ -z "$SOURCE_DIR" ]]; then
  SOURCE_DIR="$REPO_ROOT/opencli/clis/gequhai"
fi
if [[ -z "$TARGET_DIR" ]]; then
  TARGET_DIR="$HOME/.opencli/clis/gequhai"
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  printf '未找到源目录: %s\n' "$SOURCE_DIR" >&2
  exit 1
fi

TARGET_PARENT="$(dirname -- "$TARGET_DIR")"
mkdir -p "$TARGET_PARENT"

log "系统: $(uname -s)"
log "仓库根目录: $REPO_ROOT"
log "源目录: $SOURCE_DIR"
log "目标目录: $TARGET_DIR"
log "同步模式: $MODE"

if [[ "$MODE" == "copy" ]]; then
  mkdir -p "$TARGET_DIR"

  if [[ "$CLEAN" == "1" ]]; then
    log '清空目标目录中的现有文件'
    find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  fi

  log '复制 gequhai CLI 文件到 opencli 目录'
  cp -R "$SOURCE_DIR"/. "$TARGET_DIR"/
else
  if [[ -L "$TARGET_DIR" || -e "$TARGET_DIR" ]]; then
    log "删除已有目标: $TARGET_DIR"
    rm -rf "$TARGET_DIR"
  fi

  log '创建符号链接模式的目标目录'
  ln -s "$SOURCE_DIR" "$TARGET_DIR"
fi

log '同步完成。当前目标目录内容：'
ls -la "$TARGET_DIR"

printf '\n可用示例:\n'
printf '  bash ./scripts/sync-opencli.sh\n'
printf '  bash ./scripts/sync-opencli.sh --clean\n'
printf '  bash ./scripts/sync-opencli.sh --mode symlink\n'
