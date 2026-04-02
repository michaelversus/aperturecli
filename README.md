<p align="center">
    <img src="https://img.shields.io/badge/Swift-6.0-red.svg" />
    <img src="https://codecov.io/gh/michaelversus/aperurecli/graph/badge.svg?token=X6D554DMMR"/>
</p>
# 📸 nsassetscli

`nsassetscli` is a macOS Swift CLI that connects Xcode snapshot test output with NSAssets macOS app.
It helps you set up a repository for NSAssets-driven snapshot workflows, inject managed post-test actions into the right `.xcscheme` files, parse fresh `xcresult` data into structured JSON artifacts, and notify the NSAssets macOS app when new results are available.

The CLI currently provides three main workflows:
- `init` bootstraps a repository by creating `.nsassets.json`, preparing artifact folders, and optionally updating `.gitignore`.
- `schemes sync-post-actions` rewrites selected test schemes so they run the managed `nsassetscli xcresult parse` hook after tests finish.
- `xcresult parse` resolves the latest matching `xcresult`, exports failure details and attachments, and writes structured output into `nsassets-artifacts/`.

## Common use cases

### Set up a repository for NSAssets macOS app
Run the setup wizard once from your project root to collect the iOS version, simulator model, Xcode version, project file, local packages path, and the snapshot test schemes you want to manage.

```bash
nsassetscli init
```

This creates `.nsassets.json`, prepares `nsassets-artifacts/logs`, and can append `nsassets-artifacts/` to `.gitignore`.

### Re-sync managed post-test actions after scheme changes
If new snapshot schemes are added, moved, or recreated, run the sync command from the repository root to re-inject the managed post-action into the selected schemes stored in `.nsassets.json`.

```bash
nsassetscli schemes sync-post-actions
```

### Parse the latest snapshot test result into NSAssets artifacts
The managed scheme hook calls this automatically after tests, but you can also run it manually when debugging.

```bash
nsassetscli xcresult parse \
    --scheme Snapshots \
    --project-name MyApp \
    --workspace-path "/Users/me/Projects/MyApp/MyApp.xcworkspace"
```

This writes a JSON summary to `nsassets-artifacts/xcresults/Snapshots.json`, exports failure attachments into a per-test folder, and attempts to notify NSAssets macOS app.

## 🛠️ Installation

### Homebrew
```bash
brew tap michaelversus/aperturecli https://github.com/michaelversus/aperturecli.git
brew install nsassetscli
```

### Build from source
```bash
make install prefix=/usr/local
```

The managed Xcode post-action currently invokes `nsassetscli` directly, so the binary should be available on the PATH used by Xcode's scheme execution environment.

## Commands

### Root command
- `nsassetscli` defaults to the `init` workflow.
- `--version` prints the CLI version.
- `--help` prints command usage.

### `init`
- Launches the interactive setup wizard.
- Scans project and package schemes to discover candidate snapshot test schemes.
- Writes `.nsassets.json` in the current repository root.
- Creates `nsassets-artifacts/logs`.
- Optionally updates `.gitignore`.

### `schemes sync-post-actions`
- Loads `.nsassets.json` from the current repository root.
- Finds the selected snapshot schemes again.
- Injects or refreshes the managed NSAssets shell-script post action in those `.xcscheme` files.

### `xcresult parse`
- `--scheme` is the scheme name used to match the latest `xcresult`.
- `--project-name` is the Xcode project name without the `.xcodeproj` extension.
- `--workspace-path` is optional and helps the CLI derive the repository root for output paths and NSAssets Studio notifications.

## Usage

### Start the setup wizard
```bash
nsassetscli
```

Because `init` is the default subcommand, running the root command without arguments starts the same workflow as `nsassetscli init`.

### Rebuild managed scheme hooks from saved config
```bash
cd /Users/me/Projects/MyApp
nsassetscli schemes sync-post-actions
```

Sample output:
```text
Matched schemes: 2
Updated scheme files: 2
Updated scheme file paths:
/Users/me/Projects/MyApp/MyApp.xcodeproj/xcshareddata/xcschemes/Snapshots.xcscheme
/Users/me/Projects/MyApp/Packages/FeatureUI/xcshareddata/xcschemes/FeatureSnapshots.xcscheme
```

### Manually parse results for a scheme
```bash
nsassetscli xcresult parse \
    --scheme Snapshots \
    --project-name MyApp \
    --workspace-path "/Users/me/Projects/MyApp/MyApp.xcworkspace"
```

Sample output:
```text
/Users/me/Projects/MyApp/nsassets-artifacts/xcresults/Snapshots.json
```

## Configuration

`init` writes a `.nsassets.json` file in the repository root. It stores the values needed to rediscover schemes and keep post-actions in sync.

Example:
```json
{
  "iosVersion": "18.2",
  "projectFileName": "MyApp.xcodeproj",
  "repoRoot": "/Users/me/Projects/MyApp",
  "simulatorModel": "iPhone 16 Pro",
  "snapshotTestSchemes": [
    "Snapshots",
    "FeatureSnapshots"
  ],
  "spmPackagesContainerPath": "Packages",
  "xcodeVersion": "16.2"
}
```

## Artifacts

`nsassetscli xcresult parse` writes output under `nsassets-artifacts/`:
- `nsassets-artifacts/logs/<Scheme>.log` stores the managed scheme post-action log.
- `nsassets-artifacts/xcresults/<Scheme>.json` stores the structured parsed summary for NSAssets Studio.
- `nsassets-artifacts/xcresults/<Scheme>/attachments/...` stores exported attachments grouped by failed test identifier.

## How it works

### Setup workflow
1. The wizard prompts for repository-specific Xcode and simulator details.
2. It resolves the project file and optional local packages path.
3. It scans `.xcscheme` files from the app project and package container to discover snapshot test schemes.
4. It stores the selected scheme names in `.nsassets.json` and optionally updates `.gitignore`.

### Scheme synchronization
1. The sync command reloads `.nsassets.json`.
2. It locates the selected schemes again across the project and package container.
3. It injects a managed shell-script post action into each matching scheme.
4. That post action runs `nsassetscli xcresult parse` in the background and appends logs to `nsassets-artifacts/logs/<Scheme>.log`.

### XCResult parsing and app notification
1. The parser resolves the latest matching `xcresult` in DerivedData for the given scheme and project name.
2. It reads the summary, failed tests, per-test details, activity attachments, and exported attachment manifests through `xcresulttool`.
3. It writes a pretty-printed JSON artifact into `nsassets-artifacts/xcresults/`.
4. It notifies NSAssets macOS app through a distributed notification. If the app is not running, the CLI prompts in interactive terminals and auto-launches in non-interactive environments.

## Testing

The package uses Swift Testing with focused unit tests for setup prompting, config loading and writing, scheme synchronization, post-action generation, xcresult parsing, derived-data resolution, and app-bridge behavior.

Run the test suite with:

```bash
swift test
```
