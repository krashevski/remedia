#!/usr/bin/env bash
# ====================================================================
# PRODUCTION MEDIA PANEL — MIT ライセンス
# Copyright (c) 2025 Vladislav Krashevsky
# 本ソフトウェアおよび関連ドキュメント
# ファイル（以下「本ソフトウェア」）のコピーを入手したすべての人に対し、
# いかなる制限もなく本ソフトウェアを取り扱うことを無償で許可します。これには、
# 本ソフトウェアの使用、
# 複製、変更、統合、公開、配布、サブライセンス、および/または
# 販売する権利が含まれますが、これらに限定されません。ただし、以下の条件が適用されます。
# 上記の著作権表示およびこの許可通知は、
# 本ソフトウェアのすべてのコピーまたは大部分に含まれるものとします。
# 本ソフトウェアは「現状有姿」で提供され、いかなる種類の保証もありません。
# =========================================================================
# messages_en.sh
# PRODUCTION MEDIA PANEL — メッセージライブラリ
# すべてのスクリプトで統一された英語メッセージ
# MITライセンス — Copyright (c) 2025 Vladislav Krashevsky support ChatGPT
# ======================================================================

MSG[hello]="Hello, world!"
MSG[start]="開始しています"

# 共通ライブラリ
# logging.sh
MSG[man_not_installed_hint]="manページがインストールされていません。設定メニューからインストールしてください。"
# privileges.sh
MSG[run_sudo]="スクリプトはroot権限（sudo）で実行する必要があります"
MSG[exec_via_sudo]="sudo 経由で実行しようとしています..."
# cleanup.sh
MSG[clean_ok]="一時ファイルを削除しました。"
MSG[clean_tmp]="一時ファイルをクリーンアップしています…"
MSG[clean_invalid_dir]="無効なディレクトリ: %s"
MSG[msg_cleanup_start]="一時ファイルをクリーンアップしています"
MSG[msg_cleanup_done]="クリーンアップ完了"
MSG[msg_removing]="削除中"
MSG[msg_workdir_cleaning]="作業ディレクトリをクリーンアップしています: %s..."
MSG[msg_workdir_cleaned]="作業ディレクトリ %s が正常にクリーンアップされました。"
MSG[msg_unsafe_path]="安全でないパスのため、操作はキャンセルされました"
# guards-firefox.sh
MSG[firefox_closing]="Firefox を終了しています。しばらくお待ちください..."
MSG[firefox_stop]="Firefox がまだ実行中です → 強制停止します"
# guards-inhibit.sh
MSG[inhibit_not_found]="systemd-inhibitが見つからないため、inhibitをスキップします"
MSG[inhibit_failed]="inhibitに失敗しましたが、そのまま続行します"
# select_user.sh
MSG[user_no_home]="/home にユーザーがいません"
MSG[user_available]="利用可能なユーザー:"
MSG[user_select]="操作 "%s" のユーザーを選択してください (例: 1 または 1 3): "
MSG[user_invalid_select]="無効な選択を無視します: %s"
MSG[user_no_selected]="ユーザーが選択されていません"
# system_detect.sh
MSG[detect_system]="検出されたシステム: %s %s"
MSG[not_system]="システムを検出できません (/etc/os-release がありません)"
# deps.sh
MSG[deps_ok]="すべての依存関係がインストールされました"
MSG[deps_install_try]="自動インストールを試行します…"
MSG[deps_unknown_manager]="不明なパッケージマネージャーです。手動でインストールしてください: %s"
MSG[deps_missing_list]="不足している依存関係: %s"
MSG[deps_missing]="パッケージがインストールされていません。インストールしてください"
# run-step
MSG[step_ok]="%s — 正常に完了しました"
MSG[step_fail]="%s — 失敗しました（参照%s)"
MSG[step_not_function]="'%s' は関数ではありません"
MSG[step_extract]="アーカイブを抽出しています"
MSG[step_repos]="リポジトリとキーリングを復元しています"
MSG[step_packages]="パッケージを復元しています"
MSG[step_logs]="ログを復元しています"
MSG[step_archive]="アーカイブ"
MSG[step_system_packages]="システムパッケージ"
MSG[step_repos_and_keys]="APTソースとキー"
MSG[step_logs]="ログ"
MSG[step_user_packages]="ユーザーによってインストールされたパッケージ"
MSG[step_archive]="アーカイブ"
MSG[backup_fail]="バックアップに失敗しました"
# init.sh
MSG[init_start]="ディレクトリを初期化しています"
MSG[dir_created]="ディレクトリを作成しました"
MSG[dir_exists]="ディレクトリが既に存在します"
MSG[dir_create_failed]="ディレクトリの作成に失敗しました"
MSG[dir_empty]="ディレクトリパスが空です"
MSG[msg_init_user_dirs]="ユーザーを初期化していますディレクトリ"
MSG[msg_init_system_dirs]="システムディレクトリを初期化しています"
MSG[msg_unsafe_path]="安全でないパス"
MSG[msg_run_sudo]="root権限が必要です (sudoで実行してください)"
# install-man.sh
MSG[man_not_found]="REBK のマニュアルページが見つかりません。インストール中です..."
MSG[man_installed]="マニュアルページが正常にインストールされました"
MSG[man_install_sudo]="manページをインストールするにはroot権限が必要です。sudoを使用してください。"
MSG[error_run_root]="エラー: スクリプトはルート権限で実行する必要があります。"
MSG[man_install_start]="==== REBK man のインストールを開始しました: %s ===="
MSG[directory_not_found]="ディレクトリ %s が見つかりません。スキップします。"
MSG[man_installed]="インストールされたマニュアルページ [%s]: %s.gz"
MSG[updating_mandb]="mandbデータベースを更新しています..."
MSG[install_completed]="==== REBK man のインストールが完了しました: %s ===="

# install.sh

# menu.sh, mediapanel
MSG[menu_home_not]="エラー: ユーザーのホームディレクトリを特定できません"
MSG[menu_dir_not]="エラー: パッケージディレクトリが見つかりません"
MSG[menu_modules_dir_not]="エラー: モジュールディレクトリが見つかりません:"
MSG[menu_mediasystem_title]="転生パイプライン"
MSG[menu_sel_mode]="パイプラインモードを選択してください:"
MSG[menu_mode_safe]="安全（デフォルトは最小限のモジュール）"
MSG[menu_mode_standard]="標準（標準設定）"
MSG[menu_mode_full]="フル（標準設定＋オプションのフルモジュール）"
MSG[menu_mode_choice]="選択肢を入力してください [1～3、デフォルトは1]: "
MSG[menu_choice_invalid]="無効な選択です。デフォルトで安全な方法を使用します。"
MSG[menu_mode_selected]="選択されたモード:"
MSG[menu_summary]="パイプライン概要"
MSG[menu_ok]="OK"
MSG[menu_fail]="失敗"
MSG[menu_skip]="スキップ"
MSG[menu_finished]="パイプライン完了:"
MSG[menu_write_error]="警告: ログにサマリーを書き込めません"
MSG[menu_exit]="終了"
