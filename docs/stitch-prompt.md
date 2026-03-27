# Stitch Prompt — 私人音乐播放器 (Warm Music Player)

## App Overview

A private, local-first music player app with a warm-tone visual identity. All user data (playlists, favorites, history, cache) is stored locally on-device. The app has two variants: **Mobile (Android/iOS)** and **TV (Android TV)**.

---

## Design System

**Color Palette:**
- Primary: `#E2A05B` (Amber Orange)
- Primary Light: `#EEC08A`
- Primary Dark: `#C67D35`
- Background: `#FFFDF7` (Cream White)
- Surface: `#FFF8E7` (Warm Sand)
- Text Primary: `#3E2723` (Deep Brown)
- Text Secondary: `#795548` (Warm Brown)
- Accent / Favorite: `#E57373` (Soft Red)
- Divider: `#F0E6D3`
- Focus Border (TV): `#E2A05B` with glow

**Typography:**
- Font: System default sans-serif (SF Pro on iOS, Roboto on Android)
- Title: 22sp Bold, color `#3E2723`
- Body: 16sp Regular, color `#3E2723`
- Caption: 13sp Regular, color `#795548`
- TV Scale: all sizes × 1.5

**Corner Radius:**
- Cards: 16dp
- Buttons: 12dp
- Chips/Tags: 20dp (pill shape)
- Cover images: 12dp

**Elevation / Shadow:**
- Cards: `box-shadow: 0 4px 16px rgba(226,160,91,0.12)`
- Mini Player: `box-shadow: 0 -4px 20px rgba(0,0,0,0.08)`
- Bottom nav: `box-shadow: 0 -1px 0 #F0E6D3`

---

## Mobile App Screens

### Screen 1 — Home / Discovery (発現页)

**Layout:** Single column, full-screen scroll

**Components (top to bottom):**
1. **Status bar** — warm background
2. **Search Bar** — full-width rounded pill `#FFF8E7`, magnifier icon `#795548`, placeholder: "搜索歌手、曲目、专辑…"
3. **Section: 搜索历史** — horizontal row of amber pill-shaped chips with `×` dismiss icon each, "清空" text button at far right
4. **Section: 最近播放** — section title + vertical list of 10 songs:
   - Cover image (48×48dp, rounded 12dp)
   - Song title (16sp bold `#3E2723`)
   - Artist · Album (13sp `#795548`)
   - Three-dot overflow menu icon (`#795548`)
5. **[Search Active State overlay]** — replaces history/recent sections:
   - Song list items with cover + title + artist + album
   - Each row right side: vertical three-dot menu
   - Menu options: 播放 / 加入队列末尾 / 下一首播放 / 加入歌单 / 收藏
   - "加载更多" button at bottom

6. **Mini Player** (sticky, floating above bottom nav):
   - Surface: `#FFF8E7`, height 64dp, full-width, rounded-top 20dp, subtle shadow
   - Left: circular rotating cover image (48dp)
   - Center: song title (15sp bold) + artist (12sp)
   - Right: amber play/pause icon + skip-next icon

7. **Bottom Navigation Bar** — 4 tabs:
   - 发现 (active: filled icon + amber label)
   - 歌单 (icon + label)
   - 收藏 (icon + label)
   - 设置 (icon + label)

---

### Screen 2 — Full Player (全屏播放器)

**Layout:** Full-screen immersive, top-to-bottom gradient from `#5D3A1A` (dark caramel) → `#FFF8E7` (cream)

**Components:**
1. **Top Bar:**
   - `←` back button (white/light)
   - Center: "正在播放" label (subtle, 14sp)
   - Right: queue icon button

2. **Album Cover** — centered large circle (240dp), rotating slowly, shadow glow `rgba(226,160,91,0.4)`, rounded square 24dp

3. **Song Info Row:**
   - Song title (22sp bold, off-white `#FFF8E7`)
   - Artist name (15sp `#EEC08A`)
   - Heart (favorite) icon at far right (filled red if favorited)

4. **Progress Bar:**
   - Track: `rgba(255,255,255,0.2)`, height 4dp
   - Played portion: `#E2A05B`, animated
   - Thumb: amber circle 14dp with glow
   - Time labels: elapsed left, remaining right, 12sp `#EEC08A`

5. **Playback Controls Row:**
   - Shuffle/mode icon (left)
   - Previous track icon
   - Play/Pause button — large circle 64dp, amber fill `#E2A05B`, white icon
   - Next track icon
   - Repeat icon (right)

6. **Lyrics Preview Area** (bottom half, ~35% height):
   - Semi-transparent dark overlay
   - 3 visible lyric lines, center-aligned
   - Active line: `#E2A05B` bold, larger (18sp)
   - Adjacent lines: `rgba(255,255,255,0.5)` smaller (14sp)
   - "上滑查看全部歌词 ↑" hint text at bottom

---

### Screen 3 — Full Lyrics (全屏歌词)

**Layout:** Dark warm background `#2B1810`, full-screen scroll

**Components:**
1. **Top Bar:** `←` back, song title + artist centered
2. **Lyrics Scroll Area:**
   - Each lyric entry: 2 lines (original + Chinese translation)
   - Active line: `#E2A05B` bold 18sp, centered, slightly larger
   - Past lines: `#795548` 15sp
   - Future lines: `#795548` 15sp, slightly dimmer
   - Smooth auto-scroll, active line centered vertically
   - Tap on any line → seek to that timestamp

---

### Screen 4 — My Playlists (我的歌单)

**Layout:** Single column card list

**Components:**
1. **Top Bar:** "我的歌单" title + `+` create button (amber)
2. **Playlist Cards** (vertical scroll):
   - Cover image 72×72dp rounded 12dp (first song's cover or default gradient placeholder)
   - Playlist name (17sp bold)
   - Song count (13sp `#795548`)
   - `›` chevron right
3. **Empty state:** centered music-note illustration + "还没有歌单，点击 + 创建" text

---

### Screen 5 — Playlist Detail (歌单详情)

**Layout:** Full-screen with sticky header

**Components:**
1. **Hero Header:**
   - Large cover mosaic (4 covers in 2×2 grid) or single image, 200dp height
   - Gradient overlay bottom: `#3E2723` → transparent
   - Playlist name over image (white 22sp bold, tappable to rename)

2. **Action Row:** 
   - "▶ 播放全部" filled amber button
   - "⇌ 随机播放" outlined amber button

3. **Song List** (vertical scroll):
   - Left: drag handle icon `⠿` (`#D4B896`)
   - Cover image 48dp rounded
   - Song title + artist
   - Three-dot menu (remove from playlist, play next, add to queue)
   - Long-press: enters batch selection mode (checkboxes appear, amber)

4. **Batch Action Bar** (bottom, shown in selection mode):
   - "加入播放队列" | "加入其他歌单" | "移除"

---

### Screen 6 — Favorites (收藏)

**Layout:** Identical structure to Playlist Detail but no drag handles, sorted by date added

**Components:**
1. **Top Bar:** "我的收藏" + batch-select button
2. **Song List:**
   - Cover 48dp + title + artist
   - Filled heart icon (`#E57373`) on right
3. **Batch Action Bar:** same as playlist detail

---

### Screen 7 — Play History (播放历史)

**Layout:** Grouped list with sticky date headers

**Components:**
1. **Top Bar:** "播放历史" + "清空" text button (red `#E57373`)
2. **Date Section Headers:** "今天" / "昨天" / "更早" — 13sp bold amber `#E2A05B`, background `#FFF8E7`
3. **Song Items:**
   - Cover 48dp + title + artist
   - Right: play count badge "×3" in small pill `#FFF8E7` border `#E2A05B` text `#E2A05B`

---

### Screen 8 — Play Queue (播放队列 — Right Drawer)

**Layout:** Modal bottom sheet or right-side drawer, 80% screen width

**Components:**
1. **Header:** "当前队列" (18sp bold) + "清空" button
2. **Currently Playing indicator:** amber left border accent on active row
3. **Queue Items:**
   - Drag handle `⠿`
   - Cover 44dp + title + artist
   - `×` delete button right
4. **"下一首播放" insert zone:** thin dashed amber line between current and next items as visual hint

---

### Screen 9 — Settings (设置)

**Layout:** Grouped list with card sections

**Components (grouped cards):**

**Card Group 1 — 播放**
- 默认音乐源: `[netease ▾]` dropdown pill
- 音质偏好: `[320kbps ▾]` dropdown pill

**Card Group 2 — 缓存**
- 缓存上限: slider `128MB ←●→ 4096MB`, current value label `512 MB`
- 当前缓存占用: progress bar (amber fill) + "247 MB / 512 MB" label
- 清空缓存: right-aligned `[清空]` outlined red button

**Card Group 3 — 歌词**
- 歌词翻译: toggle switch (amber when on)

**Card Group 4 — 网络**
- 离线模式: toggle switch + description "开启后仅播放已缓存内容"

---

## TV Screens (1920×1080)

### TV Screen 1 — TV Home

**Layout:** Left sidebar (200dp) + right content area (full height)

**Left Sidebar:**
- App logo / name at top
- Navigation items (vertical list):
  - 发现 (active: amber background pill, bold)
  - 我的歌单
  - 收藏
  - 设置
- Each item: 56dp height, 24sp icon + label, focus state: `#E2A05B` border 2dp glow

**Right Content Area:**
- Section title "最近播放" (28sp bold `#3E2723`)
- Horizontal scroll row of history cards:
  - Card: 180×200dp, rounded 16dp, subtle warm shadow
  - Cover image 160×160dp top
  - Song title (18sp bold) + artist (14sp) below
  - Focus state: scale 1.08, amber glow border 3dp
- Empty area below for future content

**Persistent Bottom Bar (mini player):**
- Full width, 80dp height, `#FFF8E7` background, subtle top shadow
- Left: rotating circular cover 56dp
- Center: title (22sp) + artist (16sp) + progress bar
- Right: prev / play-pause (72dp amber circle) / next buttons — focused button has amber glow

---

### TV Screen 2 — TV Full Player

**Layout:** Full-screen, left 45% / right 55% split

**Left Side:**
- Centered large album cover (400×400dp), rounded 24dp, subtle amber glow shadow
- Slowly rotating (visual indicator only)

**Right Side (top to bottom):**
- Song title (36sp bold, `#3E2723`)
- Artist name (24sp `#795548`)
- Spacer
- Progress bar (full width of right panel, 8dp height)
  - Elapsed / total time labels 18sp
- Spacer
- Playback Controls Row (centered):
  - Mode icon (48dp touch target)
  - Previous (64dp)
  - Play/Pause (96dp amber filled circle, default focused)
  - Next (64dp)
  - Repeat icon (48dp)
  - Each button: focused state → amber 3dp border + scale 1.1 + glow

**Focus indicator:** visible 2dp amber rounded border on all interactive elements
**Auto-hide:** control row fades to 20% opacity after 3s inactivity, reappears on any input

---

## Navigation Flow

```
Home (Tab 1)
  └─► Full Player  ──► Full Lyrics (swipe up / button)
                   └─► Play Queue Drawer (button)

My Playlists (Tab 2)
  └─► Playlist Detail

Favorites (Tab 3)

Settings (Tab 4)

[Any screen with song] ──► Add to Playlist Dialog
                       └─► Play Queue
```

---

## Notes for Stitch

- All screens share the same warm color palette and component library
- Mobile screens target 390×844dp (iPhone 14 size reference)
- TV screens are 1920×1080
- Interactive elements on TV must be ≥ 48dp with visible focus rings
- Prefer flat, modern design — avoid skeuomorphic shadows except subtle card elevation
- Amber (`#E2A05B`) is the single accent color; use sparingly for CTAs, active states, and highlights only
