#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "Обновляем репозиторий..."
git pull --ff-only

echo "Пересобираем SRTLA..."
cd srtla
make clean
make -j$(nproc)

echo "Готово"
