# 私人音乐播放器 设计文档

> 版本：v1.0 | 日期：2026-03-27

---

## 一、项目概述

基于 GD Studio 音乐 API，构建一款**纯本地数据**的私人音乐播放器，同时覆盖手机端（App）和电视端（TV）。所有用户数据（歌单、收藏、历史、缓存）均存储在设备本地，不与任何服务器同步。

---

## 二、技术选型

| 层级 | 选型 | 说明 |
|------|------|------|
| 跨平台框架 | **Flutter 3.x** | 一套代码覆盖 Android / iOS / Android TV |
| 状态管理 | **Riverpod 2.x** | 可测试、无全局副作用 |
| 本地数据库 | **Drift (SQLite)** | 强类型 ORM，支持复杂查询 |
| 音频播放 | **just_audio** | 支持 HLS、在线流、本地文件 |
| 网络请求 | **Dio** | 拦截器统一处理限流、错误 |
| 本地缓存 | **dio_cache_interceptor + 自定义磁盘管理** | 按大小上限 LRU 淘汰 |
| 图片缓存 | **cached_network_image** | 封面图自动缓存 |
| 歌词解析 | 自实现 LRC parser | 支持双语时间轴对齐 |
| TV 焦点 | Flutter 原生 `FocusNode` + 自定义 `FocusTraversalPolicy` | 遥控器方向键导航 |

---

## 三、系统架构

```
┌─────────────────────────────────────────────────────┐
│                    Presentation Layer                │
│   Mobile UI (screens/)    TV UI (tv_screens/)        │
│   共用 Widgets (widgets/)                            │
└────────────────────┬────────────────────────────────┘
                     │ Riverpod Providers
┌────────────────────▼────────────────────────────────┐
│                  Application Layer                   │
│  PlayerNotifier  PlaylistNotifier  SearchNotifier    │
│  FavoriteNotifier  HistoryNotifier  SettingsNotifier │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│                  Domain Layer                        │
│  Song / Playlist / Lyric / CacheEntry  (models)      │
│  Repository interfaces                               │
└──────┬─────────────────────────┬────────────────────┘
       │                         │
┌──────▼──────────┐   ┌──────────▼──────────────────┐
│  Remote Layer   │   │       Local Layer            │
│  MusicApiClient │   │  Drift DB  |  DiskCacheRepo  │
│  (Dio)          │   │  (歌单/收藏/历史/设置)         │
└─────────────────┘   └─────────────────────────────┘
```

---

## 四、数据模型设计

### 4.1 数据库表（Drift）

```sql
-- 歌曲基本信息（搜索结果或历史缓存）
CREATE TABLE songs (
  id          TEXT NOT NULL,
  source      TEXT NOT NULL,         -- netease / kuwo / joox 等
  name        TEXT NOT NULL,
  artist      TEXT NOT NULL,         -- JSON array string
  album       TEXT NOT NULL,
  pic_id      TEXT NOT NULL,
  lyric_id    TEXT NOT NULL,
  PRIMARY KEY (id, source)
);

-- 歌单
CREATE TABLE playlists (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);

-- 歌单-歌曲关联
CREATE TABLE playlist_songs (
  playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
  song_id     TEXT NOT NULL,
  source      TEXT NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  added_at    INTEGER NOT NULL
);

-- 收藏
CREATE TABLE favorites (
  song_id     TEXT NOT NULL,
  source      TEXT NOT NULL,
  added_at    INTEGER NOT NULL,
  PRIMARY KEY (song_id, source)
);

-- 播放历史
CREATE TABLE play_history (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  song_id     TEXT NOT NULL,
  source      TEXT NOT NULL,
  played_at   INTEGER NOT NULL,
  play_count  INTEGER NOT NULL DEFAULT 1
);

-- 当前播放队列（持久化）
CREATE TABLE play_queue (
  position    INTEGER PRIMARY KEY,
  song_id     TEXT NOT NULL,
  source      TEXT NOT NULL
);

-- 设置（Key-Value）
CREATE TABLE settings (
  key         TEXT PRIMARY KEY,
  value       TEXT NOT NULL
);
```

### 4.2 设置项 Key 列表

| Key | 默认值 | 说明 |
|-----|--------|------|
| `default_source` | `netease` | 默认音乐源 |
| `audio_quality` | `320` | 音质 128/192/320/740/999 |
| `cache_max_mb` | `512` | 缓存上限（MB） |
| `play_mode` | `sequence` | sequence / shuffle / repeat_one / repeat_all |
| `lyric_translation` | `true` | 显示中文翻译歌词 |
| `search_history` | `[]` | JSON 最近搜索词列表（最多20条） |

---

## 五、功能模块详细设计

### 5.1 搜索模块

**流程：**
1. 用户输入关键词 → 防抖 500ms → 调用搜索 API
2. API 参数：`source`（用户设置的默认源）、`name`、`count=20`、`pages=1`
3. 支持下拉加载更多（pages 递增）
4. 搜索结果展示：封面图 + 歌名 + 歌手 + 专辑
5. 每条结果操作：播放 / 加入队列末尾 / 下一首播放 / 加入歌单 / 收藏

**搜索历史：**
- 本地存储最近 20 条，展示在搜索框下方
- 支持单条删除、清空全部

**限流保护：**
- 本地维护请求计数器，5 分钟窗口内超过 45 次时，Toast 提示"请求频繁，请稍后再试"并阻断新请求

### 5.2 播放器模块

**核心状态（PlayerNotifier）：**
```dart
class PlayerState {
  final Song? currentSong;
  final PlayMode playMode;        // sequence/shuffle/repeat_one/repeat_all
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<Song> queue;
  final int currentIndex;
}
```

**播放流程：**
1. 点击播放 → 检查本地缓存文件是否存在
2. 命中缓存 → 直接播放本地文件
3. 未命中 → 调用 URL API 获取在线地址 → 开始播放同时异步写入缓存
4. 播放成功 → 写入播放历史（同一首歌当天多次播放只更新 `play_count`）

**播放模式切换逻辑：**
- `sequence` → `shuffle` → `repeat_all` → `repeat_one` → 循环

**上下首逻辑：**
- `shuffle`：从队列中随机取未播放歌曲，全部播完后重新洗牌
- `repeat_one`：当前歌曲重新播放（上一首/下一首按钮跳过到相邻歌曲）

### 5.3 播放队列模块

- 显示当前队列，支持拖拽排序
- 支持「下一首播放」（插入当前位置 +1）
- 支持删除单首
- 支持清空队列
- 队列持久化到 `play_queue` 表，App 重启恢复上次状态

### 5.4 歌单模块

- 创建歌单（输入名称）
- 删除歌单（二次确认）
- 歌单详情页显示歌曲列表，支持拖拽排序
- 歌曲从歌单移除（不删除 songs 表数据）
- 批量选择 → 批量移除 / 批量加入播放队列
- 歌单支持重命名

### 5.5 收藏模块

- 收藏/取消收藏（Heart 图标，所有有歌曲的地方均可触发）
- 收藏列表按 `added_at` 倒序
- 支持批量操作（批量加入歌单/队列）

### 5.6 播放历史模块

- 按日期分组展示（今天 / 昨天 / 更早）
- 显示每首歌累计播放次数
- 支持清空全部历史

### 5.7 歌词模块

**LRC 解析：**
- 解析 `[mm:ss.xx]` 格式时间轴
- 双语模式：将 `lyric`（原文）和 `tlyric`（译文）按时间轴合并，同一时间点显示两行
- 歌词随播放进度自动滚动，当前行高亮并居中
- 点击歌词行 → 跳转到对应播放时间点（scrubbing）

**缓存：**
- 歌词内容缓存到本地文件（`<cache_dir>/lyrics/<source>_<lyric_id>.json`）

### 5.8 缓存模块

**策略：**
- 音频文件保存至 `<cache_dir>/audio/<source>_<id>_<br>.mp3`
- 采用 LRU 算法：当总大小超过用户设置上限时，删除最久未播放的缓存文件
- 缓存元数据（文件路径、大小、最后访问时间）存储在 SQLite 附加表 `cache_entries` 中
- 设置页展示：当前使用量 / 上限（进度条），提供「立即清空缓存」按钮

**缓存表：**
```sql
CREATE TABLE cache_entries (
  file_path      TEXT PRIMARY KEY,
  song_id        TEXT NOT NULL,
  source         TEXT NOT NULL,
  file_size_kb   INTEGER NOT NULL,
  last_accessed  INTEGER NOT NULL
);
```

### 5.9 设置页

| 选项 | 类型 | 说明 |
|------|------|------|
| 默认音乐源 | 下拉选择 | netease / kuwo / joox / bilibili |
| 音质偏好 | 下拉选择 | 128 / 192 / 320 / 740(无损) / 999(无损) |
| 缓存上限 | 滑块 | 128MB ~ 4096MB |
| 当前缓存占用 | 只读展示 | 显示已用空间 |
| 清空缓存 | 按钮 | 二次确认后删除所有缓存文件 |
| 歌词翻译 | 开关 | 是否显示中文翻译歌词 |
| 离线模式 | 开关 | 开启后只播放已缓存歌曲 |

---

## 六、UI 页面设计（App 版）

### 6.1 页面结构

```
底部导航栏（4 个 Tab）
├── 发现（搜索首页）
├── 我的歌单
├── 收藏
└── 设置

全局悬浮迷你播放器（底部，TabBar 之上）
全屏播放器页（从迷你播放器上滑展开）
```

### 6.2 各页面要素

**发现页**
- 顶部搜索框（常驻）
- 未搜索时：显示播放历史（最近10首）+ 搜索历史词
- 搜索后：搜索结果列表（支持分页加载）

**我的歌单页**
- 右上角「+」创建歌单
- 歌单列表（封面取第一首歌的封面，无歌曲时显示默认图）
- 点击进入歌单详情

**歌单详情页**
- 歌单名（可点击重命名）
- 「播放全部」「随机播放」按钮
- 歌曲列表（可拖拽排序，长按进入批量选择模式）

**全屏播放器页**
- 专辑封面（旋转动画）
- 歌名 + 歌手
- 收藏按钮
- 进度条（支持拖拽）
- 播放控制区（上一首、播放/暂停、下一首、播放模式切换）
- 歌词区（下半屏，可上滑展开全屏歌词）
- 右上角队列按钮（弹出当前队列抽屉）

---

## 七、TV 版适配

### 7.1 布局差异

- 采用**左右两栏**布局替代底部 TabBar
  - 左栏：导航侧边栏（可收起）
  - 右栏：内容区
- 字体尺寸放大 1.5x，行间距加大
- 所有可交互元素尺寸不小于 48dp，焦点边框清晰可见

### 7.2 遥控器交互

| 按键 | 行为 |
|------|------|
| 方向键 | 焦点移动 |
| 确认键 | 点击 |
| 返回键 | 返回上一级 / 退出全屏播放器 |
| 播放/暂停键 | 控制播放（媒体键） |
| 快进/快退 | 进度 +/- 10s |

- 使用 `FocusTraversalGroup` 划分区域（侧边栏 / 内容区 / 播放控制栏），防止焦点越界
- 全屏播放器：播放控制条在底部，焦点默认在播放/暂停按钮，3秒无操作自动隐藏控制条

### 7.3 TV 专属页面

- **全屏歌词模式**：左侧显示大封面，右侧双栏歌词（原文 + 译文），字号 24sp+
- 主页展示播放历史卡片流（横向滚动）

---

## 八、API 集成设计

### 8.1 请求封装

```
MusicApiClient（Dio）
├── RateLimitInterceptor    -- 5分钟窗口 45次上限，本地令牌桶
├── RetryInterceptor        -- 网络超时自动重试1次
└── ErrorInterceptor        -- 统一错误转换为 AppError

方法：
  searchSongs(source, keyword, count, page)   → List<Song>
  searchAlbum(source, keyword, count, page)   → List<Song>
  getSongUrl(source, id, br)                  → SongUrl
  getPicUrl(source, picId, size)              → String
  getLyric(source, lyricId)                   → Lyric
```

### 8.2 图片加载策略

- 列表中使用 300px 封面图
- 播放器全屏使用 500px 封面图
- 通过 `cached_network_image` 自动磁盘缓存（独立于音频缓存，不计入缓存上限）

### 8.3 离线模式

- `SettingsNotifier` 中 `isOfflineMode == true` 时：
  - 屏蔽所有 API 请求（搜索、获取 URL、歌词请求均返回错误提示）
  - 播放时直接查 `cache_entries` 表，命中则播放，未命中则跳过并 Toast 提示

---

## 九、开发里程碑

### Phase 1 — 核心播放（2周）
- [ ] 项目初始化（Flutter + Riverpod + Drift）
- [ ] API Client 封装（搜索、URL、歌词、封面）
- [ ] 基础数据库 Schema
- [ ] 搜索页 + 搜索结果展示
- [ ] 播放器内核（just_audio + PlayerNotifier）
- [ ] 迷你播放器 + 全屏播放器 UI
- [ ] 播放队列（添加、删除、顺序播放、随机播放）

### Phase 2 — 数据管理（1.5周）
- [ ] 歌单 CRUD
- [ ] 收藏功能
- [ ] 播放历史
- [ ] 搜索历史
- [ ] 音频缓存 + LRU 淘汰
- [ ] 歌词显示（LRC 解析 + 滚动高亮 + 双语）

### Phase 3 — 完善体验（1周）
- [ ] 设置页（音质、缓存上限、音乐源、离线模式）
- [ ] 批量操作（多选）
- [ ] 播放队列拖拽排序
- [ ] 限流保护 + 错误提示
- [ ] 专辑搜索模式

### Phase 4 — TV 适配（1.5周）
- [ ] TV 布局框架（两栏 + 侧边栏）
- [ ] FocusTraversal 遥控器导航
- [ ] 全屏歌词模式
- [ ] TV 播放控制栏（媒体键支持）
- [ ] 字体 / 控件尺寸适配

---

## 十、目录结构建议

```
lib/
├── main.dart
├── app.dart                    # MaterialApp / TV 主题切换
├── core/
│   ├── api/                    # MusicApiClient + 拦截器
│   ├── db/                     # Drift database + DAOs
│   ├── models/                 # Song, Playlist, Lyric, etc.
│   └── utils/                  # lrc_parser, rate_limiter, cache_manager
├── features/
│   ├── player/                 # PlayerNotifier + just_audio 封装
│   ├── search/                 # SearchNotifier + 搜索页
│   ├── playlist/               # 歌单管理
│   ├── favorite/               # 收藏
│   ├── history/                # 播放历史
│   ├── lyric/                  # 歌词解析 + 展示
│   └── settings/               # 设置
├── mobile/                     # 手机端专属 Screens + Widgets
└── tv/                         # TV 端专属 Screens + Widgets
```
