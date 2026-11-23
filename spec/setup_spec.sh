#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2317,SC2329

setup() {
  create_test_root
  mkdir -p "$TEST_HOME/.dotfiles"
  mkdir -p "$TEST_HOME/.dotfiles/claude/agents" "$TEST_HOME/.dotfiles/claude/rules"

  TEST_DOTFILES_DIR="$TEST_HOME/.dotfiles"
  TEST_CONFIG_DIR="$TEST_HOME/.config"
  TEST_ANTIGEN_DIR="$TEST_HOME/.antigen"
  TEST_PATH="$TEST_BIN:/bin:/usr/bin"
  TEST_SHELL="/bin/bash"
  unset TEST_SKIP_CHSH TEST_XDG_DATA_HOME TEST_FONT_DOWNLOAD_FAIL

  write_fake_grep

  make_stub git <<'STUB'
#!/bin/sh
echo "$*" >> "$HOME/.setup_calls"
exit 0
STUB

  make_stub chsh <<'STUB'
#!/bin/sh
echo "chsh:$*" >> "$HOME/.setup_calls"
exit 0
STUB

  make_stub custom-chsh <<'STUB'
#!/bin/sh
echo "custom-chsh:$*" >> "$HOME/.setup_calls"
exit 0
STUB

  make_stub zsh <<'STUB'
#!/bin/sh
exit 0
STUB

  make_stub my-zsh <<'STUB'
#!/bin/sh
exit 0
STUB

  make_stub curl <<'STUB'
#!/bin/sh
[ "${FONT_DOWNLOAD_FAIL:-0}" = 0 ] || exit 1
while [ "$1" != --output ]; do shift; done
printf '%s\n' "$3" >> "$HOME/.font_downloads"
printf 'test font\n' > "$2"
STUB

  make_stub fc-cache <<'STUB'
#!/bin/sh
exit 0
STUB

  unset TEST_UNAME
  make_stub uname <<'STUB'
#!/bin/sh
echo "$FAKE_UNAME"
STUB
}

cleanup() {
  cleanup_test_root
}

run_setup() {
  HOME="$TEST_HOME" \
  PATH="$TEST_PATH" \
  SHELL="$TEST_SHELL" \
  DOTFILES_DIR="$TEST_DOTFILES_DIR" \
  CONFIG_DIR="$TEST_CONFIG_DIR" \
  ANTIGEN_DIR="$TEST_ANTIGEN_DIR" \
  GIT_BIN="$TEST_BIN/git" \
  GREP_BIN="$TEST_BIN/grep" \
  ZSH_BIN="${TEST_ZSH_BIN:-$TEST_BIN/zsh}" \
  CHSH_BIN="${TEST_CHSH_BIN:-$TEST_BIN/chsh}" \
  SKIP_CHSH="${TEST_SKIP_CHSH:-}" \
  UNAME_BIN="$TEST_BIN/uname" \
  XDG_DATA_HOME="${TEST_XDG_DATA_HOME:-}" \
  FONT_DOWNLOAD_FAIL="${TEST_FONT_DOWNLOAD_FAIL:-}" \
  FAKE_UNAME="${TEST_UNAME:-Linux}" \
    /bin/sh "$SHELLSPEC_PROJECT_ROOT/setup.sh"
}

Describe 'setup.sh'
  Before 'setup'
  After 'cleanup'

  It 'creates wrapper files, links, antigen clone, and chsh'
    When run run_setup
    The status should be success
    The output should include 'Installing antigen...'
    The contents of file "$TEST_HOME/.zshrc" should include 'source ~/.zshrc_pre'
    The contents of file "$TEST_HOME/.zshrc" should include 'source ~/.dotfiles/.zshrc'
    The contents of file "$TEST_HOME/.zshrc" should include 'source ~/.zshrc_post'
    The file "$TEST_HOME/.zshrc_pre" should be exist
    The file "$TEST_HOME/.zshrc_post" should be exist
    Assert symlink_to "$TEST_HOME/.p10k.zsh" "$TEST_DOTFILES_DIR/.p10k.zsh"
    Assert symlink_to "$TEST_HOME/.vimrc" "$TEST_DOTFILES_DIR/.vimrc"
    Assert symlink_to "$TEST_HOME/.tmux.conf" "$TEST_DOTFILES_DIR/.tmux.conf"
    The path "$TEST_HOME/.hammerspoon" should not be exist
    The path "$TEST_HOME/.claude" should not be symlink
    The directory "$TEST_HOME/.claude" should be exist
    The line 2 of contents of file "$TEST_HOME/.claude/CLAUDE.md" \
      should equal "@$TEST_DOTFILES_DIR/claude/CLAUDE.md"
    Assert symlink_to "$TEST_HOME/.claude/agents" "$TEST_DOTFILES_DIR/claude/agents"
    Assert symlink_to "$TEST_HOME/.claude/rules" "$TEST_DOTFILES_DIR/claude/rules"
    Assert symlink_to "$TEST_HOME/.claude/skills" "$TEST_HOME/.agents/skills"
    The directory "$TEST_CONFIG_DIR" should be exist
    The path "$TEST_CONFIG_DIR/karabiner" should not be exist
    The contents of file "$TEST_CONFIG_DIR/ghostty/config.ghostty" \
      should include "config-file = \"$TEST_DOTFILES_DIR/ghostty/linux\""
    The contents of file "$TEST_HOME/.setup_calls" \
      should include 'clone https://github.com/zsh-users/antigen.git'
    The contents of file "$TEST_HOME/.setup_calls" \
      should include "chsh:-s $TEST_BIN/zsh"
    The contents of file "$TEST_HOME/.setup_calls" \
      should include "-C $TEST_DOTFILES_DIR config core.hooksPath hooks"
  End

  It 'installs the JetBrains Mono Nerd Font styles into the Linux user font directory'
    mkdir -p "$TEST_ANTIGEN_DIR"
    TEST_XDG_DATA_HOME="$TEST_HOME/data"
    When run run_setup
    The status should be success
    The file "$TEST_HOME/data/fonts/JetBrainsMonoNerdFontMono-Regular.ttf" should be exist
    The file "$TEST_HOME/data/fonts/JetBrainsMonoNerdFontMono-Bold.ttf" should be exist
    The file "$TEST_HOME/data/fonts/JetBrainsMonoNerdFontMono-Italic.ttf" should be exist
    The file "$TEST_HOME/data/fonts/JetBrainsMonoNerdFontMono-BoldItalic.ttf" should be exist
  End

  It 'installs the font on macOS and skips downloads on rerun'
    mkdir -p "$TEST_ANTIGEN_DIR"
    TEST_UNAME=Darwin
    run_setup >/dev/null
    rm "$TEST_HOME/.font_downloads"
    When run run_setup
    The status should be success
    The file "$TEST_HOME/Library/Fonts/JetBrainsMonoNerdFontMono-Regular.ttf" should be exist
    The path "$TEST_HOME/.font_downloads" should not be exist
  End

  It 'completes setup if font downloads are unavailable'
    mkdir -p "$TEST_ANTIGEN_DIR"
    TEST_FONT_DOWNLOAD_FAIL=1
    When run run_setup
    The status should be success
    The stderr should include 'Warning: could not install JetBrainsMono Nerd Font.'
    The path "$TEST_HOME/.local/share/fonts/JetBrainsMonoNerdFontMono-Regular.ttf" \
      should not be exist
  End

  It 'links Hammerspoon and Karabiner on macOS'
    TEST_UNAME=Darwin
    When run run_setup
    The status should be success
    The output should include 'Installing antigen...'
    Assert symlink_to "$TEST_HOME/.hammerspoon" "$TEST_DOTFILES_DIR/.hammerspoon"
    Assert symlink_to "$TEST_CONFIG_DIR/karabiner" "$TEST_DOTFILES_DIR/karabiner"
  End

  It 'removes Hammerspoon and Karabiner links an older setup made off macOS'
    mkdir -p "$TEST_CONFIG_DIR" "$TEST_HOME/my-karabiner"
    ln -s "$TEST_DOTFILES_DIR/.hammerspoon" "$TEST_HOME/.hammerspoon"
    ln -s "$TEST_HOME/my-karabiner" "$TEST_CONFIG_DIR/karabiner"
    When run run_setup
    The status should be success
    The output should include 'Installing antigen...'
    The path "$TEST_HOME/.hammerspoon" should not be exist
    The path "$TEST_HOME/.hammerspoon" should not be symlink
    # Not a link to the repo, so it stays.
    Assert symlink_to "$TEST_CONFIG_DIR/karabiner" "$TEST_HOME/my-karabiner"
  End

  It 'sets git include.path idempotently'
    mkdir -p "$TEST_ANTIGEN_DIR"
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.setup_calls" \
      should include "config --global include.path $TEST_DOTFILES_DIR/.gitconfig"
  End

  It 'skips antigen clone when antigen directory exists'
    mkdir -p "$TEST_ANTIGEN_DIR"
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.setup_calls" \
      should not include 'clone https://github.com/zsh-users/antigen.git'
  End

  It 'skips chsh when shell is already the resolved zsh path'
    mkdir -p "$TEST_ANTIGEN_DIR"
    TEST_SHELL="$TEST_BIN/zsh"
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.setup_calls" \
      should not include "chsh:-s $TEST_BIN/zsh"
  End

  It 'skips chsh when SKIP_CHSH is set'
    mkdir -p "$TEST_ANTIGEN_DIR"
    TEST_SKIP_CHSH=1
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.setup_calls" \
      should not include 'chsh:-s'
  End

  It 'backs up and replaces a real file with the correct symlink'
    mkdir -p "$TEST_ANTIGEN_DIR"
    echo local-vimrc > "$TEST_HOME/.vimrc"
    When run run_setup
    The status should be success
    Assert symlink_to "$TEST_HOME/.vimrc" "$TEST_DOTFILES_DIR/.vimrc"
    The contents of file "$TEST_HOME/.vimrc.bak" should equal 'local-vimrc'
  End

  It 'fixes a wrong symlink'
    mkdir -p "$TEST_ANTIGEN_DIR"
    ln -s /tmp/wrong "$TEST_HOME/.vimrc"
    When run run_setup
    The status should be success
    Assert symlink_to "$TEST_HOME/.vimrc" "$TEST_DOTFILES_DIR/.vimrc"
    The file "$TEST_HOME/.vimrc.bak" should be symlink
  End

  It 'is idempotent — correct symlinks are left unchanged'
    mkdir -p "$TEST_ANTIGEN_DIR"
    # Pre-create correct symlinks
    ln -s "$TEST_DOTFILES_DIR/.vimrc" "$TEST_HOME/.vimrc"
    ln -s "$TEST_DOTFILES_DIR/.tmux.conf" "$TEST_HOME/.tmux.conf"
    ln -s "$TEST_DOTFILES_DIR/.p10k.zsh" "$TEST_HOME/.p10k.zsh"
    When run run_setup
    The status should be success
    The file "$TEST_HOME/.vimrc.bak" should not be exist
    The file "$TEST_HOME/.tmux.conf.bak" should not be exist
    The file "$TEST_HOME/.p10k.zsh.bak" should not be exist
  End

  It 'uses DOTFILES_DIR override for links and include path'
    TEST_DOTFILES_DIR="$TEST_HOME/dotfiles-custom"
    mkdir -p "$TEST_DOTFILES_DIR"
    When run run_setup
    The status should be success
    The output should include 'Installing antigen...'
    Assert symlink_to "$TEST_HOME/.vimrc" "$TEST_DOTFILES_DIR/.vimrc"
    The contents of file "$TEST_HOME/.setup_calls" \
      should include "config --global include.path $TEST_DOTFILES_DIR/.gitconfig"
  End

  It 'uses CONFIG_DIR override for config links'
    TEST_CONFIG_DIR="$TEST_HOME/custom-config"
    TEST_UNAME=Darwin
    When run run_setup
    The status should be success
    The output should include 'Installing antigen...'
    Assert symlink_to "$TEST_CONFIG_DIR/karabiner" "$TEST_DOTFILES_DIR/karabiner"
    The file "$TEST_CONFIG_DIR/ghostty/config.ghostty" should be exist
  End

  It 'uses ANTIGEN_DIR override for clone target'
    TEST_ANTIGEN_DIR="$TEST_HOME/antigen-custom"
    When run run_setup
    The status should be success
    The output should include 'Installing antigen...'
    The contents of file "$TEST_HOME/.setup_calls" \
      should include "clone https://github.com/zsh-users/antigen.git $TEST_ANTIGEN_DIR"
  End

  It 'uses CHSH_BIN and ZSH_BIN overrides'
    mkdir -p "$TEST_ANTIGEN_DIR"
    TEST_CHSH_BIN="$TEST_BIN/custom-chsh"
    TEST_ZSH_BIN="$TEST_BIN/my-zsh"
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.setup_calls" \
      should include "custom-chsh:-s $TEST_BIN/my-zsh"
  End

  It 'fails when ZSH_BIN cannot be resolved'
    mkdir -p "$TEST_ANTIGEN_DIR"
    TEST_ZSH_BIN='missing-zsh'
    When run run_setup
    The status should be failure
    The contents of file "$TEST_HOME/.setup_calls" should not include 'chsh:-s'
  End

  It 'migrates .zshrc_local to .zshrc_post'
    mkdir -p "$TEST_ANTIGEN_DIR"
    echo 'export FOO=bar' > "$TEST_HOME/.zshrc_local"
    When run run_setup
    The status should be success
    The file "$TEST_HOME/.zshrc_local" should not be exist
    The contents of file "$TEST_HOME/.zshrc_post" should equal 'export FOO=bar'
  End

  It 'skips migration when .zshrc_post already exists'
    mkdir -p "$TEST_ANTIGEN_DIR"
    echo 'old-local' > "$TEST_HOME/.zshrc_local"
    echo 'existing-post' > "$TEST_HOME/.zshrc_post"
    When run run_setup
    The status should be success
    The contents of file "$TEST_HOME/.zshrc_local" should equal 'old-local'
    The contents of file "$TEST_HOME/.zshrc_post" should equal 'existing-post'
  End

  It 'symlinks .local/bin scripts'
    mkdir -p "$TEST_ANTIGEN_DIR"
    mkdir -p "$TEST_DOTFILES_DIR/.local/bin"
    echo '#!/bin/sh' > "$TEST_DOTFILES_DIR/.local/bin/whereami"
    echo '#!/bin/sh' > "$TEST_DOTFILES_DIR/.local/bin/whereami-color"
    When run run_setup
    The status should be success
    Assert symlink_to "$TEST_HOME/.local/bin/whereami" \
      "$TEST_DOTFILES_DIR/.local/bin/whereami"
    Assert symlink_to "$TEST_HOME/.local/bin/whereami-color" \
      "$TEST_DOTFILES_DIR/.local/bin/whereami-color"
  End

  It 'fixes stale .local/bin symlinks on re-run'
    mkdir -p "$TEST_ANTIGEN_DIR"
    mkdir -p "$TEST_DOTFILES_DIR/.local/bin"
    mkdir -p "$TEST_HOME/.local/bin"
    echo '#!/bin/sh' > "$TEST_DOTFILES_DIR/.local/bin/whereami"
    ln -s /tmp/wrong "$TEST_HOME/.local/bin/whereami"
    When run run_setup
    The status should be success
    Assert symlink_to "$TEST_HOME/.local/bin/whereami" \
      "$TEST_DOTFILES_DIR/.local/bin/whereami"
  End
  It 'replaces a stale ~/.claude/skills symlink'
    mkdir -p "$TEST_ANTIGEN_DIR" "$TEST_DOTFILES_DIR/.agents/skills/add-lync-skill"
    mkdir -p "$TEST_HOME/.claude"
    ln -s /tmp/wrong "$TEST_HOME/.claude/skills"
    When run run_setup
    The status should be success
    Assert symlink_to "$TEST_HOME/.claude/skills" "$TEST_HOME/.agents/skills"
  End

  It "moves Claude Code's state out of the repo when ~/.claude linked to it"
    mkdir -p "$TEST_ANTIGEN_DIR" "$TEST_DOTFILES_DIR/.claude/projects/p" \
      "$TEST_DOTFILES_DIR/.claude/rules"
    echo token > "$TEST_DOTFILES_DIR/.claude/.credentials.json"
    echo session > "$TEST_DOTFILES_DIR/.claude/projects/p/s.jsonl"
    : > "$TEST_DOTFILES_DIR/.claude/rules/.gitkeep"
    ln -s "$TEST_DOTFILES_DIR/.claude" "$TEST_HOME/.claude"
    When run run_setup
    The status should be success
    The path "$TEST_HOME/.claude" should not be symlink
    The contents of file "$TEST_HOME/.claude/.credentials.json" should equal 'token'
    The contents of file "$TEST_HOME/.claude/projects/p/s.jsonl" should equal 'session'
    The path "$TEST_DOTFILES_DIR/.claude" should not be exist
    The path "$TEST_HOME/.claude/rules.bak" should not be exist
    Assert symlink_to "$TEST_HOME/.claude/rules" "$TEST_DOTFILES_DIR/claude/rules"
  End

  It 'backs up a ~/.claude link that points somewhere else'
    mkdir -p "$TEST_ANTIGEN_DIR" "$TEST_HOME/elsewhere"
    ln -s "$TEST_HOME/elsewhere" "$TEST_HOME/.claude"
    When run run_setup
    The status should be success
    Assert symlink_to "$TEST_HOME/.claude.bak" "$TEST_HOME/elsewhere"
    The path "$TEST_HOME/.claude" should not be symlink
  End

  It 'keeps machine-local lines under the CLAUDE.md import, and backs up a hand-written one'
    mkdir -p "$TEST_ANTIGEN_DIR" "$TEST_HOME/.claude"
    echo '# mine' > "$TEST_HOME/.claude/CLAUDE.md"
    run_setup_twice() {
      run_setup >/dev/null
      echo '- local' >> "$TEST_HOME/.claude/CLAUDE.md"
      run_setup
    }
    When run run_setup_twice
    The status should be success
    The contents of file "$TEST_HOME/.claude/CLAUDE.md.bak" should equal '# mine'
    The line 3 of contents of file "$TEST_HOME/.claude/CLAUDE.md" should equal '- local'
  End

  It 'escapes spaces in the CLAUDE.md import path'
    TEST_DOTFILES_DIR="$TEST_HOME/dot files"
    mkdir -p "$TEST_ANTIGEN_DIR" "$TEST_DOTFILES_DIR/claude"
    When run run_setup
    The status should be success
    The line 2 of contents of file "$TEST_HOME/.claude/CLAUDE.md" \
      should equal "@$TEST_HOME/dot\\ files/claude/CLAUDE.md"
  End

  It 'writes a ghostty wrapper that includes config, linux, then config.local on Linux'
    mkdir -p "$TEST_ANTIGEN_DIR"
    When run run_setup
    The status should be success
    The line 1 of contents of file "$TEST_CONFIG_DIR/ghostty/config.ghostty" \
      should start with '# Generated by ~/.dotfiles/setup.sh.'
    The line 2 of contents of file "$TEST_CONFIG_DIR/ghostty/config.ghostty" \
      should equal "config-file = \"$TEST_DOTFILES_DIR/ghostty/config\""
    The line 3 of contents of file "$TEST_CONFIG_DIR/ghostty/config.ghostty" \
      should equal "config-file = \"$TEST_DOTFILES_DIR/ghostty/linux\""
    The line 4 of contents of file "$TEST_CONFIG_DIR/ghostty/config.ghostty" \
      should equal 'config-file = ?config.local'
  End

  It 'includes ghostty/macos on macOS'
    mkdir -p "$TEST_ANTIGEN_DIR"
    TEST_UNAME=Darwin
    When run run_setup
    The status should be success
    The line 3 of contents of file "$TEST_CONFIG_DIR/ghostty/config.ghostty" \
      should equal "config-file = \"$TEST_DOTFILES_DIR/ghostty/macos\""
  End

  It 'ships every ghostty file the wrappers include'
    When call ls "$SHELLSPEC_PROJECT_ROOT/ghostty/config" \
      "$SHELLSPEC_PROJECT_ROOT/ghostty/macos" "$SHELLSPEC_PROJECT_ROOT/ghostty/linux" \
      "$SHELLSPEC_PROJECT_ROOT/ghostty/windows" "$SHELLSPEC_PROJECT_ROOT/ghostty/keys-alt"
    The status should be success
    The output should include 'keys-alt'
  End

  It 'replaces the old ghostty directory symlink without touching the repo'
    mkdir -p "$TEST_ANTIGEN_DIR" "$TEST_CONFIG_DIR" "$TEST_DOTFILES_DIR/ghostty"
    echo 'theme = x' > "$TEST_DOTFILES_DIR/ghostty/config"
    ln -s "$TEST_DOTFILES_DIR/ghostty" "$TEST_CONFIG_DIR/ghostty"
    When run run_setup
    The status should be success
    The path "$TEST_CONFIG_DIR/ghostty" should not be symlink
    The file "$TEST_CONFIG_DIR/ghostty/config.ghostty" should be exist
    The file "$TEST_DOTFILES_DIR/ghostty/config.ghostty" should not be exist
    The contents of file "$TEST_DOTFILES_DIR/ghostty/config" should equal 'theme = x'
  End

  It 'backs up hand-written ghostty configs'
    mkdir -p "$TEST_ANTIGEN_DIR" "$TEST_CONFIG_DIR/ghostty"
    echo 'font-size = 20' > "$TEST_CONFIG_DIR/ghostty/config"
    echo 'font-size = 30' > "$TEST_CONFIG_DIR/ghostty/config.ghostty"
    When run run_setup
    The status should be success
    The contents of file "$TEST_CONFIG_DIR/ghostty/config.bak" should equal 'font-size = 20'
    The contents of file "$TEST_CONFIG_DIR/ghostty/config.ghostty.bak" \
      should equal 'font-size = 30'
    The file "$TEST_CONFIG_DIR/ghostty/config" should not be exist
  End

  It 'rewrites its own ghostty wrapper without a backup'
    mkdir -p "$TEST_ANTIGEN_DIR"
    run_setup >/dev/null
    When run run_setup
    The status should be success
    The file "$TEST_CONFIG_DIR/ghostty/config.ghostty.bak" should not be exist
  End
End
