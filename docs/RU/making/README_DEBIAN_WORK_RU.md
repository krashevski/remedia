# Remedia - работа с .deb пакетом

## Перед сборкой .deb пакета

### Проверить синтаксис изменённого файла
К примеру:
```bash
cd ~/scripts/remedia
bash -n modules/mediapanel/core/project_core.sh
```

* Если проверка ничего не показала, то ошибок нет.
### Поиск всех мест, где указана версия
```bash
grep -RIn -E 'Version:|VERSION=|VERSION =|version=' ./DEBIAN
```

1. Ожидаемый результат:
```bash
./DEBIAN/build.sh:7:VERSION="1.0.0"
./DEBIAN/control:2:Version: 1.0.0
```

2. И изменить номер версии в каждом файле на новый, например 1.1.0.

### Найти все упоминания текущей версии
```bash
grep -RIn --exclude-dir=.git '1\.0\.0' ./DEBIAN
```

### Проверка версии в уже собранном .deb
```bash
dpkg-deb -f build/remedia_1.1.0_all.deb Version
```

* Ожидаемый результат: 1.1.0

## Cоздание .deb пакета

Запуск из корня проекта, если сам build.sh рассчитан на структуру remedia/:
```bash
cd ~/scripts/remedia
./DEBIAN/build.sh
```

* Результатом должно быть: 
```bash
[BUILD] done
```

* Запуск из корня проекта обычно надёжнее, потому что скрипт может использовать относительные пути вроде:
```bash
build/
DEBIAN/
usr/
etc/
```

## Проверка перед установкой содержимого пакета

```bash
dpkg-deb -c build/remedia_1.1.0_all.deb
```

* Посмотреть, присутствуют ли последние изменения

## Установка .deb пакета

```bash
cd ~/scripts/remedia
sudo apt install ./build/remedia_1.1.0_all.deb
```

* Это предпочтительнее dpkg -i, потому что apt заодно обработает зависимости.

## После установки

Проверка:
```bash
dpkg -s remedia
```

Проверка диагностической команды Remedia:
```bash
remedia doctor
```

Обычный	запуск Remedia:
```bash
remedia
```

## Важный порядок при выпуске новой версии

1. Найти старую версию:
```bash
grep -RIn --exclude-dir=.git '1\.0\.0' .
```
2. Изменить все необходимые места.

3. Проверить, что старая версия больше не осталась:
```bash
grep -RIn --exclude-dir=.git '1\.0\.0' .
```

4. Собрать:
```bash
./DEBIAN/build.sh
```

5. Проверить версию готового пакета:
```bash
dpkg-deb -f build/remedia_1.1.0_all.deb Version
```

6. Можно устанавливать:
```bash
sudo apt install ./build/remedia_1.1.0_all.deb
```



