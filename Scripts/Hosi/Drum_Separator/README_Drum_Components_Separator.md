# 🥁 Hosi Drum Components Separator (MDX23C)

Công cụ trí tuệ nhân tạo (AI) chạy trực tiếp trong REAPER, giúp bạn bóc tách một track Drum Loop tổng thành các track thành phần chi tiết (Kick, Snare, Toms, Hi-Hat, Cymbals) cực kỳ sắc nét.

Công cụ giải phóng sức mạnh của mô hình mạng nơ-ron chuyên dụng **MDX23C DrumSep** (được tin dùng bởi Ultimate Vocal Remover), hoạt động mượt mà, độc lập ngay bên trong workflow của bạn.

---

## 🛠 1. Yêu Cầu Hệ Thống (Requirements)
- **REAPER** v6.0 trở lên.
- Extension **ReaImGui v0.10** (Cài đặt thông qua hệ thống ReaPack trong REAPER).
- **Python 3.9+**.

## ⚙️ 2. Hướng Dẫn Cài Đặt (Installation)

### Bươc 1: Đảm bảo máy tính có Python
Nếu máy bạn chưa cài đặt Python, hãy tải phiên bản mới nhất tại [python.org](https://www.python.org/downloads/). 
> 🚨 **Quan trọng:** Khi giao diện cài đặt Python hiện lên, bạn **BẮT BUỘC** phải tick vào ô `Add Python to PATH` (ở dưới cùng) trước khi nhấn Install.

### Bước 2: Tự động cài đặt thư viện AI (Chỉ cần 1 click)
Tìm đến file `Install_Drum_Separator.bat` đi kèm với bộ Script này và nhấp đúp để chạy nó.
- Tự động chạy cửa sổ cấp lệnh (Command Prompt).
- Ngồi đợi hệ thống tự tải các lõi `audio-separator` và `onnxruntime` về máy (Chừng 1-2 phút tuỳ mạng).
- Khi màn hình thả dòng chữ xanh "HOAN TAT!", bạn bấm phím bất kỳ để đóng.

### Bước 3: Đưa Script vào REAPER
1. Mở phần mềm REAPER.
2. Trên thanh menu trên cùng, chọn menu `Actions` -> Chọn `Show action list...`
3. Nhấp vào nút `New action...` -> `Load ReaScript...`
4. Dẫn tìm file `Hosi_Drum_Components_Separator.lua` và bấm Open.
5. Xong! Bạn có thể gắn phím tắt (Shortcut) cho nó nếu muốn.

---

## 🚀 3. Hướng Dẫn Sử Dụng
1. Nhấp đúp vào script vừa thêm trong danh sách Actions để gọi giao diện khởi động.
2. Trên màn hình làm việc (Timeline), **click để bôi sáng 1 Item âm thanh duy nhất** chứa toàn bộ Drum.
3. Kéo Script lại và nhấp thẳng vào nút vàng **SPLIT DRUM COMPONENTS**.

> ⚠️ *Lưu ý cực quan trọng: Ở TAY CHƠI ĐẦU TIÊN (Lần chạy đầu tiên), màn hình quá trình sẽ đứng khựng ở mức 0% tương đối lâu (5-10 phút). Không phải lỗi đâu! Đây là lúc Audio-Separator đang tranh thủ download bộ não AI tạ (model MDX23C-DrumSep) nặng ~100MB từ đám mây xuống. Sau lần này, nó sẽ có sẵn trong máy và các lần chạy sau sẽ là OFFLINE siêu tốc độ.*

4. Sau khi dòng loading chạy vọt lên 100%, 5 kênh linh kiện rã xác (Kick, Snare, Toms, Hihat, Cymbals) sẽ được Auto-Load đệm thẳng xuống các dòng Tracks dưới, bám đúng khớp timeline với nhịp nhạc cũ. File gốc tự động được Mute đi.

Chúc bạn có những bản Mix đỉnh cao!
