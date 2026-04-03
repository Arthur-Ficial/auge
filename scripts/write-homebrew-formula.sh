#!/usr/bin/env bash

set -euo pipefail

version=""
sha256=""
output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      version="${2:-}"
      shift 2
      ;;
    --sha256)
      sha256="${2:-}"
      shift 2
      ;;
    --output)
      output="${2:-}"
      shift 2
      ;;
    *)
      echo "usage: $0 --version <version> --sha256 <sha256> --output <path>" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$version" || -z "$sha256" || -z "$output" ]]; then
  echo "usage: $0 --version <version> --sha256 <sha256> --output <path>" >&2
  exit 1
fi

cat > "$output" <<EOF
class Auge < Formula
  desc "On-device Apple Vision CLI for OCR, classification, barcode, and face detection"
  homepage "https://github.com/Arthur-Ficial/auge"
  url "https://github.com/Arthur-Ficial/auge/releases/download/v${version}/auge-${version}-arm64-macos.tar.gz"
  sha256 "${sha256}"
  license "MIT"

  def install
    odie "auge requires Apple Silicon." unless Hardware::CPU.arm?

    bin.install "auge"
  end

  def caveats
    <<~EOS
      auge runs entirely on-device using Apple's Vision framework.
      No API keys or network access required.

      Verify with:
        auge --version
        auge --ocr /path/to/image.png
    EOS
  end

  test do
    assert_match "auge v${version}", shell_output("#{bin}/auge --version")
  end
end
EOF
