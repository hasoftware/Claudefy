#!/usr/bin/env node

const { spawn } = require("child_process");
const path = require("path");
const os = require("os");
const fs = require("fs");

const ROOT = path.resolve(__dirname, "..");
const platform = os.platform();

function banner() {
  console.log();
  console.log("  \x1b[1;36mClaudefy\x1b[0m — Make Claude Code yours.");
  console.log("  https://github.com/hasoftware/Claudefy");
  console.log();
}

function run(cmd, args, opts) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, { stdio: "inherit", ...opts });
    child.on("close", (code) =>
      code === 0 ? resolve() : reject(new Error(`Exit code ${code}`))
    );
    child.on("error", reject);
  });
}

function help() {
  console.log("  Usage: npx @hasoftware/claudefy [options]");
  console.log();
  console.log("  Options:");
  console.log("    --force          Overwrite existing config without backup prompt");
  console.log("    --skip-font      Skip Nerd Font installation");
  console.log("    --skip-mcp       Skip MCP sequential-thinking setup");
  console.log("    --skip-devradar  Skip DevRadar integration");
  console.log("    --help           Show this help message");
  console.log();
}

async function main() {
  const args = process.argv.slice(2);
  const forwardArgs = args.filter((a) => a.startsWith("--"));

  banner();

  if (args.includes("--help") || args.includes("-h")) {
    help();
    return;
  }

  if (platform === "win32") {
    const script = path.join(ROOT, "windows", "Install-Claudefy.ps1");
    if (!fs.existsSync(script)) {
      console.error("  Error: installer not found at", script);
      process.exit(1);
    }
    const psArgs = [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      script,
    ];
    if (forwardArgs.includes("--force")) psArgs.push("-Force");
    if (forwardArgs.includes("--skip-font")) psArgs.push("-SkipFont");
    if (forwardArgs.includes("--skip-mcp")) psArgs.push("-SkipMcp");
    if (forwardArgs.includes("--skip-devradar")) psArgs.push("-SkipDevRadar");

    console.log("  Platform: Windows");
    console.log("  Running Install-Claudefy.ps1 ...\n");
    await run("pwsh", psArgs);
  } else if (platform === "darwin") {
    const script = path.join(ROOT, "MACOS", "install-claudefy.sh");
    if (!fs.existsSync(script)) {
      console.error("  Error: installer not found at", script);
      process.exit(1);
    }
    fs.chmodSync(script, 0o755);

    const shArgs = [script, ...forwardArgs];
    console.log("  Platform: macOS");
    console.log("  Running install-claudefy.sh ...\n");
    await run("bash", shArgs);
  } else if (platform === "linux") {
    const script = path.join(ROOT, "Linux", "install-claudefy.sh");
    if (!fs.existsSync(script)) {
      console.error("  Error: installer not found at", script);
      process.exit(1);
    }
    fs.chmodSync(script, 0o755);

    const shArgs = [script, ...forwardArgs];
    console.log("  Platform: Linux");
    console.log("  Running install-claudefy.sh ...\n");
    await run("bash", shArgs);
  } else {
    console.error(`  Unsupported platform: ${platform}`);
    console.error("  Claudefy supports: Windows, Linux, macOS");
    process.exit(1);
  }

  console.log("\n  \x1b[1;32mDone!\x1b[0m Restart Claude Code to see your new statusline.\n");
}

main().catch((err) => {
  console.error("\n  \x1b[1;31mInstallation failed:\x1b[0m", err.message);
  process.exit(1);
});
