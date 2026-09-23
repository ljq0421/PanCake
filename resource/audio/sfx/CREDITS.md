# 金币入账音 C03A

`coin-credit-c03a.wav`：用户于 2026-09-21 试听确认，用于天津、武汉自动入账。与确认的 C03A WAV 逐字节一致；不循环、不归一化、不做有损压缩。

来源：StarNinjas 的 [12 Coin Sound Effects](https://opengameart.org/node/123368)，原包 [coins_-_starninjas.zip](https://opengameart.org/sites/default/files/coins_-_starninjas.zip) 内的 `coin.1.ogg`、`coin.9.ogg`。许可：[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)，来源页于 2026-09-21 核查；可免费商用及修改。感谢作者 StarNinjas。

处理：裁剪、变速、三层硬币编排与增益；相对 C03 去除尾部玻璃点音及拨弦，保留原硬币层和主增益。最终音频不包含 Kenney 的玻璃、拨弦素材。

来源哈希、完整处理脚本及验证记录见项目 `docs/首页天津武汉卡通音效试听-20260921.md` 所链接的试听档案。

## 已确认的两城动作音效

2026-09-21 用户确认 K01、K02、K03、K07 及其用途。游戏 WAV 与对应试听文件逐字节一致，不归一化、不循环、不做有损压缩。运行时动作音量低于金币奖励，继续受音效及主音量控制。

| 文件 | 用途 | 作者及来源 |
| --- | --- | --- |
| action-pickup-k01.wav | 取料 | EZduzziteh，Pop sounds / pop1.wav |
| action-drop-k02.wav | 加料、落下 | EZduzziteh，Pop sounds / pop4.wav |
| action-mix-k03.wav | 涂抹、搅拌短反馈 | EZduzziteh，Pop sounds / pop7.wav，三次编排 |
| action-error-k07.wav | 操作与交付失败 | reelworldstudio，Cartoon Boing.wav |

[Pop sounds](https://opengameart.org/content/pop-sounds-0)、[Cartoon Boing](https://freesound.org/people/reelworldstudio/sounds/161122/) 均标注 CC0 1.0，来源页于 2026-09-21 核查。许可允许商业使用及修改。

K07 使用用户实际确认的 HQ MP3 预览编辑版转出的 WAV；不是无损原始录音。本次保持已确认音色，未用另一个未经试听的文件替代。其 Freesound 原始录音下载要求登录。逐条作者、许可、处理与哈希见 `action-sources.json`。

## 首页统一纸页声（当前：原创合成版，2026-09-23）

用户要求不参考现有版本，从零制作略带翻页感、非写实的卡通展开音效。当前 `home-paper-h08c.wav` 仅沿用资源路径；声音由 `tools/synthesize_book_unfold.py` 原创程序合成，不含旧版音频或第三方采样。固定随机种子的柔和带通噪声组成两段重叠纸页起伏，噪声激励共振提供轻微卡通弹性，无乐器旋律及收尾撞击。

用户追加“更多卡通感、钝感”：纸页频段降至 720–1370Hz，圆润共振降至 320–650Hz 并提高占比，加入低音量 230–380Hz 弹性滑音，整体经 1800Hz 二阶低通、40ms 柔和起音；保留两段翻动节奏，无独立弹跳落点。

用户再追加“灵动一些”：保留 1800Hz 低通及圆钝音色，将双段起伏改为轻快抬起、较轻较短的回弹；弹性滑音最高约 440Hz，略提高存在感，尾段仍自然收住。

44.1kHz、单声道 PCM16，520ms；RMS -26.00dBFS，峰值 -11.30dBFS，首尾零采样。主体随常规 520ms 展开动画的中段起伏，505ms 前收声。既有 Paper/Postcard 共用、播放时点、运行时 -4dB 及音量控制保持不变。SHA-256：`d638956e93f6f505176fa425d88be5b3a0e0caedadde9dc1eced1a207efa3945`。

### 历史纸页声 H08C（以下均已替换，非当前素材来源）

2026-09-23 轻快翻页版（最新）：用户反馈上一版不像翻页，本版将纸张层由 -39 提至 -33dBFS，滑音由 -32 降至 -35dBFS、空气声由 -35 降至 -38dBFS（均为最终混音前的层级），纸页动作约 390ms。整体仍 -29dBFS、520ms 文件、无收尾落点；沿用原 CC0 纸张与原创合成声层。

2026-09-23 轻快翻页版（最新）：用户反馈上一版不像翻页，本版将纸张层由 -39 提至 -33dBFS，滑音由 -32 降至 -35dBFS、空气声由 -35 降至 -38dBFS（均为最终混音前的层级），纸页动作约 390ms。整体仍 -29dBFS、520ms 文件、无收尾落点；沿用原 CC0 纸张与原创合成声层。

2026-09-23 轻快轻量版（最新）：按用户追加要求减少写实感，将原纸张声降低为微弱底纹（-39dBFS），主体改为原创圆润上扬滑音与平滑空气声；动作主体约 355ms，文件仍 520ms，整体 -29dBFS，不添加收尾落点。保留 Kenney 原纸张来源及 CC0 许可；其余声层为程序合成。

2026-09-23 轻快轻量版（最新）：按用户追加要求减少写实感，将原纸张声降低为微弱底纹（-39dBFS），主体改为原创圆润上扬滑音与平滑空气声；动作主体约 355ms，文件仍 520ms，整体 -29dBFS，不添加收尾落点。保留 Kenney 原纸张来源及 CC0 许可；其余声层为程序合成。

2026-09-23 卡通柔和版（当前）：用户追加要求更卡通。在柔和版纸张声上加入轻微变速起伏和原创合成的圆润滑音（340→550→340Hz，45–410ms，底层 RMS -37dBFS），整体仍为 -27dBFS、0.52 秒，无收尾落点。原纸张素材来源与许可不变。

2026-09-23 卡通柔和版（当前）：用户追加要求更卡通。在柔和版纸张声上加入轻微变速起伏和原创合成的圆润滑音（340→550→340Hz，45–410ms，底层 RMS -37dBFS），整体仍为 -27dBFS、0.52 秒，无收尾落点。原纸张素材来源与许可不变。

2026-09-23 柔和版：按用户要求更轻柔、纸张感更明显、声音更舒缓，使用原 Kenney CC0 的 card-fan-1 / card-slide-1 重新混音（42:58）；220Hz 高通、2600Hz 低通，柔化瞬态，55ms 淡入、150ms 淡出，RMS -27dBFS。保留 0.52 秒、无收尾落点和原资源路径，运行时仍为 -4dB。以下为此前版本记录。

2026-09-23 柔和版：按用户要求更轻柔、纸张感更明显、声音更舒缓，使用原 Kenney CC0 的 card-fan-1 / card-slide-1 重新混音（42:58）；220Hz 高通、2600Hz 低通，柔化瞬态，55ms 淡入、150ms 淡出，RMS -27dBFS。保留 0.52 秒、无收尾落点和原资源路径，运行时仍为 -4dB。以下为此前版本记录。

`home-paper-h08c.wav`：用户要求手账打开、明信片落下、手账翻页统一使用 H08B，并去掉收尾落点。H08C 仅删除 H08B 在 425ms 处的 pop9 层，纸页两层、原主增益、0.52 秒长度保持不变，前 425ms 逐样本一致。运行时 -4dB，导入不压缩、不归一化、不循环。

最终素材只包含 Kenney [Casino Audio](https://kenney.nl/assets/casino-audio) 中 `card-fan-1.ogg` 和 `card-slide-1.ogg`，CC0 1.0；裁剪、低通、时间延展与叠层编排，无泡泡收尾。SHA-256：`ff970c7a6c0b247f30c90186551cde65cbfc33a6bd1ffacf51c8281f41bbd26b`。完整处理见试听档案 `finalize_paper.py` 与 `paper-final/manifest.json`。

## 首页点击 H05（来源详情）

`home-click-h05.wav`：用户于 2026-09-21 确认，用于现有 `OpeningCue.Click` 入口（新旅程开始、出发）。源自 EZduzziteh 的 [Pop sounds](https://opengameart.org/content/pop-sounds-0) 中 `pop2.wav`，CC0 1.0。

处理：去近静音首尾、1.08 倍速、5ms 淡入淡出、试听增益调整。游戏内增益 -4dB，仍跟随主音量和音效音量；导入不压缩、不归一化、不循环。文件与确认的 H05 逐字节一致，SHA-256：`2d2385bc50ba2b4010f8f0c778bba6fd965afdc68869de39516df53296cf2ad0`。

## 订单完成 K11B

`order-complete-k11b.wav`：用户于 2026-09-21 确认，用于天津、武汉最终订单完成；不用于部分交付或制作就绪。源自 Kenney 的 [Music Jingles](https://kenney.nl/assets/music-jingles)，`jingles_STEEL00.ogg`，CC0 1.0。

处理：截取钢鼓首音，按 0/+4/+7/+12 半音上扬编排；保留 K11A 的音高、时序与 0.60 秒长度，增加 1400Hz 高频搁架 -6dB 及 3200Hz 二阶低通，匹配原版平均 RMS。游戏文件与确认 K11B 逐字节一致；运行时 -4dB，不压缩、不循环、不归一化，继续受音效及主音量控制。完整来源、处理与哈希见试听档案 `paper-round3/manifest.json`。

## 订单完成 K11B

`order-complete-k11b.wav`：用户于 2026-09-21 确认，用于天津、武汉最终订单完成；不用于部分交付或制作就绪。源自 Kenney 的 [Music Jingles](https://kenney.nl/assets/music-jingles)，`jingles_STEEL00.ogg`，CC0 1.0。

处理：截取钢鼓首音，按 0/+4/+7/+12 半音上扬编排；保留 K11A 的音高、时序与 0.60 秒长度，增加 1400Hz 高频搁架 -6dB 及 3200Hz 二阶低通，匹配原版平均 RMS。游戏文件与确认 K11B 逐字节一致；运行时 -4dB，不压缩、不循环、不归一化，继续受音效及主音量控制。完整来源、处理与哈希见试听档案 `paper-round3/manifest.json`。

## 首页点击 H05

`home-click-h05.wav`：用户于 2026-09-21 确认，用于现有 `OpeningCue.Click` 入口（新旅程开始、出发）。源自 EZduzziteh 的 [Pop sounds](https://opengameart.org/content/pop-sounds-0) 中 `pop2.wav`，CC0 1.0。

处理：去近静音首尾、1.08 倍速、5ms 淡入淡出、试听增益调整。游戏内增益 -4dB，仍跟随主音量和音效音量；导入不压缩、不归一化、不循环。文件与确认的 H05 逐字节一致，SHA-256：`2d2385bc50ba2b4010f8f0c778bba6fd965afdc68869de39516df53296cf2ad0`。

## 已确认的两城动作音效

2026-09-21 用户确认 K01、K02、K03、K07 及其用途。游戏 WAV 与对应试听文件逐字节一致，不归一化、不循环、不做有损压缩。运行时动作音量低于金币奖励，继续受音效及主音量控制。

| 文件 | 用途 | 作者及来源 |
| --- | --- | --- |
| action-pickup-k01.wav | 取料 | EZduzziteh，Pop sounds / pop1.wav |
| action-drop-k02.wav | 加料、落下 | EZduzziteh，Pop sounds / pop4.wav |
| action-mix-k03.wav | 涂抹、搅拌短反馈 | EZduzziteh，Pop sounds / pop7.wav，三次编排 |
| action-error-k07.wav | 操作与交付失败 | reelworldstudio，Cartoon Boing.wav |

[Pop sounds](https://opengameart.org/content/pop-sounds-0)、[Cartoon Boing](https://freesound.org/people/reelworldstudio/sounds/161122/) 均标注 CC0 1.0，来源页于 2026-09-21 核查。许可允许商业使用及修改。

K07 使用用户实际确认的 HQ MP3 预览编辑版转出的 WAV；不是无损原始录音。本次保持已确认音色，未用另一个未经试听的文件替代。其 Freesound 原始录音下载要求登录。逐条作者、许可、处理与哈希见 `action-sources.json`。
