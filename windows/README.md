# Claudefy cho Windows

Phiên bản PowerShell của Claudefy. Chạy trên Windows 10 và Windows 11.

## File trong thư mục này

| File | Mô tả |
|---|---|
| Claudefy.cmd | Trình khởi chạy double-click, kiểm tra pwsh rồi gọi Claudefy.ps1 |
| Claudefy.ps1 | Menu chính với bốn mục Install, Reset, Theme, About |
| Install-Claudefy.ps1 | Trình cài đặt all-in-one, có thể chạy độc lập không qua menu |

## Yêu cầu

- Windows 10 hoặc Windows 11
- PowerShell 7 trở lên, cài bằng `winget install Microsoft.PowerShell`
- Claude Code CLI
- winget (khuyến nghị, để tự cài JetBrainsMono Nerd Font)

## Cài đặt

Tải ba file ở trên về cùng một thư mục. Sau đó:

Cách bấm chuột: bấm hai lần vào Claudefy.cmd.

Cách dòng lệnh:

```powershell
cd duongdan-toi-thumuc
.\Claudefy.ps1
```

Hoặc bỏ qua menu, chạy thẳng installer:

```powershell
.\Install-Claudefy.ps1
.\Install-Claudefy.ps1 -SkipFont
.\Install-Claudefy.ps1 -SkipWindowsTerminal
.\Install-Claudefy.ps1 -SkipMCP
.\Install-Claudefy.ps1 -Force
```

## Sau khi cài

Đóng tất cả cửa sổ Windows Terminal rồi mở lại để font Nerd Font được nạp. Sau đó mở Claude Code trong project bất kỳ.

## Menu Theme

Phiên bản Windows có mục Theme for Claude Code với mười color scheme chọn sẵn. Mở Claudefy.ps1, chọn mục 3 trong menu chính.

Mười theme có sẵn: One Half Dark, Dracula, Tokyo Night, Catppuccin Mocha, Nord, Solarized Dark, Gruvbox Dark, Monokai, Synthwave 84, GitHub Dark.

## Repository và liên hệ

Repository: https://github.com/hasoftware/Claudefy

Telegram: https://t.me/hasoftware
