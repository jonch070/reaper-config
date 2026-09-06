#!/bin/bash

echo "================================================="
echo "   CÀI ĐẶT AUDIO SEPARATOR CHO MAC VÀ LINUX      "
echo "================================================="
echo ""

# Kiểm tra xem python3 và pip đã được cài đặt chưa
if ! command -v python3 &> /dev/null
then
    echo "[LỖI] python3 không được tìm thấy. Bạn cần cài đặt Python 3 trước."
    echo "Tải Python tại: https://www.python.org/downloads/mac-osx/"
    echo ""
    read -p "Nhấn Enter để thoát..."
    exit
fi

echo "[1/2] Đang cập nhật pip..."
python3 -m pip install --upgrade pip

echo ""
echo "[2/2] Đang cài đặt thư viện 'audio-separator[cpu]'..."
python3 -m pip install "audio-separator[cpu]"

echo ""
echo "================================================="
echo "   CÀI ĐẶT HOÀN TẤT! BẠN CÓ THỂ ĐÓNG CỬA SỔ NÀY. "
echo "================================================="
echo ""

read -p "Nhấn Enter để đóng..."
