# Claudefy

Bộ công cụ cá nhân hoá Claude Code dành cho người dùng Windows. Một lần cài đặt cho mọi máy mới, không cần ghi chú lại từng bước.

```
   ____ _                 _       __
  / ___| | __ _ _   _  __| | ___ / _|_   _
 | |   | |/ _`| | | |/ _`|/ _ \ |_| | | |
 | |___| | (_| | |_| | (_| |  __/  _| |_| |
  \____|_|\__,_|\__,_|\__,_|\___|_|  \__, |
                                     |___/

       Claudefy v1.0.0  -  make Claude Code yours.
```

## Claudefy là gì

Claudefy là một tập hợp script PowerShell biến thanh trạng thái mặc định của Claude Code thành một bảng điều khiển hai dòng đầy đủ thông tin lập trình, kèm theo thông báo khi Claude phản hồi xong, tự đặt tên tab terminal theo project, mười theme màu chọn sẵn, và một danh sách cho phép lệnh đọc an toàn để bớt phải bấm xác nhận quyền.

Có thể nghĩ Claudefy là phiên bản "đã trang điểm" cho Claude Code. Cài một lần, mỗi lần mở project khác nhau thanh thông tin sẽ tự đổi theo.

## Demo thanh statusLine

Khi đang code trong một project Node.js có git, bạn sẽ thấy hai dòng như sau ở dưới khung chat Claude Code:

```
 my-project    main 12  3d   Node 22.19.0    #42    Opus 4.7   01:33 ICT (46m)
 Context: 84%    5h: 24% 05:40    7d: 17%    $8.42    +616 -215    164.3k
```

Dòng một là "tôi đang ở đâu, làm với cái gì":

| Vị trí | Ý nghĩa |
|---|---|
| my-project | Tên thư mục project hiện tại |
| main 12 3d | Branch tên main, có 12 file thay đổi chưa commit, lần commit gần nhất cách đây 3 ngày |
| Node 22.19.0 | Runtime tự nhận theo manifest, hiện có hỗ trợ Node, Python, Rust, Go, .NET, Java, Ruby, Flutter |
| #42 | Pull request số 42 đang mở cho branch hiện tại, dấu chọn nghĩa là CI đã pass |
| Opus 4.7 | Model Claude đang dùng |
| 01:33 ICT (46m) | Đồng hồ Hà Nội và thời lượng session đã chạy |

Dòng hai là "đã tiêu bao nhiêu":

| Vị trí | Ý nghĩa |
|---|---|
| Context: 84% | Cửa sổ context còn lại bao nhiêu phần trăm |
| 5h: 24% 05:40 | Quota 5 tiếng đã dùng 24%, sẽ reset lúc 05:40 giờ Hà Nội |
| 7d: 17% | Quota 7 ngày đã dùng |
| $8.42 | Chi phí session hiện tại |
| +616 -215 | Số dòng đã thêm và xoá trong session |
| 164.3k | Tổng số token đã tiêu |

Màu sắc tự thay đổi theo ngưỡng. Khi quota dưới 50% sẽ là xanh, 50% tới 80% là cam, trên 80% là đỏ. Khi context còn dưới 20% cũng sẽ đỏ.

## Tính năng đầy đủ

### Thanh statusLine hai dòng

Hiển thị mọi thứ cần biết về session hiện tại bằng các icon từ Nerd Font. Có hỗ trợ powerline với mũi tên nối các segment, nền các segment có màu nhẹ phân biệt. Mỗi block tự ẩn nếu không có dữ liệu, ví dụ block git chỉ hiện khi thư mục là git repo, block PR chỉ hiện khi branch có pull request mở.

### Thông báo khi Claude trả lời xong

Mỗi khi Claude kết thúc lượt trả lời, máy sẽ kêu một tiếng chuông và hiện toast notification ở góc màn hình. Bạn có thể đi pha cà phê hoặc làm việc khác, không cần dán mắt vào terminal chờ.

Khi quota gần hết hoặc chi phí vượt ngưỡng, thông báo sẽ kêu ba tiếng chuông liên tiếp kèm dòng chữ cảnh báo. Mặc định ngưỡng cảnh báo là 80% cho 5h, 7d, opus 7d; 10% còn lại cho context; 5 USD cho cost.

### Tên tab tự đổi theo project

Mỗi khi mở Claude Code trong một thư mục mới, tab Windows Terminal sẽ tự đổi tên thành "TenProject - Claude Code". Khi mở nhiều tab cùng lúc với nhiều project khác nhau, bạn nhìn vào title là biết tab nào của project nào.

Ví dụ khi mở Claude Code trong thư mục my-project, tab terminal sẽ hiện "my-project - Claude Code".

### Mười theme màu chọn sẵn

Trong menu Claudefy có mục Theme for Claude Code cho phép đổi color scheme của Windows Terminal sang một trong mười theme phổ biến nhất giới developer:

1. One Half Dark, theme cân bằng kiểu Atom
2. Dracula, tím và hồng nổi tiếng
3. Tokyo Night, xanh đậm tinh tế
4. Catppuccin Mocha, pastel ấm dịu mắt
5. Nord, xanh xám phong cách Scandinavia
6. Solarized Dark, classic độ tương phản cao
7. Gruvbox Dark, nâu retro ấm
8. Monokai, vibrant cổ điển
9. Synthwave 84, neon hồng cyan retro
10. GitHub Dark, hiện đại

### Danh sách cho phép lệnh đọc

Khoảng năm mươi lệnh đọc an toàn được thêm vào allowlist của Claude Code, ví dụ git status, git log, ls, cat, pip list, npm ls, gh pr view. Nhờ vậy khi Claude muốn chạy các lệnh này không phải bấm xác nhận từng lần. Các lệnh ghi hoặc nguy hiểm vẫn được hỏi xác nhận bình thường.

### MCP server suy nghĩ có cấu trúc

Tự động đăng ký sequential-thinking MCP server. Đây là một công cụ giúp Claude phân tích vấn đề phức tạp theo từng bước rõ ràng thay vì trả lời ngẫu hứng.

## Cấu trúc repository

Claudefy hỗ trợ ba hệ điều hành. Mỗi nền tảng có thư mục riêng chứa script được port phù hợp.

```
Claudefy/
  windows/        cho Windows 10 và 11, viết bằng PowerShell
  Linux/          cho Linux mọi distro, viết bằng bash
  MACOS/          cho macOS, viết bằng bash với Homebrew và osascript
  README.md       file này
  LICENSE
```

Tất cả các nền tảng đều có chung tập tính năng, chỉ khác cách cài font và cách hiển thị notification. Riêng menu Theme chỉ có ở phiên bản Windows do mỗi terminal trên Linux và macOS có cách cấu hình màu khác nhau.

## Yêu cầu hệ thống

Phần chung cho ba nền tảng:

| Bắt buộc | Mô tả |
|---|---|
| Claude Code CLI | Phần mềm chính, cài từ trang chủ Claude |
| Một terminal hỗ trợ font Nerd Font | Windows Terminal, GNOME Terminal, iTerm2, Alacritty, Kitty đều được |

Phần riêng từng nền tảng:

| Nền tảng | Yêu cầu thêm |
|---|---|
| Windows | PowerShell 7 trở lên, winget |
| Linux | jq, curl hoặc wget, unzip, fc-cache |
| macOS | jq, Homebrew (khuyến nghị để tự cài font) |

Khuyến nghị bổ sung cho cả ba nền tảng:

| Khuyến nghị | Mở khoá tính năng |
|---|---|
| git | Hiển thị block git trong statusLine |
| Node.js | Chạy MCP server sequential-thinking |
| gh CLI đã đăng nhập | Hiển thị block PR và CI status |

## Cài đặt

Chọn hướng dẫn theo hệ điều hành đang dùng.

### Windows

Vào thư mục windows trong repository, tải ba file Claudefy.ps1, Install-Claudefy.ps1, Claudefy.cmd, để chung một thư mục bất kỳ, sau đó bấm hai lần vào Claudefy.cmd. Menu chính sẽ hiện ra, chọn 1 để cài đặt.

Hoặc mở Windows Terminal và gõ:

```powershell
cd duongdan-toi-thumuc-windows
.\Claudefy.ps1
```

Chi tiết thêm trong windows/README.md.

### Linux

Vào thư mục Linux trong repository, tải toàn bộ thư mục về (gồm install-claudefy.sh, claudefy.sh và folder lib), sau đó chạy:

```bash
cd duongdan-toi-thumuc-Linux
chmod +x claudefy.sh install-claudefy.sh lib/*.sh
./claudefy.sh
```

Menu chính sẽ hiện ra, chọn 1 để cài đặt.

Hoặc bỏ qua menu, chạy installer trực tiếp:

```bash
./install-claudefy.sh
./install-claudefy.sh --skip-font
./install-claudefy.sh --skip-mcp
./install-claudefy.sh --force
```

Chi tiết thêm trong Linux/README.md.

### macOS

Vào thư mục MACOS trong repository, tải toàn bộ thư mục về, sau đó chạy:

```bash
cd duongdan-toi-thumuc-MACOS
chmod +x claudefy.sh install-claudefy.sh lib/*.sh
./claudefy.sh
```

Menu chính sẽ hiện ra, chọn 1 để cài đặt.

Trên macOS, installer sẽ dùng Homebrew để cài JetBrainsMono Nerd Font cask. Nếu chưa có Homebrew, cài trước tại brew.sh hoặc dùng cờ --skip-font rồi cài font bằng tay.

Chi tiết thêm trong MACOS/README.md.

## Sử dụng menu Claudefy

Menu Claudefy có cấu trúc nhất quán trên ba nền tảng, chỉ khác số lượng option do menu Theme chỉ có trên Windows.

Trên Windows, menu có bốn lựa chọn:

```
  Main Menu
  ------------------------------
    [1] Install Claudefy
    [2] Reset to Default
    [3] Theme for Claude Code
    [4] About

    [Q] Quit
```

Trên Linux và macOS, menu có ba lựa chọn (không có mục Theme):

```
  Main Menu
  ------------------------------
    [1] Install Claudefy
    [2] Reset to Default
    [3] About

    [Q] Quit
```

### Option 1, Install Claudefy

Chạy installer như đã mô tả ở trên.

### Option 2, Reset to Default

Gỡ bỏ tất cả thay đổi mà Claudefy đã thực hiện. Cụ thể:

- Xoá statusLine, SessionStart hook, Stop hook khỏi settings.json
- Xoá các lệnh trong allowlist mà Claudefy đã thêm
- Xoá ba file statusline-command.ps1, notify-stop.ps1, set-title.ps1
- Trả font Windows Terminal về mặc định
- Xoá các theme có tên bắt đầu bằng Claude

Để xác nhận thực sự muốn reset, bạn cần gõ chính xác chữ RESET viết hoa. Trước khi xoá, mọi file bị sửa đều được sao lưu với hậu tố .backup-<dấu thời gian>.

Không động vào:

- Font JetBrainsMono Nerd Font đã cài trên hệ thống
- MCP server đã đăng ký
- Các trường khác trong settings.json như language, theme, verbose

### Option 3, Theme for Claude Code

Hiện danh sách mười theme, kèm theo theme đang dùng đánh dấu sao. Bạn gõ số từ 1 đến 10 để chọn theme. Gõ 0 để xoá theme Claude và trở về mặc định của Windows Terminal. Sau khi chọn, đóng và mở lại Windows Terminal để thấy hiệu ứng.

### Option 4, About

Hiện thông tin phiên bản, các file kit đã cài, thông tin tác giả và liên hệ.

## Sao lưu và khôi phục

Mỗi lần script chạm vào một file, một bản sao lưu sẽ được tạo cùng thư mục với tên kiểu settings.json.backup-20260515-013300.

Để khôi phục một file về trạng thái cũ:

```powershell
Copy-Item settings.json.backup-20260515-013300 settings.json -Force
```

Tất cả backup nằm trong thư mục .claude của user. Không tự xoá định kỳ, bạn dọn tay khi cần.

## Cấu trúc thư mục sau khi cài

```
C:\Users\<ten>\.claude\
  settings.json               cấu hình Claude Code
  statusline-command.ps1      script render statusLine hai dòng
  notify-stop.ps1             script chạy khi Claude trả lời xong
  set-title.ps1               script đổi tên tab khi mở session
  *.backup-<timestamp>        bản sao lưu trước khi sửa
```

## Tinh chỉnh ngưỡng cảnh báo

Mở file notify-stop.ps1 trong thư mục .claude, các giá trị cấu hình nằm ở đầu file:

```powershell
$T_5H        = 80     # cảnh báo khi 5-hour quota trên 80%
$T_7D        = 80     # cảnh báo khi 7-day quota trên 80%
$T_OPUS_7D   = 80     # cảnh báo khi Opus 7-day trên 80%
$T_CONTEXT   = 10     # cảnh báo khi context còn dưới 10%
$T_COST_USD  = 5.0    # cảnh báo khi chi phí session vượt 5 USD
```

Đổi số rồi lưu file là xong, không cần cài lại.

## Đổi múi giờ trên thanh đồng hồ

Mặc định đồng hồ hiển thị giờ Hà Nội tức GMT+7. Nếu bạn ở múi giờ khác, sửa file statusline-command.ps1, tìm dòng AddHours(7) và đổi số 7 thành múi giờ của bạn.

Có hai chỗ cần đổi:

```powershell
$utc.AddHours(7)
```

Và:

```powershell
(Get-Date).ToUniversalTime().AddHours(7).ToString('HH:mm')
```

Cũng có thể đổi chữ ICT thành tên múi giờ của bạn.

## Câu hỏi thường gặp

### Sau khi cài, statusLine không hiện đầy đủ chữ và icon

Khả năng cao là Windows Terminal chưa được đổi font sang JetBrainsMono Nerd Font. Vào Settings của Windows Terminal, kiểm tra mục Profiles, Defaults, Appearance, Font Face có giá trị JetBrainsMono Nerd Font không. Nếu không, đổi lại bằng tay rồi đóng mở Windows Terminal.

### Block git, runtime, PR không hiện

Block git chỉ hiện khi thư mục hiện tại là git repo. Block runtime chỉ hiện khi có file package.json, pyproject.toml, Cargo.toml, go.mod, pubspec.yaml, csproj, sln, pom.xml, build.gradle hoặc Gemfile. Block PR chỉ hiện khi gh CLI đã đăng nhập và branch hiện tại có pull request mở trên GitHub.

### Tab title không đổi theo project

Hook SessionStart chỉ kích hoạt khi mở session mới. Nếu đang trong session cũ, hãy thoát Claude Code rồi mở lại.

### Thanh statusLine bị chậm

Block PR và CI mất khoảng 200 đến 500 mili giây mỗi lần gọi gh API. Claudefy đã cache 60 giây cho mỗi branch để giảm tải. Nếu vẫn chậm khó chịu, mở Claudefy.ps1 và tìm khối PR + CI status để gỡ ra. Hoặc đăng xuất gh CLI thì block PR sẽ tự ẩn.

### Cài lại nhiều lần có sao không

Script được thiết kế để idempotent, tức là chạy nhiều lần vẫn an toàn. Mỗi lần chạy đều backup trước nên không sợ mất config cũ.

### Linux và macOS có đầy đủ tính năng như Windows không

Gần đầy đủ. Các tính năng cốt lõi như statusLine hai dòng, hooks notification, hooks tự đặt tên tab, MCP server, allowlist permission đều giống nhau. Khác biệt:

- Trên Linux dùng notify-send để hiện notification, trên macOS dùng osascript display notification, trên Windows dùng OSC 9 toast của Windows Terminal.
- Menu Theme với mười color scheme chỉ có ở phiên bản Windows do Windows Terminal có file settings.json thống nhất. Trên Linux và macOS, mỗi terminal có cách cấu hình màu riêng nên không có menu Theme.
- Font trên Windows cài qua winget, trên macOS cài qua Homebrew cask, trên Linux tải từ GitHub release của nerd-fonts về thư mục font của user.

## Liên hệ

Tác giả: Hoàng Anh Dev

Admin của HASOFTWARE

Telegram channel: https://t.me/hasoftware

Repository: https://github.com/hasoftware/Claudefy

Nếu gặp bug hoặc muốn đóng góp, mở issue hoặc pull request trên repository. Nếu cần trao đổi nhanh, vào Telegram channel.

## Giấy phép

MIT License. Bạn được tự do dùng, sửa đổi, phân phối, kể cả cho mục đích thương mại. Chỉ cần giữ lại file LICENSE trong bản phân phối.
