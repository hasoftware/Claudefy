# Claudefy cho macOS

Phiên bản bash của Claudefy. Chạy trên macOS từ Big Sur trở lên (đã thử với macOS Sonoma và Sequoia).

## File trong thư mục này

| File | Mô tả |
|---|---|
| claudefy.sh | Menu chính với ba mục Install, Reset, About |
| install-claudefy.sh | Trình cài đặt all-in-one, có thể chạy độc lập không qua menu |
| lib/statusline-command.sh | Script render thanh statusLine (2 hoặc 3 dòng), copy vào ~/.claude. Dòng 3 (tổng dòng code + framework + tỉ lệ code) chỉ hiện nếu có DevRadar (`npm install -g @hasoftware/devradar`) |
| lib/notify-stop.sh | Hook Stop, phát chuông và toast notification qua osascript |
| lib/set-title.sh | Hook SessionStart, đặt tên tab terminal theo project |

## Yêu cầu

- macOS 11 Big Sur trở lên
- bash 3.2 mặc định của macOS hoặc bash 5 cài qua Homebrew
- Claude Code CLI
- jq để parse JSON. Cài: `brew install jq`
- Homebrew để tự cài font. Cài tại brew.sh

Khuyến nghị thêm: git, node, gh CLI (đều cài được qua brew).

## Cài đặt

Tải toàn bộ thư mục MACOS từ repository về máy. Cấp quyền thực thi và chạy:

```bash
cd duongdan-toi-thumuc-MACOS
chmod +x claudefy.sh install-claudefy.sh lib/*.sh
./claudefy.sh
```

Menu sẽ hiện ra, chọn 1 để cài đặt.

Hoặc bỏ qua menu, chạy thẳng installer:

```bash
./install-claudefy.sh
./install-claudefy.sh --skip-font
./install-claudefy.sh --skip-mcp
./install-claudefy.sh --force
```

## Font

Installer dùng Homebrew cask để cài JetBrainsMono Nerd Font:

```bash
brew install --cask font-jetbrains-mono-nerd-font
```

Sau khi cài, đặt font trong terminal đang dùng.

Terminal.app: Menu Terminal, Preferences, chọn Profile, mục Text, đổi Font thành JetBrainsMono Nerd Font.

iTerm2: Preferences, Profiles, chọn profile, mục Text, đổi Font thành JetBrainsMono Nerd Font.

## Notification

Trên macOS, notification dùng osascript với lệnh `display notification`. Lần đầu chạy, hệ thống có thể hỏi quyền hiện notification. Cho phép trong System Settings, Notifications, mục Script Editor hoặc terminal đang dùng.

## Repository và liên hệ

Repository: https://github.com/hasoftware/Claudefy

Telegram: https://t.me/hasoftware
