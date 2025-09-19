# Repository Guidelines

## Dos and Don’ts

- Do export `LAZARUS_DIR` before running `make` or `lazbuild`; builds fail when Lazarus is not discoverable.
- Do keep `.pas` and `.lfm` changes synchronized through Lazarus; update `lang/transgui.template` plus locale files together.
- Do run only the CI steps relevant to touched files, mirroring the commands in `.travis.yml`.
- Don’t edit generated artifacts such as `Makefile` or commit outputs under `Release/`.
- Don’t modify third-party sources in `synapse/` or bundled libraries in `setup/win/openssl/` unless you are porting an upstream fix.

## Project Structure and Module Organization

Transmission Remote GUI is a Lazarus/Free Pascal desktop client for Transmission’s RPC API.

- `transgui.lpi`, `transgui.lpr`, and the root `.pas`/`.lfm` pairs implement the application UI and logic.
- `lang/` contains key-value locale files; `transgui.template` is the canonical English resource.
- `synapse/` bundles the Synapse networking library; treat it as vendor code.
- `setup/` hosts packaging assets for Unix, macOS, and Windows builds (e.g., `unix/build.sh`, `macosx/create_app_new.sh`, `win/make_zipdist.bat`).
- `snap/` stores `snapcraft.yaml` and the desktop entry used for Snap builds.
- `.github/workflows/` and `.travis.yml` define automation; `VERSION.txt`, `history.txt`, and the various README files document releases.

## Build, Test, and Development Commands

Install Lazarus (≥2.2.6) and FPC (≥3.2.2); most scripts assume `lazbuild` is on PATH or pointed to by `LAZARUS_DIR`.

### Core workflow

- `cat VERSION.txt` shows the release number consumed by build scripts.
- `./setup/unix/debian-ubuntu-install_deps.sh` installs Debian/Ubuntu prerequisites (requires sudo and network access).
- `LAZARUS_DIR=/usr/lib/lazarus/default/ lazbuild -B transgui.lpi` regenerates Lazarus resources before compiling.
- `LAZARUS_DIR=/usr/lib/lazarus/default/ make -j$(nproc) all` builds the desktop binary without packaging; expect `transgui` (or `transgui.exe`) in the repository root.
- `LAZARUS_DIR=/usr/lib/lazarus/default/ make -j$(nproc) zipdist` builds the Linux zip bundle into `Release/`.
- `./setup/unix/build.sh` produces compressed txz releases and temporarily rewrites `about.lfm`; the script restores the backup at the end.
- `make clean` (with `LAZARUS_DIR` set) removes generated objects after a build.

### Platform packaging

- `setup/win/make_zipdist.bat <lazarus_dir>` creates the Windows portable zip and optionally compresses `transgui.exe` with UPX.
- `setup/win/make_setup.bat <lazarus_dir> "<Inno Setup dir>"` builds the Windows installer, honoring an optional `CODECERT` for signing.
- `setup/win/install_deps.bat` bootstraps Chocolatey-based dependencies (run in an elevated Windows shell).
- `setup/macosx/create_app_new.sh [/Library/Lazarus/]` emits a signed DMG and resets `about.lfm` afterward.
- `snapcraft` (run from the repository root) packages the app using `snap/snapcraft.yaml`.

### Static checks

- `docker run -it --rm -v "$(pwd)":/sh -w /sh peterdavehello/shfmt:3.4.0 shfmt -sr -i 2 -l -w -ci .` formats shell scripts like the Travis job.
- `find . -type f -name "*.sh" -print0 | xargs -0 shellcheck` runs ShellCheck on all shell scripts.
- `npx markdown-link-check README.md` validates README links after documentation edits.
- `npx eclint check lang/ setup/ Makefile* *.txt` enforces `.editorconfig` on templated assets.
- `doctoc --title "## Table of Contents" --github README.md` refreshes the README ToC; rerun until the diff is clean.

## Coding Style and Naming Conventions

- `.editorconfig` enforces UTF-8, LF endings (CRLF for `.txt`/`.bat`), and two-space indentation for Pascal, Lazarus project files, and shell scripts.
- Pascal units stay in `{$mode objfpc}{$H+}`; form classes follow the `T<Name>Form` naming pattern and expect matching `.lfm` changes.
- Use English for code comments; multi-line comments typically use `{ ... }` blocks, with `//` for inline notes.
- Locale files keep quoted key/value pairs and placeholder ordering; translate via `lang/transgui.template` to maintain consistency.
- Shell scripts preserve the existing shebang plus `set -ex`; prefer POSIX constructs to keep Travis checks green.
- Do not edit `Makefile`; modify `Makefile.fpc` or Lazarus project settings if build options need to change.

## Testing Guidelines

- No automated Pascal tests are present; perform manual regression on features affected (torrent list, dialogs, localization paths).
- For core behavior changes, run the app against a test Transmission daemon (local or remote) and confirm basic flows (add/start/stop torrents, refresh list).
- Record which static checks from `.travis.yml` were run locally; execute only those relevant to the files you touched.
- When packaging scripts change, run the corresponding script in an isolated environment and verify the artifact names (`Release/transgui-<ver>-*.{zip,txz,dmg}`).
- For locale updates, launch the app with that locale to confirm formatting, placeholders, and traditional Chinese typography where applicable.
- Document manual verification steps in the PR description to aid reviewers.

## Commit and Pull Request Guidelines

- Write imperative, capitalized subjects (e.g., `Fix RPC boolean handling`); append issue numbers in parentheses when closing tickets.
- Keep changes focused; separate localization refreshes, packaging tweaks, and code fixes into discrete commits.
- Ensure CI jobs (Travis static checks, GitHub workflows) pass; mention any skipped jobs and why.
- Update `history.txt` and README variants only when user-facing behavior shifts; keep Markdown Table of Contents in sync via `doctoc`.
- Provide screenshots or recordings for UI-affecting changes, especially when adjusting forms or translations.

## Safety and Permissions

- Allowed: inspect files, adjust Lazarus form pairs tied to your change, and run targeted lint/build commands with `LAZARUS_DIR` set.
- Ask before adding dependencies, renaming units, deleting locales, or altering packaging pipelines in `setup/` and `snap/`.
- Never commit build artifacts under `Release/`, temporary files produced by `build.sh`, or personal signing material.
- Restore generated backups (`about.lfm.bak`, etc.) and verify `git status` is clean before committing.
- Treat credentials and API tokens referenced in workflows as secrets; do not hardcode or log them.

## Packaging and Distribution

- Linux releases rely on `Makefile.fpc` plus `setup/unix/build.sh`; keep widgetset and CPU flags aligned with the existing scripts.
- Windows deliverables use `setup/win/setup.iss` and bundled OpenSSL DLLs (`setup/win/openssl/`); refresh both when upgrading TLS libraries.
- macOS builds depend on `setup/macosx/create_app_new.sh`, `Info.plist`, and `transgui.icns`; verify metadata placeholders resolve correctly.
- Snap packages follow `snap/snapcraft.yaml` and `snap/local/transgui.desktop`; update them whenever assets move or new permissions are needed.
