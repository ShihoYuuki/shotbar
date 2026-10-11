# shotbar

macOS のメニューバーから、純正のスクリーンショット・画面収録の直近 10 件を開く・コピーする・パスをコピーする常駐アプリ（ShotBar.app）。クリップボードに撮ったものも一定期間（既定 7 日）残して同じメニューに出す。保存先は `defaults read com.apple.screencapture` の location を読む。

- git 方針: main に直接 commit・push（1 人で使う手元のツール。PR は使わない）
- デプロイ: 無し。手元の Mac に `scripts/install.sh` で入れる（`~/Applications/ShotBar.app`、ad hoc 署名）
- 本番デプロイの事前承認: 該当なし

構成は `Sources/ShotBar/`（AppKit。`AppDelegate.swift` がメニュー、`CaptureStore.swift` が保存先と一覧、`ClipboardStore.swift` がクリップボードの監視と保存、`Thumbnails.swift` が QuickLook のサムネイル）、`Resources/Info.plist`、`scripts/`（build / install / uninstall / make-icon）。
