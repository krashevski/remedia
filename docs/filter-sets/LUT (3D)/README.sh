# Использование фильтров LUT(3D)

## Как применять LUT (3D) в Shotcut

Если исходник действительно HLG, можно добавить фильтр LUT (3D) и открыть 3-NBCU_HLG2SDR_DL_Adobe_v1.2.cube.
Не следует последовательно применять несколько LUT преобразования HDR/SDR без конкретной цели.


## файлы для преобразования между стандартами HDR и SDR

Если исходное видео снято в обычном SDR (Rec.709), а результат предназначен для YouTube Shorts в SDR, такое преобразование не требуется.
| LUT | Назначение | Когда применять |
|---|---|---|
| `1-NBCU_SDR2HLG_DL_Adobe_v1.2.cube` | SDR → HLG | Подготовка SDR для HDR-производства |
| `2-NBCU_SDR2HLG_SL_Adobe_v1.2.cube` | SDR → HLG | Альтернативный вариант SDR → HLG |
| `3-NBCU_HLG2SDR_DL_Adobe_v1.2.cube` | HLG → SDR | Преобразование HDR HLG в обычное SDR |
| `3b-Gamma.1.08-Philips-NBCU-HLG2SDR-DL_VRT_v1.2.cube` | HLG → SDR с дополнительной гамма-коррекцией | Специальный вариант преобразования HLG |
| `4-NBCU_SDR2PQ_DL_Adobe_v1.2.cube` | SDR → PQ | Подготовка SDR для HDR PQ |
| `5-NBCU_PQ2SDR_DL_Adobe_v1.2.cube` | PQ → SDR | Преобразование HDR PQ в SDR |
| `Magic_Lantern_Video.cube` | LUT для определённого видеопрофиля Magic Lantern | Только при совместимом исходном материале |
| `MovieLabs_PQ4000_Full_to_HLG-Legal_MaxRGB_33Point_TypeIII.cube` | PQ 4000 → HLG | Специализированное HDR-преобразование |
| `MovieLabs_PQ4000Full_to_HLG-Legal_MaxRGB_65Point_TypeIII.cube` | PQ 4000 → HLG | Аналогичное преобразование с более плотной таблицей |
