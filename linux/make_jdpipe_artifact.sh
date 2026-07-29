#!/bin/bash
set -euo pipefail

: "${PANDOC_SOURCE_REVISION:?PANDOC_SOURCE_REVISION is required}"
: "${TEXMATH_SOURCE_REVISION:?TEXMATH_SOURCE_REVISION is required}"
: "${SOURCE_DATE_EPOCH:?SOURCE_DATE_EPOCH is required}"
: "${JDPIPE_INDEX_STATE:?JDPIPE_INDEX_STATE is required}"
: "${CABALOPTS:?CABALOPTS is required}"

ARTIFACTS_DIR=${ARTIFACTS_DIR:-/artifacts}
BUILD_ROOT=$(mktemp -d)

cabal update
# CABALOPTS is intentionally expanded into individual Cabal arguments.
# shellcheck disable=SC2086
cabal build $CABALOPTS pandoc-cli
# shellcheck disable=SC2086
BINPATH=$(cabal list-bin $CABALOPTS pandoc-cli)

case "$(uname -m)" in
  x86_64) ARCHITECTURE=amd64 ;;
  aarch64) ARCHITECTURE=arm64 ;;
  i686 | i386) ARCHITECTURE=i386 ;;
  armv6l | armv7l) ARCHITECTURE=armhf ;;
  riscv64) ARCHITECTURE=riscv64 ;;
  loongarch64) ARCHITECTURE=loong64 ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

PANDOC_VERSION=$("$BINPATH" --version | awk 'NR == 1 {print $2}')
SHORT_REVISION=${PANDOC_SOURCE_REVISION:0:9}
PACKAGE_NAME="pandoc-jdpipe-${PANDOC_VERSION}+git.${SHORT_REVISION}-linux-${ARCHITECTURE}"
PACKAGE_ROOT="$BUILD_ROOT/$PACKAGE_NAME"
PACKAGE_BIN="$PACKAGE_ROOT/bin/pandoc-jdpipe"
DOC_DIR="$PACKAGE_ROOT/share/doc/pandoc-jdpipe"

install -Dm755 "$BINPATH" "$PACKAGE_BIN"
strip "$PACKAGE_BIN"
install -Dm644 COPYRIGHT "$DOC_DIR/COPYRIGHT"

{
  printf 'distribution: pandoc-jdpipe\n'
  printf 'pandoc-version: %s\n' "$PANDOC_VERSION"
  printf 'pandoc-commit: %s\n' "$PANDOC_SOURCE_REVISION"
  printf 'texmath-commit: %s\n' "$TEXMATH_SOURCE_REVISION"
  printf 'architecture: %s\n' "$ARCHITECTURE"
  printf 'source-date-epoch: %s\n' "$SOURCE_DATE_EPOCH"
  printf 'hackage-index-state: %s\n' "$JDPIPE_INDEX_STATE"
  printf 'builder-image: %s\n' "${JDPIPE_BUILDER_IMAGE:-unknown}"
} > "$DOC_DIR/BUILDINFO"

echo "Checking that the executable is statically linked"
file "$PACKAGE_BIN" | grep -q 'statically linked'
if readelf -l "$PACKAGE_BIN" | grep -q 'INTERP'; then
  echo "Static executable unexpectedly contains an ELF interpreter" >&2
  exit 1
fi
if readelf -d "$PACKAGE_BIN" 2>/dev/null | grep -q '(NEEDED)'; then
  echo "Static executable unexpectedly contains shared-library dependencies" >&2
  exit 1
fi

echo "Checking embedded features and data files"
"$PACKAGE_BIN" --version | grep -q '+server +lua'
(cd /tmp && "$PACKAGE_BIN" --print-default-template=html >/dev/null)

COMMONMARK_EXTENSIONS=$("$PACKAGE_BIN" --list-extensions=commonmark_x | sed 's/^[+-]//')
LATEX_EXTENSIONS=$("$PACKAGE_BIN" --list-extensions=latex | sed 's/^[+-]//')

require_extension() {
  local extension=$1
  local available=$2
  local format=$3
  if ! grep -Fxq "$extension" <<< "$available"; then
    echo "Required $format extension is missing: $extension" >&2
    exit 1
  fi
}

for extension in citations figure_divs table_divs equation_divs sourcepos_sparse; do
  require_extension "$extension" "$COMMONMARK_EXTENSIONS" commonmark_x
done
require_extension cell_tabulars "$LATEX_EXTENSIONS" latex

echo "Smoke-testing the patched readers"
printf '%s\n' \
  'See [@fig:sample].' \
  '' \
  '::: {#fig:sample .figure}' \
  '![Sample](sample.png)' \
  ':::' | \
  "$PACKAGE_BIN" \
    -f commonmark_x+citations+figure_divs+table_divs+equation_divs+sourcepos_sparse \
    -t native >/dev/null
printf '%s\n' '\begin{tabular}{c}x\end{tabular}' | \
  "$PACKAGE_BIN" -f latex+cell_tabulars -t native >/dev/null

mkdir -p "$ARTIFACTS_DIR"
ARCHIVE_NAME="$PACKAGE_NAME.tar.gz"
tar \
  --sort=name \
  --mtime="@$SOURCE_DATE_EPOCH" \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  -C "$BUILD_ROOT" \
  -cf - "$PACKAGE_NAME" | gzip -n > "$ARTIFACTS_DIR/$ARCHIVE_NAME"

(
  cd "$ARTIFACTS_DIR"
  sha256sum "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
)

echo "Created artifacts:"
ls -lh "$ARTIFACTS_DIR/$ARCHIVE_NAME" "$ARTIFACTS_DIR/$ARCHIVE_NAME.sha256"
