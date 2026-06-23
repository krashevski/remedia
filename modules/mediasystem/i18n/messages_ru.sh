#!/usr/bin/env bash
# =============================================================
# PRODUCTION MEDIA PANEL — MIT License
# Copyright (c) 2025 Vladislav Krashevsky
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, subject to the following:
# The above copyright notice and this permission notice shall
# be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
# =============================================================
# messages_ru.sh
# PRODUCTION MEDIA PANEL — Messages Library
# Unified messages for all scripts in russian
# MIT License — Copyright (c) 2025 Vladislav Krashevsky support ChatGPT
# ==============================================================

MSG[hello]="Привет, мир!"
MSG[start]="Запуск"

# common library
# logging.sh
MSG[man_not_installed_hint]="Man-страницы не установлены. Установите их из меню «Настройки»."
# privileges.sh
MSG[run_sudo]="Скрипт нужно запускать с правами root (sudo)"
MSG[exec_via_sudo]="Попытка выполнить через sudo..."
# cleanup.sh
MSG[cleanup_tmp]="Очистка временных файлов..."
MSG[cleanup_ok]="Временные файлы удалены."
MSG[cleanup_invalid_dir]="Некорректный каталог: %s"
MSG[cleanup_removing]="Удаление"
MSG[cleanup_unsafe_path]="Небезопасный путь, операция отменена"
MSG[msg_workdir_cleaning]="Очистка рабочего каталога: %s..."
MSG[msg_workdir_cleaned]="Рабочий каталог %s успешно очищен."
# guards-firefox.sh
MSG[firefox_closing]="Firefox закрывается, пожалуйста, подождите..."
MSG[firefox_stop]="Firefox все еще работает → принудительная остановка"
# guards-inhibit.sh
MSG[inhibit_not_found]="systemd-inhibit не найден, пропускаем блокировку"
MSG[inhibit_failed]="Не удалось выполнить блокировку, продолжаем в любом случае"
# select_user.sh
MSG[user_no_home]="Нет пользователей в /home"
MSG[user_available]="Доступные пользователи:"
MSG[user_select]="Выберите пользователя(ей) для операции "%s" (например: 1 или 1 3): "
MSG[user_invalid_select]="Игнорируется недопустимый выбор: %s"
MSG[user_no_selected]="Пользователи не выбраны"
# system_detect.sh
MSG[detect_system]="Определение системы: %s %s"
MSG[not_system]="Не удается определить систему (нет /etc/os-release)"
# deps.sh
MSG[deps_ok]="Все зависимости установлены"
MSG[deps_install_try]="Попытка автоматической установки…"
MSG[deps_unknown_manager]="Неизвестный менеджер пакетов. Установите вручную: %s"
MSG[deps_missing_list]="Отсутствуют зависимости: %s"
MSG[deps_missing]="Пакет не установлен. Установите его"
# run-step
MSG[step_ok]="%s — успешно выполнено"
MSG[step_fail]="%s — ошибка (см. %s)"
MSG[step_not_function]="'%s' не является функцией"
MSG[step_extract]="Распаковка архива"
MSG[step_repos]="Восстановление репозиториев и ключей"
MSG[step_packages]="Восстановление пакетов"
MSG[step_logs]="Восстановление логов"
MSG[step_archive]="Архив"
MSG[step_system_packages]="Системные пакеты"
MSG[step_repos_and_keys]="Источники APT и ключи"
MSG[step_logs]="Логи"
MSG[step_user_packages]="Пакеты установленные пользователем"
MSG[step_archive]="Архив"
MSG[step_backup_fail]="Резервное копирование не удалось"
# init.sh
MSG[init_start]="Инициализация каталогов"
MSG[dir_created]="Каталог создан"
MSG[dir_exists]="Каталог уже существует"
MSG[dir_create_failed]="Не удалось создать каталог"
MSG[dir_empty]="Пустой путь каталога"
MSG[msg_init_user_dirs]="Инициализация пользовательских каталогов"
MSG[msg_init_system_dirs]="Инициализация системных каталогов"
MSG[msg_unsafe_path]="Небезопасный путь"
MSG[msg_run_sudo]="Требуются права root (запустите с sudo)"
# install-man.sh
MSG[man_not_found]="Man-страницы REBK не найдены, выполняем установку..."
MSG[man_installed]="Man-страницы успешно установлены"
MSG[man_install_sudo]="Для установки man-страниц требуется root. Используйте sudo."
MSG[error_run_root]="Ошибка: скрипт должен быть запущен с правами root."
MSG[man_install_start]="==== REBK man installation started: %s ===="
MSG[directory_not_found]="Каталог %s не найден. Пропуск."
MSG[man_installed]="Установлена man-страница [%s]: %s.gz"
MSG[updating_mandb]="Обновление базы mandb..."
MSG[install_completed]="==== REBK man installation completed: %s ===="

# install.sh

# menu.sh, mediapanel
MSG[menu_home_not]="ERROR: Невозможно определить домашний каталог для пользователя"
MSG[menu_dir_not]="ERROR: Каталог пакетов не найден:"
MSG[menu_modules_dir_not]="ERROR: Каталог модулей не найден:"
MSG[menu_mediasystem_title]="РЕИНКАРНАЦИЯ КОНВЕЙЕР"
MSG[menu_sel_mode]="Выберите режим конвейера:"
MSG[menu_mode_safe]="Безопасный (минимальные модули по умолчанию)"
MSG[menu_mode_standard]="Стандартный (стандартная настройка)"
MSG[menu_mode_full]="Полный (стандартный + все дополнительные модули)"
MSG[menu_mode_choice]="Введите выбор [1-3, по умолчанию 1]: "
MSG[menu_choice_invalid]="Неверный выбор. По умолчанию используется безопасный вариант."
MSG[menu_mode_selected]="Выбранный режим:"
MSG[menu_summary]="КОНВЕЙЕР РЕЗЮМЕ"
MSG[menu_ok]="УСПЕШНО"
MSG[menu_fail]="НЕУДАЧНО"
MSG[menu_skip]="ПРОПУЩЕНО"
MSG[menu_finished]="Конвейер завершен:"
MSG[menu_write_error]="ПРЕДУПРЕЖДЕНИЕ: Невозможно записать сводку в журнал"
MSG[menu_exit]="Выход"
