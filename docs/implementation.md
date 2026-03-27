# 私人音乐播放器 落地实施文档

> 版本：v1.0 | 日期：2026-03-27 | 依据：设计文档 v1.0

---

## 一、项目目标总结（工程视角）

### 1.1 核心约束

| 约束维度 | 描述 |
|---------|------|
| 平台覆盖 | Android / iOS（Mobile）、Android TV（TV），一套代码库 |
| 数据主权 | 所有持久化数据（歌单、收藏、历史、设置、缓存元数据）100% 本地存储，零服务端同步 |
| 外部依赖 | 仅依赖 GD Studio 音乐 API，用于搜索、获取播放 URL、封面图、歌词 |
| 离线能力 | 支持离线模式，已缓存的音频可在无网络下完整播放 |
| 缓存约束 | 音频缓存采用 LRU 淘汰策略，大小上限用户可配置（128MB ~ 4096MB） |

### 1.2 工程范围（In Scope）

- Flutter 单 Repo，支持 Android / iOS / Android TV 三个 Target
- 9 个核心功能模块：搜索、播放器、播放队列、歌单、收藏、播放历史、歌词、缓存、设置
- Mobile UI（底部导航 + 全屏播放器）
- TV UI（左右两栏 + 遥控器焦点导航）
- GD Studio API 集成（含限流保护、重试、错误转换）

### 1.3 工程范围（Out of Scope）

- 用户账号体系
- 云端同步
- 社交或分享功能
- 音乐版权处理（由 API 提供方负责）

---

## 二、架构落地方案

### 2.1 Flutter 工程目录结构（最终版）

```
lib/
├── main.dart                          # 入口，区分 mobile / tv 模式
├── app.dart                           # MaterialApp + 主题配置
│
├── core/
│   ├── api/
│   │   ├── music_api_client.dart      # Dio 封装，统一请求入口
│   │   ├── interceptors/
│   │   │   ├── rate_limit_interceptor.dart
│   │   │   ├── retry_interceptor.dart
│   │   │   └── error_interceptor.dart
│   │   └── models/                    # API 响应 DTO
│   │       ├── song_dto.dart
│   │       ├── song_url_dto.dart
│   │       └── lyric_dto.dart
│   │
│   ├── db/
│   │   ├── app_database.dart          # Drift Database 根类
│   │   ├── tables/                    # 各表定义
│   │   │   ├── songs_table.dart
│   │   │   ├── playlists_table.dart
│   │   │   ├── playlist_songs_table.dart
│   │   │   ├── favorites_table.dart
│   │   │   ├── play_history_table.dart
│   │   │   ├── play_queue_table.dart
│   │   │   ├── settings_table.dart
│   │   │   └── cache_entries_table.dart
│   │   └── daos/                      # DAO 各模块
│   │       ├── songs_dao.dart
│   │       ├── playlists_dao.dart
│   │       ├── favorites_dao.dart
│   │       ├── history_dao.dart
│   │       ├── queue_dao.dart
│   │       ├── settings_dao.dart
│   │       └── cache_dao.dart
│   │
│   ├── models/                        # Domain 实体（纯 Dart，不依赖 Flutter）
│   │   ├── song.dart
│   │   ├── playlist.dart
│   │   ├── lyric.dart
│   │   ├── lyric_line.dart
│   │   ├── cache_entry.dart
│   │   └── enums.dart                 # PlayMode, AudioQuality, MusicSource
│   │
│   └── utils/
│       ├── lrc_parser.dart            # LRC 格式解析
│       ├── rate_limiter.dart          # 本地令牌桶
│       ├── cache_manager.dart         # LRU 磁盘缓存管理
│       └── platform_detector.dart    # 检测是否为 TV 环境
│
├── features/
│   ├── player/
│   │   ├── player_notifier.dart
│   │   ├── player_repository.dart
│   │   └── just_audio_player.dart    # just_audio 封装
│   │
│   ├── search/
│   │   ├── search_notifier.dart
│   │   └── search_repository.dart
│   │
│   ├── playlist/
│   │   ├── playlist_notifier.dart
│   │   └── playlist_repository.dart
│   │
│   ├── favorite/
│   │   ├── favorite_notifier.dart
│   │   └── favorite_repository.dart
│   │
│   ├── history/
│   │   ├── history_notifier.dart
│   │   └── history_repository.dart
│   │
│   ├── lyric/
│   │   ├── lyric_notifier.dart
│   │   └── lyric_repository.dart
│   │
│   ├── cache/
│   │   ├── cache_notifier.dart
│   │   └── cache_repository.dart
│   │
│   └── settings/
│       ├── settings_notifier.dart
│       └── settings_repository.dart
│
├── mobile/
│   ├── app_shell.dart                 # 底部导航 + 迷你播放器
│   ├── screens/
│   │   ├── home_screen.dart           # 发现页
│   │   ├── playlist_screen.dart       # 我的歌单
│   │   ├── playlist_detail_screen.dart
│   │   ├── favorite_screen.dart
│   │   ├── history_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── full_player_screen.dart    # 全屏播放器
│   │   ├── full_lyric_screen.dart     # 全屏歌词
│   │   └── play_queue_drawer.dart     # 播放队列抽屉
│   └── widgets/
│       ├── song_list_item.dart
│       ├── mini_player.dart
│       ├── album_cover_rotator.dart
│       ├── lyric_scroll_view.dart
│       ├── playlist_card.dart
│       └── cache_usage_bar.dart
│
└── tv/
    ├── tv_app_shell.dart              # 左侧边栏 + 内容区
    ├── screens/
    │   ├── tv_home_screen.dart
    │   ├── tv_playlist_screen.dart
    │   ├── tv_full_player_screen.dart
    │   └── tv_full_lyric_screen.dart
    └── widgets/
        ├── tv_nav_sidebar.dart
        ├── tv_focus_card.dart         # 带焦点光晕的通用卡片
        ├── tv_player_control_bar.dart
        └── tv_lyric_panel.dart
```

### 2.2 各层职责

| 层 | 所在目录 | 职责 | 禁止依赖 |
|----|---------|------|---------|
| **Presentation** | `mobile/` `tv/` | Widget 树渲染、用户手势响应、调用 Provider | 直接访问 DAO / API |
| **Application** | `features/*/notifier` | 业务状态管理，协调 Repository，暴露不可变状态流 | 直接调用 Dio / Drift |
| **Domain** | `core/models/` | 纯数据实体，无 Flutter 依赖，定义 Repository 接口 | 任何具体实现 |
| **Data** | `core/api/` `core/db/` `features/*/repository` | Repository 实现，DAO 操作，API 调用，缓存读写 | Flutter Widget |

### 2.3 Provider 结构（Riverpod）

```
// 基础设施层 Provider
appDatabaseProvider          → AppDatabase（Drift 单例）
musicApiClientProvider       → MusicApiClient（Dio 单例）
rateLimiterProvider          → RateLimiter（令牌桶）

// Repository Provider（各自注入上层依赖）
searchRepositoryProvider     → SearchRepository(apiClient)
playerRepositoryProvider     → PlayerRepository(apiClient, db)
playlistRepositoryProvider   → PlaylistRepository(db)
favoriteRepositoryProvider   → FavoriteRepository(db)
historyRepositoryProvider    → HistoryRepository(db)
lyricRepositoryProvider      → LyricRepository(apiClient)
cacheRepositoryProvider      → CacheRepository(db)
settingsRepositoryProvider   → SettingsRepository(db)

// Notifier Provider（注入 Repository）
searchNotifierProvider       → SearchNotifier.family(keyword)
playerNotifierProvider       → PlayerNotifier(playerRepo, historyRepo, cacheRepo, settingsRepo)
playlistNotifierProvider     → PlaylistNotifier(playlistRepo)
favoriteNotifierProvider     → FavoriteNotifier(favoriteRepo)
historyNotifierProvider      → HistoryNotifier(historyRepo)
lyricNotifierProvider        → LyricNotifier.family(songId, source)
cacheNotifierProvider        → CacheNotifier(cacheRepo, settingsRepo)
settingsNotifierProvider     → SettingsNotifier(settingsRepo)
```

**关键原则：**
- 每个 Repository Provider 注入所需的基础 Provider，**不跨 Repository 共享 DAO**
- `PlayerNotifier` 依赖多个 Repository（播放 + 历史 + 缓存 + 设置），这是唯一允许的多依赖 Notifier
- 所有 Provider 均为 `final`，状态变更通过 `Notifier` 的方法触发

### 2.4 Repository 设计规范

每个 Repository 遵循统一接口模式：

```dart
// 示例 interface（Domain 层定义）
abstract class IPlaylistRepository {
  Stream<List<Playlist>> watchAllPlaylists();
  Future<Playlist> createPlaylist(String name);
  Future<void> renamePlaylist(int id, String newName);
  Future<void> deletePlaylist(int id);
  Stream<List<Song>> watchPlaylistSongs(int playlistId);
  Future<void> addSongToPlaylist(int playlistId, Song song);
  Future<void> removeSongFromPlaylist(int playlistId, String songId, String source);
  Future<void> reorderSong(int playlistId, int oldIndex, int newIndex);
}

// 实现在 Data 层
class PlaylistRepository implements IPlaylistRepository {
  final PlaylistsDao _dao;
  PlaylistRepository(this._dao);
  // ... 实现
}
```

---

## 三、数据库落地方案

### 3.1 Drift 表结构

#### songs 表

```dart
class Songs extends Table {
  TextColumn get id      => text()();
  TextColumn get source  => text()();           // netease/kuwo/joox/bilibili
  TextColumn get name    => text()();
  TextColumn get artist  => text()();           // JSON: ["歌手A","歌手B"]
  TextColumn get album   => text()();
  TextColumn get picId   => text()();
  TextColumn get lyricId => text()();

  @override
  Set<Column> get primaryKey => {id, source};
}
```

#### playlists 表

```dart
class Playlists extends Table {
  IntColumn get id        => integer().autoIncrement()();
  TextColumn get name     => text()();
  IntColumn  get createdAt => integer()();      // Unix timestamp ms
  IntColumn  get updatedAt => integer()();
}
```

#### playlist_songs 表

```dart
class PlaylistSongs extends Table {
  IntColumn  get playlistId => integer().references(Playlists, #id)();
  TextColumn get songId     => text()();
  TextColumn get source     => text()();
  IntColumn  get sortOrder  => integer().withDefault(const Constant(0))();
  IntColumn  get addedAt    => integer()();
}
```

#### favorites 表

```dart
class Favorites extends Table {
  TextColumn get songId  => text()();
  TextColumn get source  => text()();
  IntColumn  get addedAt => integer()();

  @override
  Set<Column> get primaryKey => {songId, source};
}
```

#### play_history 表

```dart
class PlayHistory extends Table {
  IntColumn  get id        => integer().autoIncrement()();
  TextColumn get songId    => text()();
  TextColumn get source    => text()();
  IntColumn  get playedAt  => integer()();      // 最后一次播放时间
  IntColumn  get playCount => integer().withDefault(const Constant(1))();
}
```

**play_history 唯一约束**：`(songId, source)` 业务上唯一，通过 DAO 层的 upsert 保证（同一首歌存一条记录，更新 playedAt 和 playCount）。

#### play_queue 表

```dart
class PlayQueue extends Table {
  IntColumn  get position => integer()();       // PRIMARY KEY，即排列顺序
  TextColumn get songId   => text()();
  TextColumn get source   => text()();

  @override
  Set<Column> get primaryKey => {position};
}
```

#### settings 表

```dart
class Settings extends Table {
  TextColumn get key   => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
```

#### cache_entries 表

```dart
class CacheEntries extends Table {
  TextColumn get filePath     => text()();      // PRIMARY KEY
  TextColumn get songId       => text()();
  TextColumn get source       => text()();
  IntColumn  get fileSizeKb   => integer()();
  IntColumn  get lastAccessed => integer()();   // Unix timestamp ms，用于 LRU

  @override
  Set<Column> get primaryKey => {filePath};
}
```

### 3.2 DAO 设计

#### SongsDao

```dart
@DriftAccessor(tables: [Songs])
class SongsDao extends DatabaseAccessor<AppDatabase> with _$SongsDaoMixin {
  // 批量 upsert（搜索结果写入）
  Future<void> upsertSongs(List<SongsCompanion> songs);
  // 查单首
  Future<SongData?> getSong(String id, String source);
}
```

#### PlaylistsDao

```dart
@DriftAccessor(tables: [Playlists, PlaylistSongs, Songs])
class PlaylistsDao extends DatabaseAccessor<AppDatabase> {
  Stream<List<PlaylistData>> watchAll();
  Future<int> insert(PlaylistsCompanion playlist);       // 返回新 id
  Future<void> rename(int id, String name);
  Future<void> delete(int id);                           // CASCADE 自动删关联
  Stream<List<SongData>> watchSongs(int playlistId);
  Future<void> addSong(int playlistId, SongsCompanion song, int sortOrder);
  Future<void> removeSong(int playlistId, String songId, String source);
  Future<void> updateSortOrders(int playlistId, List<MapEntry<String, int>> orders);
}
```

#### FavoritesDao

```dart
@DriftAccessor(tables: [Favorites, Songs])
class FavoritesDao extends DatabaseAccessor<AppDatabase> {
  Stream<List<SongData>> watchAll();                     // JOIN songs
  Future<void> add(String songId, String source, int addedAt);
  Future<void> remove(String songId, String source);
  Future<bool> isFavorite(String songId, String source);
}
```

#### HistoryDao

```dart
@DriftAccessor(tables: [PlayHistory, Songs])
class HistoryDao extends DatabaseAccessor<AppDatabase> {
  // 返回按 playedAt 倒序，JOIN songs
  Stream<List<HistoryWithSong>> watchAll();
  // 同一首歌当天多次播放：先查是否存在，存在则 UPDATE playedAt + playCount++
  Future<void> upsertPlay(String songId, String source, int playedAt);
  Future<void> clearAll();
}
```

#### QueueDao

```dart
@DriftAccessor(tables: [PlayQueue, Songs])
class QueueDao extends DatabaseAccessor<AppDatabase> {
  Future<List<SongData>> getAll();                       // 按 position 排序
  Future<void> replaceAll(List<PlayQueueCompanion> items);
  Future<void> insert(PlayQueueCompanion item);
  Future<void> remove(String songId, String source);
  Future<void> clear();
}
```

#### SettingsDao

```dart
@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase> {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
}
```

#### CacheDao

```dart
@DriftAccessor(tables: [CacheEntries])
class CacheDao extends DatabaseAccessor<AppDatabase> {
  Future<CacheEntryData?> getEntry(String songId, String source);
  Future<void> upsert(CacheEntriesCompanion entry);
  Future<void> updateLastAccessed(String filePath, int timestamp);
  Future<void> delete(String filePath);
  Future<List<CacheEntryData>> getOldestEntries(int limit);   // LRU 淘汰用
  Future<int> totalSizeKb();
}
```

### 3.3 Repository 与 DAO 关系

```
PlaylistRepository  ──→  PlaylistsDao
                    ──→  SongsDao (upsert song 时调用)

FavoriteRepository  ──→  FavoritesDao
                    ──→  SongsDao

HistoryRepository   ──→  HistoryDao

PlayerRepository    ──→  QueueDao
                    ──→  SongsDao
                    ──→  MusicApiClient (获取播放 URL)

CacheRepository     ──→  CacheDao
                    ──→  FileSystem (读写音频文件)

SettingsRepository  ──→  SettingsDao

LyricRepository     ──→  MusicApiClient (获取歌词)
                    ──→  FileSystem (歌词文件缓存)

SearchRepository    ──→  MusicApiClient
                    ──→  SongsDao (缓存搜索结果)
                    ──→  SettingsDao (读取搜索历史)
```

**原则：** 一个 Repository 最多依赖多个 DAO，但 DAO 之间不互相调用。跨表联查通过 Drift 的 JOIN 在 DAO 层实现。

---

## 四、功能模块落地方案

### 4.1 搜索模块

#### 状态设计（SearchNotifier）

```dart
@freezed
class SearchState with _$SearchState {
  const factory SearchState({
    @Default('') String keyword,
    @Default([]) List<Song> results,
    @Default([]) List<String> searchHistory,   // 最多 20 条
    @Default(1) int currentPage,
    @Default(false) bool isLoading,
    @Default(false) bool hasMore,
    String? errorMessage,
  }) = _SearchState;
}

class SearchNotifier extends AsyncNotifier<SearchState> {
  Future<void> search(String keyword);          // 触发搜索，重置 page=1
  Future<void> loadMore();                      // page++，追加结果
  Future<void> removeHistoryItem(String word);
  Future<void> clearHistory();
}
```

#### Repository 设计

```dart
class SearchRepository {
  Future<List<Song>> search(String source, String keyword, int count, int page);
  Future<List<String>> getSearchHistory();
  Future<void> addToHistory(String keyword);
  Future<void> removeFromHistory(String keyword);
  Future<void> clearHistory();
}
```

#### UI 组件拆分

```
HomeScreen
├── SearchBar（TextField，防抖 500ms）
├── [isEmpty] HistorySectionView
│   ├── SearchHistoryChips（可删除标签）
│   └── RecentPlayList（最近10首，来自 HistoryNotifier）
└── [hasResults] SearchResultList
    ├── SongListItem（封面 + 歌名 + 歌手 + 操作菜单）
    └── LoadMoreButton
```

#### 数据流

```
用户输入 → SearchBar(防抖500ms) → SearchNotifier.search()
  → SearchRepository.search(source, keyword, count, page)
    → RateLimiter.check() → 超限则抛 RateLimitException
    → MusicApiClient.searchSongs()
    → SongsDao.upsertSongs()（缓存搜索结果到本地）
  → state.results 更新 → UI 重建
```

#### 边界情况与错误处理

| 场景 | 处理方式 |
|------|---------|
| 5 分钟内请求 ≥ 45 次 | `RateLimiter` 抛出 `RateLimitException`，Notifier catch 后设置 `errorMessage`，UI 显示 Toast |
| 网络超时（已在拦截器重试1次后仍失败） | 设置 `errorMessage`，结果列表保留上次内容 |
| 关键词为空 | `SearchNotifier` 直接 return，不发 API 请求 |
| 搜索历史超 20 条 | `addToHistory` 时先删最旧的，再插入 |
| 离线模式开启 | `SearchRepository` 检查 `SettingsRepository.isOfflineMode()`，若为 true 直接抛 `OfflineModeException`，UI 提示"已开启离线模式" |

---

### 4.2 播放器模块

#### 状态设计（PlayerNotifier）

```dart
@freezed
class PlayerState with _$PlayerState {
  const factory PlayerState({
    Song? currentSong,
    @Default(PlayMode.sequence) PlayMode playMode,
    @Default(false) bool isPlaying,
    @Default(Duration.zero) Duration position,
    @Default(Duration.zero) Duration duration,
    @Default([]) List<Song> queue,
    @Default(0) int currentIndex,
    @Default(false) bool isBuffering,
  }) = _PlayerState;
}

class PlayerNotifier extends AsyncNotifier<PlayerState> {
  Future<void> play(Song song, {List<Song>? queue});
  Future<void> pause();
  Future<void> resume();
  Future<void> seekTo(Duration position);
  Future<void> next();
  Future<void> previous();
  void cyclePlayMode();   // sequence→shuffle→repeat_all→repeat_one→sequence
  Future<void> addToQueue(Song song);
  Future<void> insertNext(Song song);
  Future<void> removeFromQueue(int index);
  Future<void> reorderQueue(int oldIndex, int newIndex);
  Future<void> clearQueue();
}
```

#### Repository 设计

```dart
class PlayerRepository {
  // 获取播放 URL（先查缓存，再请求 API）
  Future<String> getPlayUrl(String songId, String source, AudioQuality quality);
  // 持久化队列
  Future<void> saveQueue(List<Song> queue, int currentIndex);
  Future<({List<Song> queue, int index})> loadQueue();
}
```

#### `just_audio` 封装（JustAudioPlayer）

```dart
class JustAudioPlayer {
  final AudioPlayer _player;

  // 统一封装 setUrl / setFilePath
  Future<void> setSource(String urlOrPath);
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<PlayerState> get playerStateStream;
}
```

#### 数据流

```
play(song) 调用
  → CacheRepository.getLocalPath(songId, source)
      命中 → JustAudioPlayer.setSource(localPath)
      未命中 → PlayerRepository.getPlayUrl()
               → MusicApiClient.getSongUrl()
               → JustAudioPlayer.setSource(url)
               → CacheRepository.cacheAudioAsync(url, songId) // 异步，不阻塞播放
  → JustAudioPlayer.play()
  → HistoryRepository.upsertPlay(songId, source)
  → QueueDao.replaceAll(currentQueue)  // 持久化队列
  → state 更新 → UI 重建
```

#### Shuffle 实现

`PlayerNotifier` 内部维护一个 `List<int> _shuffleOrder`，在进入 shuffle 模式时用 `Random` 生成打乱的索引序列，全部播完后重新洗牌。`previous/next` 按 `_shuffleOrder` 取对应 queue 索引。

#### 边界情况与错误处理

| 场景 | 处理方式 |
|------|---------|
| URL API 返回空 URL | 设置 `errorMessage`，跳过当前歌曲自动播下一首 |
| 音频文件下载中途中断 | 缓存文件不入库，下次播放重新获取 URL |
| 队列为空时调用 next/previous | 静默 return |
| App 从后台恢复 | `just_audio` 自动维护播放状态；队列从 `QueueDao` 恢复 |
| 离线模式下缓存未命中 | 跳过该歌曲，Toast "该歌曲未缓存" |

---

### 4.3 播放队列模块

#### 状态设计

队列状态直接复用 `PlayerState.queue` 和 `PlayerState.currentIndex`，无独立 Notifier。队列操作通过 `PlayerNotifier` 暴露的方法触发。

#### UI 组件拆分

```
PlayQueueDrawer（右侧抽屉或 BottomSheet）
├── Header（"当前队列" + 清空按钮）
├── ReorderableListView
│   └── QueueItemTile
│       ├── DragHandle（⠿）
│       ├── CoverImage（44dp）
│       ├── SongInfo（歌名 + 歌手）
│       └── DeleteButton（×）
└── 当前播放行：amber 左边框高亮
```

#### 持久化策略

- 队列变更（add/remove/reorder/clear）后，`PlayerNotifier` 立即调用 `QueueDao.replaceAll()` 异步写入，不等待写入结果再更新 UI 状态（optimistic update）。
- App 启动时，`PlayerNotifier` 在 `build()` 阶段调用 `PlayerRepository.loadQueue()` 恢复上次状态。

---

### 4.4 歌单模块

#### 状态设计（PlaylistNotifier）

```dart
@freezed
class PlaylistState with _$PlaylistState {
  const factory PlaylistState({
    @Default([]) List<Playlist> playlists,
    @Default(false) bool isLoading,
    String? errorMessage,
  }) = _PlaylistState;
}

// 歌单详情使用独立 family Provider
final playlistDetailProvider = StreamProvider.family<List<Song>, int>(
  (ref, playlistId) => ref.watch(playlistRepositoryProvider).watchSongs(playlistId),
);

class PlaylistNotifier extends AsyncNotifier<PlaylistState> {
  Future<void> createPlaylist(String name);
  Future<void> deletePlaylist(int id);
  Future<void> renamePlaylist(int id, String newName);
  Future<void> addSong(int playlistId, Song song);
  Future<void> removeSong(int playlistId, String songId, String source);
  Future<void> reorderSong(int playlistId, int oldIndex, int newIndex);
}
```

#### UI 组件拆分

```
PlaylistScreen
├── AppBar（"我的歌单" + 创建按钮）
└── PlaylistList
    └── PlaylistCard（封面 + 名称 + 歌曲数）

PlaylistDetailScreen
├── HeroHeader（封面 + 歌单名）
├── ActionRow（播放全部 / 随机播放）
├── ReorderableListView（可拖拽）
│   └── SongListItem（拖拽手柄 + 封面 + 信息 + 操作菜单）
└── BatchActionBar（批量选择时显示）
```

#### 边界情况与错误处理

| 场景 | 处理方式 |
|------|---------|
| 删除歌单 | Alert Dialog 二次确认，确认后 CASCADE 自动删除 `playlist_songs` 关联 |
| 歌单名称为空 | 客户端校验，不调用 Repository |
| 歌单名称重复 | 允许重复（无唯一约束），由用户自行区分 |
| 批量操作：加入队列 | 调用 `PlayerNotifier.addToQueue()` 遍历所选歌曲 |

---

### 4.5 收藏模块

#### 状态设计（FavoriteNotifier）

```dart
class FavoriteNotifier extends AsyncNotifier<List<Song>> {
  Future<void> toggle(Song song);             // 收藏/取消收藏
  Future<bool> isFavorite(String id, String source);
  Future<void> batchAddToPlaylist(List<Song> songs, int playlistId);
  Future<void> batchAddToQueue(List<Song> songs);
}
```

**收藏状态响应式**：`FavoriteNotifier` 通过 `FavoritesDao.watchAll()` 返回 `Stream`，所有显示 Heart 图标的页面（搜索结果、歌单详情、历史页）均订阅 `isFavorite()` 的结果，实现跨页面即时同步。

#### 数据流

```
用户点击 Heart
  → FavoriteNotifier.toggle(song)
    → FavoritesDao.isFavorite() → 已收藏则 remove，未收藏则 add + upsertSong
  → watchAll() Stream 触发 → 所有订阅方 UI 刷新
```

---

### 4.6 播放历史模块

#### 状态设计（HistoryNotifier）

```dart
@freezed
class HistoryGroup with _$HistoryGroup {
  const factory HistoryGroup({
    required String label,                    // "今天" / "昨天" / "更早"
    required List<HistoryEntry> entries,
  }) = _HistoryGroup;
}

class HistoryNotifier extends AsyncNotifier<List<HistoryGroup>> {
  Future<void> clearAll();
}
```

#### 分组逻辑

在 `HistoryRepository` 中，从 `HistoryDao.watchAll()` 拿到数据后进行分组：

```dart
List<HistoryGroup> _group(List<HistoryWithSong> raw) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));
  // 按 playedAt 分桶
}
```

---

### 4.7 歌词模块

#### LRC 解析器（LrcParser）

```dart
class LrcParser {
  // 解析单行 LRC 格式：[mm:ss.xx]歌词文本
  static List<LyricLine> parse(String lrc);

  // 将 lyric 和 tlyric 按时间轴合并
  // 相同时间点的行合并为一个 LyricLine（original + translation）
  static List<LyricLine> merge(String lyric, String tlyric);
}

class LyricLine {
  final Duration timestamp;
  final String original;
  final String? translation;
}
```

#### 状态设计（LyricNotifier）

```dart
class LyricNotifier extends FamilyAsyncNotifier<List<LyricLine>, (String, String)> {
  // key: (songId, source)
  // 先查本地缓存文件，命中直接解析；未命中则调 API，写文件后解析
}
```

#### UI 组件拆分

```
LyricScrollView（歌词滚动区域）
├── 监听 PlayerState.position
├── 根据 position 找当前激活行 index
├── ScrollController.animateTo() 将激活行滚至中心
└── LyricLineItem
    ├── original text（当前行：#E2A05B bold 18sp；其余：#795548 15sp）
    └── translation text（可选，当前行同色但 14sp）
    └── GestureDetector.onTap → PlayerNotifier.seekTo(line.timestamp)
```

#### 歌词文件缓存路径

```
<app_cache_dir>/lyrics/<source>_<lyric_id>.json
```

JSON 结构：`{"lyric": "...", "tlyric": "..."}` 原始字符串，解析在内存完成。

---

### 4.8 缓存模块

#### LRU 淘汰策略（CacheManager）

```dart
class CacheManager {
  final CacheRepository _repo;
  final SettingsRepository _settings;

  // 写入缓存前调用
  Future<void> ensureCapacity(int fileSizeKb) async {
    final maxKb = (await _settings.getCacheMaxMb()) * 1024;
    var totalKb = await _repo.totalSizeKb();
    while (totalKb + fileSizeKb > maxKb) {
      final oldest = await _repo.getOldestEntries(5);  // 批量取5条
      for (final entry in oldest) {
        await File(entry.filePath).delete();
        await _repo.delete(entry.filePath);
        totalKb -= entry.fileSizeKb;
        if (totalKb + fileSizeKb <= maxKb) break;
      }
    }
  }

  // 缓存音频文件
  Future<String> cacheAudio(String url, String songId, String source, int bitrateKbps) async {
    final path = _buildPath(songId, source, bitrateKbps);
    final bytes = await _download(url);
    await ensureCapacity(bytes.length ~/ 1024);
    await File(path).writeAsBytes(bytes);
    await _repo.upsert(filePath: path, songId: songId, source: source, fileSizeKb: bytes.length ~/ 1024);
    return path;
  }

  String _buildPath(String songId, String source, int br) =>
      '<cache_dir>/audio/${source}_${songId}_$br.mp3';
}
```

#### 缓存状态（CacheNotifier）

```dart
class CacheNotifier extends AsyncNotifier<CacheStatus> {
  Future<void> clearAll();          // 删除所有文件 + 清空 cache_entries 表
  Future<int> currentUsageMb();
}

class CacheStatus {
  final int usedMb;
  final int maxMb;
}
```

---

### 4.9 设置模块

#### 设置 Key 常量

```dart
class SettingsKey {
  static const defaultSource     = 'default_source';
  static const audioQuality      = 'audio_quality';
  static const cacheMaxMb        = 'cache_max_mb';
  static const playMode          = 'play_mode';
  static const lyricTranslation  = 'lyric_translation';
  static const searchHistory     = 'search_history';
  static const offlineMode       = 'offline_mode';
}
```

#### 状态设计（SettingsNotifier）

```dart
@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default(MusicSource.netease) MusicSource defaultSource,
    @Default(AudioQuality.q320)   AudioQuality audioQuality,
    @Default(512)                 int cacheMaxMb,
    @Default(PlayMode.sequence)   PlayMode playMode,
    @Default(true)                bool lyricTranslation,
    @Default(false)               bool offlineMode,
  }) = _AppSettings;
}
```

所有设置变更通过 `SettingsNotifier.update(field, value)` 方法写入 `SettingsDao`，并立即更新内存状态。其他 Notifier 通过 `ref.watch(settingsNotifierProvider)` 响应式处理（如 `PlayerNotifier` 读取 `audioQuality`）。

---

## 五、UI 落地方案（App 版）

### 5.1 底部导航结构

```dart
// mobile/app_shell.dart
class AppShell extends ConsumerWidget {
  // 使用 IndexedStack 保持各 Tab 页面状态不销毁
  final List<Widget> _pages = [
    HomeScreen(),
    PlaylistScreen(),
    FavoriteScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _pages),
          // 迷你播放器浮层（PlayerState.currentSong != null 时显示）
          Positioned(bottom: kBottomNavHeight, left: 0, right: 0,
            child: MiniPlayer()),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(),
    );
  }
}
```

### 5.2 各页面组件树

#### 全屏播放器（FullPlayerScreen）

```
FullPlayerScreen（上滑手势进入，PageRoute 或 showModalBottomSheet）
├── TopBar
│   ├── BackButton（关闭）
│   └── QueueButton（打开 PlayQueueDrawer）
├── AlbumCoverRotator（RotationTransition + CircleAvatar）
├── SongInfoRow
│   ├── SongTitle（22sp bold）
│   ├── ArtistName（15sp）
│   └── FavoriteButton（Heart）
├── ProgressBar（SliderTheme 定制，橙色）
├── PlaybackControls
│   ├── PlayModeButton（循环图标）
│   ├── PreviousButton
│   ├── PlayPauseButton（64dp 圆形，amber 背景）
│   ├── NextButton
│   └── RepeatButton
└── LyricPreviewArea（下 35% 屏幕，GestureDetector 上滑→FullLyricScreen）
    └── LyricScrollView（仅显示 3 行）
```

#### 迷你播放器（MiniPlayer）

```
MiniPlayer（GestureDetector 上滑→全屏播放器）
├── AlbumCover（48dp 圆形，旋转动画）
├── SongInfo（歌名 + 歌手，Expanded）
├── PlayPauseIconButton（amber）
└── NextIconButton
```

### 5.3 全屏播放器与迷你播放器交互流程

```
迷你播放器可见（PlayerState.currentSong != null）
  ├── 点击迷你播放器主体 → Navigator.push(FullPlayerScreen)
  │     FullPlayerScreen.pop() → 返回主界面，迷你播放器仍显示
  └── 迷你播放器上滑手势 → Hero 动画过渡到 FullPlayerScreen

FullPlayerScreen 内
  ├── 歌词区上滑 → Navigator.push(FullLyricScreen)
  └── 队列按钮 → showModalBottomSheet(PlayQueueDrawer)
```

### 5.4 暖色调主题体系

#### 颜色

```dart
class WarmColors {
  static const primary         = Color(0xFFE2A05B);
  static const primaryLight    = Color(0xFFEEC08A);
  static const primaryDark     = Color(0xFFC67D35);
  static const background      = Color(0xFFFFFDF7);
  static const surface         = Color(0xFFFFF8E7);
  static const textPrimary     = Color(0xFF3E2723);
  static const textSecondary   = Color(0xFF795548);
  static const accent          = Color(0xFFE57373);   // 收藏/删除
  static const divider         = Color(0xFFF0E6D3);
  static const playerGradStart = Color(0xFF5D3A1A);   // 全屏播放器背景渐变起始
}
```

#### ThemeData 配置

```dart
ThemeData warmTheme() => ThemeData(
  colorScheme: ColorScheme.light(
    primary: WarmColors.primary,
    surface: WarmColors.surface,
    onSurface: WarmColors.textPrimary,
  ),
  scaffoldBackgroundColor: WarmColors.background,
  cardTheme: CardTheme(
    color: WarmColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 0,
    shadowColor: WarmColors.primary.withOpacity(0.12),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true, fillColor: WarmColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
  ),
  sliderTheme: SliderThemeData(
    activeTrackColor: WarmColors.primary,
    inactiveTrackColor: WarmColors.divider,
    thumbColor: WarmColors.primary,
  ),
);
```

#### 圆角规范

| 组件 | 圆角 |
|------|------|
| 列表卡片 | 16dp |
| 主要按钮 | 12dp |
| 搜索框 / 标签 Chip | 20dp（胶囊） |
| 专辑封面（列表）| 12dp |
| 专辑封面（全屏）| 24dp |

---

## 六、TV 端落地方案

### 6.1 两栏布局结构

```dart
// tv/tv_app_shell.dart
class TvAppShell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        TvNavSidebar(width: 220),   // 左侧导航
        Expanded(child: _content),  // 右侧内容区
      ],
    );
  }
}
```

**侧边栏折叠**：导航项获得焦点时展开（220dp），失去焦点区域后收起（72dp，只显示图标）。使用 `AnimatedContainer` 实现宽度过渡。

**底部常驻播放器条**：TV 版不使用迷你播放器浮层，改为屏幕底部固定 80dp 高度的播放控制条（包含封面 + 歌名 + 进度 + 控制按钮），在所有内容页面均可见。

### 6.2 焦点管理策略

#### FocusTraversalGroup 分区

```
TvAppShell
├── FocusTraversalGroup(policy: OrderedTraversalPolicy)
│   └── TvNavSidebar            ← 区域 1：上下方向键在侧边栏内循环
├── FocusTraversalGroup(policy: ReadingOrderTraversalPolicy)
│   └── ContentArea             ← 区域 2：方向键在内容区内导航
└── FocusTraversalGroup(policy: OrderedTraversalPolicy)
    └── PlayerControlBar        ← 区域 3：左右方向键在控制按钮间移动
```

**区域间切换**：
- 在内容区按左→焦点转移到侧边栏
- 在侧边栏按右→焦点转移到内容区
- 在内容区按下（到最底部）→焦点转移到播放控制条

#### TV 焦点视觉规范

```dart
class TvFocusCard extends StatefulWidget {
  Widget build() => Focus(
    onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
    child: AnimatedContainer(
      decoration: BoxDecoration(
        border: _focused ? Border.all(color: WarmColors.primary, width: 3) : null,
        boxShadow: _focused ? [BoxShadow(color: WarmColors.primary.withOpacity(0.4), blurRadius: 16)] : null,
        borderRadius: BorderRadius.circular(16),
      ),
      transform: Matrix4.identity()..scale(_focused ? 1.08 : 1.0),
      child: child,
    ),
  );
}
```

### 6.3 TV 专属页面拆分

#### TvHomeScreen

```
TvHomeScreen
├── SectionTitle（"最近播放" 28sp bold）
└── HorizontalScrollRow（焦点横向滚动）
    └── TvFocusCard × N
        ├── AlbumCover（160×160dp）
        └── SongInfo（歌名 18sp + 歌手 14sp）
```

#### TvFullPlayerScreen

```
TvFullPlayerScreen（全屏）
├── Left（45%）: AlbumCover（400dp，amber glow shadow，缓慢旋转动画）
└── Right（55%）
    ├── SongTitle（36sp bold）
    ├── ArtistName（24sp）
    ├── ProgressBar（带时间标签，8dp 高）
    └── PlayerControls（5个按钮，默认焦点在播放/暂停）
        playMode | previous | play/pause(96dp) | next | repeat
```

**控制条自动隐藏**：3秒无遥控器操作后，`AnimatedOpacity` 将控制区淡化至 20% opacity；任何按键输入后立即恢复至 100% 并重置计时器。

#### TvFullLyricScreen

```
TvFullLyricScreen（全屏）
├── Left（40%）: AlbumCover（静止，不旋转，作为背景锚点）
└── Right（60%）: LyricScrollView（双语，字号 24sp 原文 / 18sp 译文）
```

### 6.4 遥控器交互规则落地

```dart
// RawKeyboardListener 或 HardwareKeyboard 处理媒体键
void _handleKeyEvent(KeyEvent event) {
  switch (event.logicalKey) {
    case LogicalKeyboardKey.mediaPlay:
    case LogicalKeyboardKey.mediaPause:
    case LogicalKeyboardKey.mediaPlayPause:
      ref.read(playerNotifierProvider.notifier).togglePlayPause();
    case LogicalKeyboardKey.mediaFastForward:
      ref.read(playerNotifierProvider.notifier).seekBy(const Duration(seconds: 10));
    case LogicalKeyboardKey.mediaRewind:
      ref.read(playerNotifierProvider.notifier).seekBy(const Duration(seconds: -10));
    case LogicalKeyboardKey.mediaTrackNext:
      ref.read(playerNotifierProvider.notifier).next();
    case LogicalKeyboardKey.mediaTrackPrevious:
      ref.read(playerNotifierProvider.notifier).previous();
  }
}
```

`HardwareKeyboard.instance.addHandler()` 在 `TvAppShell` 中全局注册，确保媒体键在任何页面均有效。

---

## 七、API 集成落地方案

### 7.1 Dio 配置

```dart
Dio buildDio() => Dio(BaseOptions(
  baseUrl: 'https://music-api.gdstudio.xyz',
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 15),
))
  ..interceptors.addAll([
    RateLimitInterceptor(),   // 必须第一个，避免浪费网络资源
    RetryInterceptor(maxRetries: 1),
    ErrorInterceptor(),
    if (kDebugMode) LogInterceptor(),
  ]);
```

### 7.2 限流拦截器（RateLimitInterceptor）

```dart
class RateLimitInterceptor extends Interceptor {
  static const _windowMs = 5 * 60 * 1000;  // 5 分钟
  static const _maxRequests = 45;           // 留 5 次余量（API 上限 50）

  final _timestamps = <int>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _timestamps.removeWhere((t) => now - t > _windowMs);

    if (_timestamps.length >= _maxRequests) {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        error: RateLimitException('请求频繁，请稍后再试'),
      ));
      return;
    }
    _timestamps.add(now);
    handler.next(options);
  }
}
```

### 7.3 重试拦截器（RetryInterceptor）

```dart
class RetryInterceptor extends Interceptor {
  final int maxRetries;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = err.requestOptions.extra['retryCount'] ?? 0;
    final isTimeout = err.type == DioExceptionType.connectionTimeout
        || err.type == DioExceptionType.receiveTimeout;

    if (isTimeout && retryCount < maxRetries) {
      err.requestOptions.extra['retryCount'] = retryCount + 1;
      final response = await dio.fetch(err.requestOptions);
      handler.resolve(response);
      return;
    }
    handler.next(err);
  }
}
```

### 7.4 错误转换拦截器（ErrorInterceptor）

```dart
// 统一转换为 AppError，Notifier 层只需处理 AppError
sealed class AppError {
  const factory AppError.network(String message)     = NetworkError;
  const factory AppError.rateLimit()                 = RateLimitError;
  const factory AppError.offline()                   = OfflineError;
  const factory AppError.notFound(String resource)   = NotFoundError;
  const factory AppError.unknown(Object cause)       = UnknownError;
}
```

### 7.5 MusicApiClient 方法

```dart
class MusicApiClient {
  final Dio _dio;

  // 搜索（支持普通搜索和专辑搜索）
  Future<List<SongDto>> searchSongs({
    required String source, required String name,
    int count = 20, int page = 1, bool albumMode = false,
  });

  // 获取播放 URL
  Future<SongUrlDto> getSongUrl({
    required String source, required String id, required int br,
  });

  // 获取封面图 URL（直接拼接 URL，不发请求；由 cached_network_image 加载）
  String getPicUrl(String source, String picId, {int size = 300});

  // 获取歌词
  Future<LyricDto> getLyric({required String source, required String id});
}
```

### 7.6 离线模式下的行为切换

所有涉及网络的 Repository 在执行前检查：

```dart
Future<void> _assertOnline() async {
  if (await _settings.isOfflineMode()) throw const AppError.offline();
}
```

| 操作 | 离线模式行为 |
|------|------------|
| 搜索 | 抛出 `OfflineError`，UI 显示"已开启离线模式，无法搜索" |
| 获取播放 URL | 检查缓存命中，未命中则跳过（不抛错，直接 next） |
| 获取封面图 | `cached_network_image` 已有磁盘缓存则显示，否则显示占位图 |
| 获取歌词 | 检查本地歌词缓存文件，有则读取，无则显示"歌词不可用" |

---

## 八、开发里程碑（可直接用于 Jira）

### Phase 1 — 核心播放基础（2 周）

**目标：** 能搜索歌曲并播放，有最基础的 UI 框架

| 编号 | 任务 | 可交付产物 |
|------|------|-----------|
| P1-01 | Flutter 项目初始化，配置 Android / iOS / TV targets | 可运行的空项目 |
| P1-02 | 引入 Riverpod / Drift / just_audio / Dio，配置依赖注入 | `pubspec.yaml` + Provider 骨架 |
| P1-03 | `AppDatabase` 建表（songs / settings / play_queue） | Drift schema v1 |
| P1-04 | `MusicApiClient` 封装（搜索 + URL API） | 单元测试通过 |
| P1-05 | `RateLimitInterceptor` + `RetryInterceptor` + `ErrorInterceptor` | 限流单元测试通过 |
| P1-06 | `SearchNotifier` + `SearchRepository` | 搜索结果可展示 |
| P1-07 | `HomeScreen`（搜索框 + 搜索结果列表 + 操作菜单） | 功能页面可用 |
| P1-08 | `JustAudioPlayer` 封装 + `PlayerNotifier` 核心状态 | 可点击播放 |
| P1-09 | `MiniPlayer` Widget + `FullPlayerScreen` 基础布局 | 播放器 UI 可见 |
| P1-10 | 播放队列（添加 / 删除 / 顺序 / 随机）+ `QueueDao` | 队列功能完整 |
| P1-11 | `AppShell`（底部导航 + IndexedStack + MiniPlayer 浮层） | App 壳子完整 |

### Phase 2 — 数据管理（1.5 周）

**目标：** 完整的歌单、收藏、历史功能；缓存与歌词

| 编号 | 任务 | 可交付产物 |
|------|------|-----------|
| P2-01 | 补全 Drift 表（playlists / playlist_songs / favorites / play_history / cache_entries） | Drift schema v2（migration） |
| P2-02 | 歌单 CRUD + `PlaylistRepository` + `PlaylistNotifier` | 歌单增删改查 |
| P2-03 | `PlaylistScreen` + `PlaylistDetailScreen`（含拖拽排序） | 歌单页面可用 |
| P2-04 | 收藏功能 + `FavoriteNotifier`（跨页面 Heart 同步） | 收藏即时响应 |
| P2-05 | `FavoriteScreen`（含批量操作） | 收藏页可用 |
| P2-06 | 播放历史（upsert 逻辑 + 日期分组） | 历史分组可显示 |
| P2-07 | `HistoryScreen` | 历史页可用 |
| P2-08 | 搜索历史（存储 + 展示 + 删除） | 搜索历史可用 |
| P2-09 | `LrcParser` + `LyricNotifier`（API 获取 + 文件缓存） | 歌词解析通过 |
| P2-10 | `LyricScrollView`（滚动高亮 + 双语 + 点击跳转） | 歌词显示完整 |
| P2-11 | `CacheManager`（LRU 淘汰）+ 音频缓存写入 | 缓存功能可用 |

### Phase 3 — 体验完善（1 周）

**目标：** 设置页、批量操作、全屏歌词、错误处理全覆盖

| 编号 | 任务 | 可交付产物 |
|------|------|-----------|
| P3-01 | `SettingsScreen`（音质 / 音乐源 / 缓存上限 / 离线模式 / 歌词翻译） | 设置页完整 |
| P3-02 | 离线模式完整联调（所有 Repository 的 offline 分支） | 离线模式通过 |
| P3-03 | `PlayQueueDrawer`（拖拽排序 + 删除 + 清空 + 下一首插队） | 队列抽屉完整 |
| P3-04 | `FullLyricScreen`（上滑手势 + 全屏滚动） | 全屏歌词可用 |
| P3-05 | 批量操作全量联调（歌单详情 + 收藏页） | 批量操作通过 |
| P3-06 | 全局 Toast / Snackbar 错误提示（限流、离线、网络错误） | 错误提示覆盖 |
| P3-07 | 专辑搜索模式（`albumMode=true`） | 专辑搜索可用 |
| P3-08 | 暖色调主题统一审查（颜色 / 间距 / 字号全页面对齐） | UI 视觉一致 |

### Phase 4 — TV 端适配（1.5 周）

**目标：** Android TV 完整可用

| 编号 | 任务 | 可交付产物 |
|------|------|-----------|
| P4-01 | `PlatformDetector` + TV/Mobile 入口分流（`main.dart`） | TV 入口可用 |
| P4-02 | `TvAppShell`（左右两栏 + `FocusTraversalGroup` 分区） | TV 布局框架 |
| P4-03 | `TvNavSidebar`（折叠/展开 + 焦点高亮） | 侧边栏完整 |
| P4-04 | `TvFocusCard`（焦点光晕 + scale 动画） | 通用 TV 卡片 |
| P4-05 | `TvHomeScreen`（历史卡片横向滚动） | TV 首页完整 |
| P4-06 | `TvFullPlayerScreen`（左右分栏布局 + 控制条 + 3s 自动隐藏） | TV 播放器完整 |
| P4-07 | `TvFullLyricScreen`（左图右词 + 24sp 字号） | TV 歌词页完整 |
| P4-08 | 媒体键全局注册（`HardwareKeyboard`） | 遥控器媒体键有效 |
| P4-09 | TV 字体 1.5x 缩放 + 所有交互元素 ≥ 48dp 审查 | TV 可用性审查通过 |
| P4-10 | TV 端 E2E 测试（遥控器导航路径覆盖核心流程） | TV 测试通过 |

---

## 九、风险点与解决方案

### 9.1 音频缓存文件写入与播放竞争

**风险：** 音频文件正在写入时 App 崩溃，导致损坏的缓存文件被下次读取使用。

**解决方案：**
1. 写入时使用临时文件名：`<path>.tmp`
2. 写入完成后原子 `rename` 到正式路径
3. `CacheRepository` 只在 rename 成功后写入 `cache_entries` 表
4. App 启动时扫描并删除所有 `.tmp` 残留文件

```dart
final tmpPath = '$path.tmp';
await File(tmpPath).writeAsBytes(bytes);
await File(tmpPath).rename(path);        // 原子操作
await _repo.upsert(...);
```

### 9.2 播放器状态多处订阅同步

**风险：** `PlayerNotifier` 状态更新后，MiniPlayer、FullPlayerScreen、LyricScrollView、PlayerControlBar（TV）等多处 Widget 同时 rebuild，可能导致 jank。

**解决方案：**
1. 使用 `select()` 精细订阅，各 Widget 只订阅自己需要的字段
   ```dart
   // LyricScrollView 只订阅 position
   final position = ref.watch(playerNotifierProvider.select((s) => s.position));
   ```
2. 歌词滚动通过 `AnimationController` 驱动，不直接触发 Widget rebuild
3. `Position` 更新通过 `just_audio` 的 Stream 驱动，不进入 Riverpod 状态树（减少 rebuild 频率）

### 9.3 TV 焦点越界（焦点跑到屏幕外元素）

**风险：** 遥控器方向键在边缘元素时焦点跳到意外位置，或陷入焦点死角。

**解决方案：**
1. 每个 `FocusTraversalGroup` 设置 `descendantsAreFocusable: true` / `descendantsAreTraversable: true` 明确边界
2. 使用 `FocusScope.of(context).nextFocus()` 手动控制边界跳转
3. 全屏播放器使用 `FocusTrap`（拦截 Back 键以外的跳出行为），退出需显式按 Back 键
4. 在 UI 测试阶段建立"焦点路径测试用例"：覆盖所有可能的方向键序列

```dart
// 防止焦点从列表末尾跳出到父级其他区域
FocusTraversalGroup(
  policy: const OrderedTraversalPolicy(),
  child: ListView.builder(/* items */),
)
```

### 9.4 API 限流（5分钟 50次）

**风险：** 用户搜索时防抖不够精准，或批量操作（如歌单全量播放触发多次 URL 请求）超出限制。

**解决方案：**

| 场景 | 策略 |
|------|------|
| 搜索防抖 | 输入后 500ms 才发请求，快速连续输入只发最后一次 |
| 批量获取 URL | 队列播放时**按需获取**：只有当前播放歌曲 + 下一首才预取 URL，不提前批量拉取 |
| 专辑搜索 | 与普通搜索共享同一个 `RateLimiter` 计数器 |
| 触发限流后 | Notifier 设置 `errorMessage`，UI 显示 Toast，下次搜索在计数器刷新后自动恢复（无需用户手动操作）|
| 计数器持久化 | `RateLimiter` 的时间戳列表存在内存中（不持久化），App 重启后重置，符合 API 的滑动窗口逻辑|

### 9.5 Drift 数据库迁移

**风险：** Phase 2 新增表时，已安装的 Phase 1 构建需要进行 Schema 迁移，若处理不当会导致 crash。

**解决方案：**
- 每次新增表，`AppDatabase` 的 `schemaVersion` +1
- 在 `MigrationStrategy.onUpgrade` 中用 `m.createTable(newTable)` 处理每个版本升级
- 生产环境从 Phase 1 直接升级到 Phase 2 的迁移逻辑必须在 Phase 2 开发时编写并通过测试

```dart
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (m, from, to) async {
    if (from < 2) {
      await m.createTable(playlists);
      await m.createTable(playlistSongs);
      await m.createTable(favorites);
      await m.createTable(playHistory);
      await m.createTable(cacheEntries);
    }
  },
);
```
