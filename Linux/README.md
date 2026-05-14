# Claudefy cho Linux

Phiên bản bash của Claudefy. Chạy trên mọi distro Linux hiện đại.

## File trong thư mục này

| File | Mô tả |
|---|---|
| claudefy.sh | Menu chính với ba mục Install, Reset, About |
| install-claudefy.sh | Trình cài đặt all-in-one, có thể chạy độc lập không qua menu |
| lib/statusline-command.sh | Script render thanh statusLine hai dòng, sẽ được copy vào ~/.claude |
| lib/notify-stop.sh | Hook Stop, phát chuông và toast khi Claude trả lời xong |
| lib/set-title.sh | Hook SessionStart, đặt tên tab terminal theo project |

## Yêu cầu

- Bất kỳ distro Linux nào (đã thử trên Ubuntu, Debian, Arch, Fedora)
- bash 3.2 trở lên (mặc định luôn có)
- Claude Code CLI
- jq để parse JSON. Cài: `sudo apt install jq` hoặc `sudo dnf install jq` hoặc `sudo pacman -S jq`
- curl hoặc wget để tải font
- unzip để giải nén font
- fc-cache để refresh font cache

Khuyến nghị thêm: git, node, gh CLI.

## Cài đặt

Tải toàn bộ thư mục Linux từ repository về máy. Cấp quyền thực thi và chạy:

```bash
cd duongdan-toi-thumuc-Linux
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

Installer sẽ tải JetBrainsMono.zip từ release mới nhất của nerd-fonts trên GitHub, giải nén vào `~/.local/share/fonts/JetBrainsMonoNerdFont` và chạy `fc-cache` để hệ thống nhận font mới.

Sau đó cần đặt font trong cấu hình của terminal đang dùng. Một số ví dụ:

GNOME Terminal: vào Preferences, chọn profile, mục Text, đổi Custom Font thành JetBrainsMono Nerd Font.

Konsole: vào Settings, chọn profile, mục Appearance, đổi Font.

Alacritty: sửa file `~/.config/alacritty/alacritty.toml`, đặt `font.normal.family = "JetBrainsMono Nerd Font"`.

Kitty: sửa file `~/.config/kitty/kitty.conf`, đặt `font_family JetBrainsMono Nerd Font`.

## Notification

Trên Linux, notification dùng `notify-send` thuộc gói libnotify. Hầu hết desktop environment hiện đại đã có sẵn. Nếu chưa, cài `sudo apt install libnotify-bin` trên Ubuntu/Debian.

## Repository và liên hệ

Repository: https://github.com/hasoftware/Claudefy

Telegram: https://t.me/hasoftware
