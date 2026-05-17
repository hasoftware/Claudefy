# Claudefy

Bộ công cụ cá nhân hoá Claude Code cho cả Windows, Linux và macOS. Một lần cài đặt cho mọi máy mới, không cần ghi chú lại từng bước.

```
   ____ _                 _       __
  / ___| | __ _ _   _  __| | ___ / _|_   _
 | |   | |/ _`| | | |/ _`|/ _ \ |_| | | |
 | |___| | (_| | |_| | (_| |  __/  _| |_| |
  \____|_|\__,_|\__,_|\__,_|\___|_|  \__, |
                                     |___/

       Claudefy v1.0.1  -  make Claude Code yours.
```

## Claudefy là gì

Claudefy là tập hợp script biến thanh trạng thái mặc định của Claude Code thành một bảng điều khiển hai dòng đầy đủ thông tin lập trình, kèm thông báo khi Claude phản hồi xong, tự đặt tên tab terminal theo project, mười theme màu chọn sẵn (chỉ Windows), và một danh sách cho phép lệnh đọc an toàn để bớt phải bấm xác nhận quyền.

Có thể hình dung Claudefy như phiên bản đã trang điểm của Claude Code. Cài một lần, mỗi project bạn mở thanh thông tin sẽ tự đổi theo.

## Demo thanh statusLine

Khi đang code trong một project Node.js có git, bạn sẽ thấy hai dòng như sau ở dưới khung chat Claude Code:

```
 my-project    main 12  3d   Node 22.19.0    #42    Opus 4.7   01:33 ICT (46m)
 Context: 84%    5h: 24% 05:40    7d: 17%    $8.42    +616 -215    164.3k
```

Dòng một là nơi bạn đang ở:

| Vị trí | Ý nghĩa |
|---|---|
| my-project | Tên thư mục project |
| main 12 3d | Branch hiện tại, 12 file thay đổi chưa commit, commit gần nhất cách đây 3 ngày |
| Node 22.19.0 | Runtime tự nhận theo manifest |
| #42 | Pull request số 42 đang mở, dấu chọn nghĩa là CI pass |
| Opus 4.7 | Model Claude đang dùng |
| 01:33 ICT (46m) | Đồng hồ Hà Nội và thời lượng session |

Dòng hai là chi phí đã tiêu:

| Vị trí | Ý nghĩa |
|---|---|
| Context: 84% | Cửa sổ context còn lại |
| 5h: 24% 05:40 | Quota 5 tiếng và giờ reset |
| 7d: 17% | Quota 7 ngày |
| $8.42 | Chi phí session hiện tại |
| +616 -215 | Số dòng đã thêm và xoá |
| 164.3k | Tổng số token |

Màu sắc tự đổi theo ngưỡng. Dưới 50 phần trăm là xanh, từ 50 tới 80 phần trăm là cam, trên 80 phần trăm là đỏ.

## Tính năng

- Thanh statusLine 2-3 dòng với Powerline, runtime, git, PR, CI, quota, cost, tokens, đồng hồ Hà Nội (dòng 3 hiện tổng dòng code + framework + tỉ lệ code khi đã cài [DevRadar](https://github.com/hasoftware/DevRadar) qua `npm install -g devradar`)
- Hook Stop: chuông và toast notification khi Claude trả lời xong, kèm cảnh báo gấp khi quota gần hết
- Hook SessionStart: tab terminal tự đổi tên thành tên project
- Mười theme màu chọn sẵn (chỉ Windows): One Half Dark, Dracula, Tokyo Night, Catppuccin Mocha, Nord, Solarized Dark, Gruvbox Dark, Monokai, Synthwave 84, GitHub Dark
- Allowlist khoảng năm mươi lệnh đọc an toàn để bớt bấm xác nhận quyền
- MCP server sequential-thinking để Claude suy nghĩ có cấu trúc hơn
- Tự cài JetBrainsMono Nerd Font qua winget, brew hoặc tải về thư mục font

## Cấu trúc repository

```
Claudefy/
  windows/        cho Windows 10 và 11, viết bằng PowerShell
  Linux/          cho mọi distro Linux, viết bằng bash
  MACOS/          cho macOS, viết bằng bash với Homebrew và osascript
```

Cả ba có chung tập tính năng cốt lõi. Khác biệt: cách cài font, cách hiện notification, và menu Theme chỉ có ở phiên bản Windows do mỗi terminal trên Linux và macOS có cách cấu hình màu khác nhau.

## Yêu cầu chung

- Claude Code CLI
- Một terminal hỗ trợ font Nerd Font (Windows Terminal, GNOME Terminal, iTerm2, Alacritty, Kitty)
- Khuyến nghị thêm: git, Node.js, gh CLI đã đăng nhập

Yêu cầu riêng cho từng nền tảng nằm trong README của từng thư mục con.

## Cài đặt

### Windows

```powershell
cd windows
.\Claudefy.ps1
```

Hoặc bấm hai lần vào Claudefy.cmd. Xem windows/README.md để biết chi tiết.

### Linux

```bash
cd Linux
chmod +x claudefy.sh install-claudefy.sh lib/*.sh
./claudefy.sh
```

Xem Linux/README.md để biết chi tiết.

### macOS

```bash
cd MACOS
chmod +x claudefy.sh install-claudefy.sh lib/*.sh
./claudefy.sh
```

Xem MACOS/README.md để biết chi tiết.

## Menu Claudefy

Trên Windows menu có bốn lựa chọn Install, Reset, Theme, About. Trên Linux và macOS menu có ba lựa chọn Install, Reset, About.

| Option | Hành động |
|---|---|
| Install | Cài đặt toàn bộ kit |
| Reset | Gỡ bỏ kit, giữ font và các trường khác trong settings.json |
| Theme | Đổi color scheme Windows Terminal (chỉ Windows) |
| About | Hiển thị thông tin phiên bản, file đã cài, tác giả |

## Tinh chỉnh

Mọi file Claudefy ghi ra đều nằm trong `~/.claude/` (Linux, macOS) hoặc `%USERPROFILE%\.claude\` (Windows). Trước khi sửa bất kỳ file nào, installer luôn tạo bản sao lưu với hậu tố `.backup-<dấu thời gian>`.

Để chỉnh ngưỡng cảnh báo, mở file `notify-stop.ps1` hoặc `notify-stop.sh` và sửa các biến `T_5H`, `T_7D`, `T_OPUS_7D`, `T_CONTEXT`, `T_COST_USD` ở đầu file.

Để đổi múi giờ hiển thị, mở file `statusline-command.*` và đổi giá trị `7` trong hai chỗ `AddHours(7)` (Windows) hoặc `25200` tức `7*3600` giây (Linux, macOS) sang múi giờ của bạn.

## Liên hệ

Tác giả: Hoàng Anh Dev

Admin: HASOFTWARE

Telegram: https://t.me/hasoftware

Repository: https://github.com/hasoftware/Claudefy

Bug hoặc đóng góp xin mở issue hoặc pull request trên repository. Trao đổi nhanh vào Telegram channel.

## Giấy phép

MIT License. Tự do dùng, sửa, phân phối, kể cả cho mục đích thương mại. Chỉ cần giữ lại file LICENSE.
