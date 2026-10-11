# ShotBar

macOS のメニューバーに常駐し、直近のスクリーンショットと画面収録をその場で **開く / コピー / パスをコピー / Finder で表示** できる小さなアプリ。Finder で保存先を探しに行かずに済む。

- 純正の ⌘⇧3 / ⌘⇧4 / ⌘⇧5 で撮ったものをそのまま扱う（撮影機能は持たない）
- 保存先は `defaults read com.apple.screencapture` の `location` / `location-screenshot` / `location-screenrecording` を読む。未設定なら `~/Desktop`
- 一番新しい 1 件は大きなサムネイルと 4 つの動詞、続く 9 件はサブメニュー
- 「コピー」はファイル（file URL）と画像データを同じ項目に載せるので、Finder / Slack にはファイルとして、画像を受けるアプリには画像として貼れる。画面収録はファイルだけ
- 「パスをコピー」は絶対パスの文字列。ターミナルや Claude Code に貼る用
- 「ログイン時に起動」はメニューのトグル（`SMAppService`）

## 入れる

```sh
git clone https://github.com/bytask/shotbar.git
cd shotbar
./scripts/install.sh   # swift build → ShotBar.app を組んで ~/Applications に入れて起動
```

Xcode（Swift 5.9 以上、macOS 14 以上）が要る。署名は ad hoc なので自分の Mac 専用。入れ替えも同じコマンド、外すのは `./scripts/uninstall.sh`。

## 作り

| ファイル | 役割 |
|---|---|
| `Sources/ShotBar/AppDelegate.swift` | NSStatusItem とメニュー。開く・コピー・パス・Finder・ログイン時起動 |
| `Sources/ShotBar/CaptureStore.swift` | 保存先の解決、新しい順の一覧、フォルダ監視（kqueue） |
| `Sources/ShotBar/Thumbnails.swift` | QuickLookThumbnailing でサムネイル |
| `Resources/Info.plist` | `LSUIElement`（Dock に出さない）、Bundle ID `com.bytask.shotbar` |
| `scripts/build.sh` | `swift build -c release` → `dist/ShotBar.app` → `codesign --sign -` |
| `scripts/make-icon.swift` | `Resources/AppIcon.icns` を描く |

## 先行品

同じ用途で先にあるもの。これで足りる人はこちらを。

- Raycast 内蔵「Search Screenshots」「Paste Latest Screenshot」: 保存先の一覧とコピー・Finder 表示。ホットキー起動で、メニューバー常駐ではない
- [Vignette](https://github.com/petekp/vignette): 保存先を監視して直近の束を出し、パスのコピーもある。撮影の流れごと置き換える作り
- [ScreenshotMenu](https://screenshotmenu.nestimer.com/) / [BetterShot](https://github.com/KartikLabhshetwar/better-shot) / CleanShot X: 自前の撮影機能を持つアプリ

ShotBar は「純正の撮影はそのまま、メニューバーに直近の一覧だけ」に絞ったもの。

## License

MIT
