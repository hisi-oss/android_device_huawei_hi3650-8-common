#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=next
VENDOR=huawei

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        vendor/etc/camera/*|odm/etc/camera/*)
	    sed -i 's/gb2312/iso-8859-1/g' "${2}"
	    sed -i 's/GB2312/iso-8859-1/g' "${2}"
	    sed -i 's/xmlversion/xml version/g' "${2}"
            ;;
        vendor/etc/perfgenius_*)
            sed -i 's/version="2.0"/version="1.0"/g' "${2}"
            ;;
        vendor/lib*/egl/libGLES_mali.so|vendor/lib*/hw/gralloc.hi3650.so)
            "${PATCHELF}" --add-needed "libutilscallstack.so" "${2}"
            ;;
        vendor/lib64/hwcam/hwcam.hi3650.m.NEXT.so)
            "${PATCHELF}" --replace-needed "libskia.so" "libhwui.so" "${2}"
            "${PATCHELF}" --add-needed "libtinyxml2_shim.so" "${2}"
            # NOP out assertOk() and return_status()
            "${SIGSCAN}" -p "e0 43 01 91 44 51 fa 97" -P "e0 43 01 91 1f 20 03 d5" -f "${2}"
            "${SIGSCAN}" -p "e0 43 01 91 45 51 fa 97" -P "e0 43 01 91 1f 20 03 d5" -f "${2}"
            ;;
        vendor/lib*/hw/camera.hi3650.so)
            "${PATCHELF}" --replace-needed "libskia.so" "libhwui.so" "${2}"
            "${PATCHELF}" --add-needed "libui_shim.so" "${2}"
            ;;
        vendor/lib*/mediadrm/libwvdrmengine.so)
            "${PATCHELF}" --replace-needed "libprotobuf-cpp-lite.so" "libprotobuf-cpp-lite-v29.so" "${2}"
            ;;
        vendor/lib*/libwvhidl.so)
            "${PATCHELF}" --replace-needed "libprotobuf-cpp-lite.so" "libprotobuf-cpp-lite-v29.so" "${2}"
            ;;
        vendor/lib*/hw/vendor.huawei.hardware.hisupl@1.0-impl.so)
            # Respect the HMI's ID, which is hisupl
            sed -i 's|hisupl.hi1102|hisupl\x00\x00\x00\x00\x00\x00\x00|g' "${2}"
            ;;
        vendor/lib*/libiawareperf_server.so)
            "${PATCHELF}" --add-needed "libtinyxml2_shim.so" "${2}"
            ;;
        vendor/lib*/libperfhub_service.so)
            "${PATCHELF}" --add-needed "libtinyxml2_shim.so" "${2}"
            ;;
        vendor/lib*/libRefocusContrastPosition.so|vendor/lib*/libhwlog.so)
            "${PATCHELF}" --add-needed "libshim_log.so" "${2}"
            ;;
        vendor/lib*/soundfx/libhuaweiprocessing.so)
            "${PATCHELF}" --remove-needed "libicuuc.so" "${2}"
            ;;
        vendor/lib*/hw/flp.default.so)
            "${PATCHELF}" --remove-needed "libicuuc.so" "${2}"
            ;;
        vendor/lib*/hw/audio.primary.hi3650.so|vendor/lib*/libhivwservice.so)
	    "${PATCHELF}" --add-needed "libprocessgroup.so" "${2}"
	    ;;
        vendor/lib64/hw/hwcomposer.hi3650.so)
            # SetPartialUpdates()
            sed -i "s|\x78\xC8\xFF\x97\xE0\x03|\x1F\x20\x03\xD5\xE0\x03|g" "${2}"
            # CalcOverlapLayersNum()
            sed -i "s|\x7A\xC8\xFF\x97\x95\xC6|\x1F\x20\x03\xD5\x95\xC6|g" "${2}"
            # CalcLayerMaskRects()
            sed -i "s|\x77\xC8\xFF\x97\x88\x12|\x1F\x20\x03\xD5\x88\x12|g" "${2}"
            # HasDamageRegion()
            sed -i "s|\x90\xB6\xFF\x97\x60\x00|\x1F\x20\x03\xD5\x60\x00|g" "${2}"
            ;;
        vendor/bin/gpsdaemon)
            "${PATCHELF}" --remove-needed "libicuuc.so" "${2}"
            sed -i 's/\([Uu][Cc][Nn][Vv]_[A-Za-z_]*\)_58/\1_70/g' "${2}"
            ;;
        vendor/bin/hw/android.hardware.drm@1.0-service.widevine)
            "${PATCHELF}" --add-needed "libbase_shim.so" "${2}"
            ;;
        vendor/lib*/vendor.huawei.hardware.graphics.gpucommon@1.0.so)
            "${PATCHELF}" --add-needed "android.hardware.graphics.common@1.0_types.so" "${2}"
            ;;
        vendor/lib*/hw/vendor.huawei.hardware.sensors@1.0-impl.so)
            "${PATCHELF}" --add-needed "libbase_shim.so" "${2}"
            ;;
        vendor/lib*/vendor.huawei.hardware.radio@1.0.so)
            "${PATCHELF}" --add-needed "android.hardware.radio@1.0_types.so" "${2}"
            ;;
        vendor/bin/hw/vendor.huawei.hardware.gnss@1.0-service)
            "${PATCHELF}" --add-needed "libshim_hardware.so" "${2}"
            ;;
    esac
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
