#!/bin/sh
# Xcode Run Script phase "Bundle Native Binaries" of the Runner target.
#
# Copies the native parts of the office and PDF editors from the binaries
# layer (the tom_binaries clone) into the application bundle, so a release
# started from the Finder (no TOM_BINARY_PATH) finds them there
# (tom_basics' TomNativeBinaries looks in the bundle first):
#
#   Contents/MacOS/tom_office_host               <tom_binaries>/tom/darwin-arm64/
#   Contents/MacOS/libtom_office_host_lok.dylib  <tom_binaries>/tom/darwin-arm64/
#   Contents/Frameworks/libpdfium.dylib          <tom_binaries>/pdfium/darwin-arm64/
#   Contents/Resources/pdfium.version.json       <tom_binaries>/pdfium/darwin-arm64/
#   Contents/Resources/licenses/pdfium/          <tom_binaries>/pdfium/darwin-arm64/LICENSE, licenses/
#
# The tom_binaries clone: TOM_BINARIES_ROOT (environment or build setting),
# else the parent of TOM_BINARY_PATH, else the clone beside tom_forge in the
# agent container (repos.yaml: tom_agent_container/tom_binaries).
#
# Release and Profile builds copy and fail when a binary is missing. Debug
# builds skip (flutter run finds the binaries through TOM_BINARY_PATH, so a
# rebuilt helper is picked up without rebuilding the app) unless
# TOM_BUNDLE_NATIVE_BINARIES=YES.
#
# Each binary is copied to a new file, signed ad hoc and renamed into place:
# overwriting a signed executable in place leaves the kernel's cached
# signature stale and later starts hang. Xcode signs the app afterwards.
set -eu

case "${TOM_BUNDLE_NATIVE_BINARIES:-}" in
  YES|yes|1) ;;
  NO|no|0)
    echo "Bundle Native Binaries: skipped (TOM_BUNDLE_NATIVE_BINARIES=${TOM_BUNDLE_NATIVE_BINARIES})"
    exit 0
    ;;
  *)
    if [ "${CONFIGURATION}" = "Debug" ]; then
      echo "Bundle Native Binaries: skipped for Debug (set TOM_BUNDLE_NATIVE_BINARIES=YES to bundle)"
      exit 0
    fi
    ;;
esac

if [ -n "${TOM_BINARIES_ROOT:-}" ]; then
  root="${TOM_BINARIES_ROOT}"
elif [ -n "${TOM_BINARY_PATH:-}" ]; then
  root="$(dirname "${TOM_BINARY_PATH}")"
else
  root="${PROJECT_DIR}/../../../tom_binaries"
fi

platform="darwin-arm64"
tom_dir="${root}/tom/${platform}"
pdfium_dir="${root}/pdfium/${platform}"

missing=""
for f in "${tom_dir}/tom_office_host" \
         "${tom_dir}/libtom_office_host_lok.dylib" \
         "${pdfium_dir}/libpdfium.dylib" \
         "${pdfium_dir}/pdfium.version.json"; do
  [ -f "$f" ] || missing="${missing} ${f}"
done
if [ -n "${missing}" ]; then
  echo "error: Bundle Native Binaries: missing in the binaries layer (${root}):${missing}" >&2
  echo "error: set TOM_BINARIES_ROOT to the tom_binaries clone, or TOM_BUNDLE_NATIVE_BINARIES=NO to build without them" >&2
  exit 1
fi

app="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
macos_dir="${app}/Contents/MacOS"
frameworks_dir="${app}/Contents/Frameworks"
resources_dir="${app}/Contents/Resources"
mkdir -p "${macos_dir}" "${frameworks_dir}" "${resources_dir}"

# install_signed <source> <destination folder> <identifier>
install_signed() {
  name="$(basename "$1")"
  tmp="$2/.${name}.bundling.$$"
  rm -f "${tmp}"
  cp -p "$1" "${tmp}"
  chmod 755 "${tmp}"
  codesign --force --sign - --identifier "$3" "${tmp}"
  mv -f "${tmp}" "$2/${name}"
  echo "Bundle Native Binaries: $2/${name}"
}

install_signed "${tom_dir}/tom_office_host" "${macos_dir}" "tom_office_host"
install_signed "${tom_dir}/libtom_office_host_lok.dylib" "${macos_dir}" "libtom_office_host_lok"
install_signed "${pdfium_dir}/libpdfium.dylib" "${frameworks_dir}" "libpdfium"

cp -p "${pdfium_dir}/pdfium.version.json" "${resources_dir}/pdfium.version.json"
rm -rf "${resources_dir}/licenses/pdfium"
mkdir -p "${resources_dir}/licenses/pdfium"
[ -f "${pdfium_dir}/LICENSE" ] && cp -p "${pdfium_dir}/LICENSE" "${resources_dir}/licenses/pdfium/LICENSE"
[ -d "${pdfium_dir}/licenses" ] && cp -Rp "${pdfium_dir}/licenses/." "${resources_dir}/licenses/pdfium/"
echo "Bundle Native Binaries: from ${root}"
