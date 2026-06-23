#!/usr/bin/env bash
# # modules/system/modules/cuda-tools/cuda_tools.sh 

cuda_tools_install() {
    echo "CUDA-TOOLKIT module"
    echo
    echo "[CUDA-TOOLS] WARNING: install CUDA toolkit"
    echo "[CUDA-TOOLS] This will ~2GB disk space"
    echo

    if [[ "${FORCE:-0}" != "1" ]]; then
        read -rp "Do you really want to continue? [y/N]: " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || {
            echo "[CUDA-TOOLS] Cancelled"
            return 1
        }
    fi

    apt update
    apt install -y nvidia-cuda-toolkit
}

cuda_tools_remove() {
    echo "CUDA-TOOLKIT module"
    echo
    echo "[CUDA-TOOLS] WARNING: uninstall CUDA toolkit"
    echo "[CUDA-TOOLS] This will free ~2GB disk space"
    echo

    if [[ "${FORCE:-0}" != "1" ]]; then
        read -rp "Do you really want to continue? [y/N]: " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || {
            echo "[CUDA-TOOLS] Cancelled"
            return 1
        }
    fi

    apt remove -y nvidia-cuda-toolkit
}

cuda_tools_check() {
    if command -v nvcc &>/dev/null; then
        echo "CUDA-TOOLKIT module"
        echo
        echo "[CUDA-TOOLS] CUDA tools installed"
        return 0
    else
        echo "CUDA-TOOLKIT module"
        echo
        echo "[CUDA-TOOLS] Missing CUDA tools"
        return 1
    fi
}
