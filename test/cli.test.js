const { execSync } = require("child_process");
const path = require("path");
const fs = require("fs");
const assert = require("assert");

const CLI = path.resolve(__dirname, "..", "bin", "cli.js");

console.log("Running Claudefy CLI tests...\n");

// Test 1: CLI file exists
assert(fs.existsSync(CLI), "bin/cli.js should exist");
console.log("  ✓ bin/cli.js exists");

// Test 2: --help flag works without error
const help = execSync(`node "${CLI}" --help`, { encoding: "utf8" });
assert(help.includes("@hasoftware/claudefy"), "--help should mention package name");
assert(help.includes("--force"), "--help should list --force option");
assert(help.includes("--skip-font"), "--help should list --skip-font option");
console.log("  ✓ --help outputs expected content");

// Test 3: Installer scripts exist for all platforms
const root = path.resolve(__dirname, "..");
assert(fs.existsSync(path.join(root, "windows", "Install-Claudefy.ps1")), "Windows installer should exist");
assert(fs.existsSync(path.join(root, "Linux", "install-claudefy.sh")), "Linux installer should exist");
assert(fs.existsSync(path.join(root, "MACOS", "install-claudefy.sh")), "macOS installer should exist");
console.log("  ✓ All platform installers present");

// Test 4: Package.json has required fields
const pkg = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8"));
assert(pkg.name === "@hasoftware/claudefy", "Package name correct");
assert(pkg.bin.claudefy === "bin/cli.js", "Bin entry correct");
assert(pkg.license === "MIT", "License field present");
assert(pkg.repository, "Repository field present");
assert(pkg.engines, "Engines field present");
console.log("  ✓ package.json has required fields");

// Test 5: No dependencies (zero supply chain risk from deps)
assert(!pkg.dependencies || Object.keys(pkg.dependencies).length === 0, "Should have zero dependencies");
assert(!pkg.devDependencies || Object.keys(pkg.devDependencies).length === 0, "Should have zero devDependencies");
console.log("  ✓ Zero dependencies (minimal supply chain surface)");

console.log("\n  All tests passed.\n");
