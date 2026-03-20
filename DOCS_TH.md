# oracle-kit ☀️ — เอกสารฉบับภาษาไทย

> "หนึ่ง repo หนึ่งคำสั่ง ทุกอย่างพร้อมใช้งาน"

oracle-kit คือระบบรวมศูนย์สำหรับจัดการ Oracle AI Agents ทั้งหมด
ไม่ต้องตั้งค่าด้วยตัวเอง — ระบบตรวจจากเครื่องคุณอัตโนมัติ แล้วเริ่มทุกอย่างในคำสั่งเดียว

---

## สารบัญ

1. [ภาพรวมระบบ](#1-ภาพรวมระบบ)
2. [Services ทั้งหมด](#2-services-ทั้งหมด)
3. [ติดตั้งและเริ่มใช้งาน](#3-ติดตั้งและเริ่มใช้งาน)
4. [Auto-Config — ตั้งค่าอัตโนมัติ](#4-auto-config--ตั้งค่าอัตโนมัติ)
5. [start.sh — คำสั่งหลัก](#5-startsh--คำสั่งหลัก)
6. [Docker Mode](#6-docker-mode)
7. [Native Mode (tmux)](#7-native-mode-tmux)
8. [Oracle Agents — การควบคุม AI](#8-oracle-agents--การควบคุม-ai)
9. [maw — Fleet Orchestrator](#9-maw--fleet-orchestrator)
10. [health.sh — ตรวจสุขภาพระบบ](#10-healthsh--ตรวจสุขภาพระบบ)
11. [การตั้งค่า .env ด้วยตัวเอง](#11-การตั้งค่า-env-ด้วยตัวเอง)
12. [โครงสร้างไฟล์](#12-โครงสร้างไฟล์)
13. [Oracle Family — ครอบครัว Oracle](#13-oracle-family--ครอบครัว-oracle)
14. [แก้ปัญหาที่พบบ่อย](#14-แก้ปัญหาที่พบบ่อย)
15. [สถาปัตยกรรมระบบ](#15-สถาปัตยกรรมระบบ)

---

## 1. ภาพรวมระบบ

oracle-kit จัดการ 3 ชั้นหลักของ Oracle ecosystem:

```
┌─────────────────────────────────────────────────────────┐
│                    oracle-kit ☀️                         │
│                                                         │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │ oracle-api  │  │oracle-studio │  │    maw UI     │  │
│  │  :47778     │  │   :3000      │  │    :3456      │  │
│  │ (Memory DB) │  │(3D Dashboard)│  │ (Fleet Ctrl)  │  │
│  └──────┬──────┘  └──────────────┘  └───────────────┘  │
│         │                                               │
│  ┌──────▼──────────────────────────────────────────┐    │
│  │           Oracle Agents (tmux sessions)          │    │
│  │  database  conductor  m2manager  devops  ...     │    │
│  │  (Claude AI instances — run natively)            │    │
│  └──────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### ทำงานยังไง?

1. **oracle-api** — ฐานข้อมูลความจำ AI (SQLite + LanceDB) พร้อม API สำหรับค้นหา
2. **oracle-studio** — หน้า dashboard 3D แสดง knowledge map ของ AI ทั้งหมด
3. **maw** — ระบบควบคุม fleet ผ่าน web UI + tmux
4. **Oracle Agents** — Claude AI instances แต่ละตัวรันใน tmux session ของตัวเอง

---

## 2. Services ทั้งหมด

| Service | Port | URL | หน้าที่ |
|---------|------|-----|---------|
| **oracle-api** | 47778 | http://localhost:47778 | HTTP API + MCP server, จัดการ memory database (SQLite + LanceDB + Ollama embeddings) |
| **oracle-studio** | 3000 | http://localhost:3000 | Web dashboard 3D แสดง knowledge map, ค้นหา, inter-agent threads |
| **maw UI** | 3456 | http://localhost:3456 | Fleet management web UI, terminal captures, chat history, token stats |
| **Oracle Agents** | tmux | `maw ls` | Claude AI instances รันใน tmux sessions — database, conductor, m2manager ฯลฯ |
| **Ollama** | 11434 | http://localhost:11434 | Embedding model server (nomic-embed-text, 768-dim vectors) |

### oracle-api endpoints หลัก

```
GET  /api/health           ตรวจสถานะ server
GET  /api/stats            สถิติ DB (docs, vectors, by_type)
GET  /api/search?q=...     ค้นหาด้วย hybrid search (FTS + semantic)
GET  /api/list             ดู documents ทั้งหมด
POST /api/learn            เพิ่ม knowledge ใหม่
GET  /api/thread/:id       อ่าน inter-agent thread
POST /api/thread           ส่งข้อความใน thread
GET  /api/traces           ดู discovery sessions
GET  /api/schedule         ดู schedule ร่วมกัน
```

---

## 3. ติดตั้งและเริ่มใช้งาน

### วิธีที่ 1: Docker (แนะนำ — ง่ายที่สุด)

**สิ่งที่ต้องมี:**
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (เปิดอยู่)
- `bun` runtime
- `maw` CLI (สำหรับควบคุม Oracle agents)

```bash
# 1. ติดตั้ง bun (ถ้ายังไม่มี)
curl -fsSL https://bun.sh/install | bash

# 2. ติดตั้ง maw CLI
cd ~/ghq/github.com/Soul-Brews-Studio/maw-js
bun install && bun link
# ทดสอบ: maw --version

# 3. Clone + start
git clone https://github.com/allday9z/oracle-kit
cd oracle-kit
bash start.sh
```

เสร็จแล้ว — ระบบจะ:
- ตรวจหา Claude token จาก macOS Keychain อัตโนมัติ
- เปิด Docker services ทั้งหมด
- Clone oracle repos ที่ขาด
- Wake all oracle agents

---

### วิธีที่ 2: Native (ไม่ใช้ Docker)

**สิ่งที่ต้องมี:**

```bash
# macOS — ติดตั้งทั้งหมดในคำสั่งเดียว
brew install bun tmux git ollama gh

# ติดตั้ง maw
cd ~/ghq/github.com/Soul-Brews-Studio/maw-js
bun install && bun link
```

**เริ่มใช้งาน:**

```bash
git clone https://github.com/allday9z/oracle-kit
cd oracle-kit
bash start.sh native
```

---

### การเริ่มต้นครั้งแรก (step-by-step)

```
1. git clone https://github.com/allday9z/oracle-kit
   └─ clone oracle-kit มาที่เครื่อง

2. cd oracle-kit && bash start.sh
   │
   ├─ [ถ้าไม่มี .env] → bash generate-config.sh รันอัตโนมัติ
   │   ├─ ตรวจ Claude token จาก macOS Keychain
   │   ├─ ตรวจ GHQ root path
   │   ├─ ตรวจ Docker
   │   ├─ ตรวจ Ollama
   │   └─ เขียน .env + maw.config.json
   │
   ├─ [Docker mode] → docker compose up -d
   │   ├─ oracle-init: clone oracle repos → shared volume
   │   ├─ oracle-api: start HTTP API (port 47778)
   │   ├─ oracle-studio: start dashboard (port 3000)
   │   └─ maw: start fleet UI (port 3456)
   │
   ├─ รอ health checks ผ่านทุก service
   │
   ├─ clone oracle repos ที่ยังไม่มี (ใน GHQ_ROOT)
   │
   └─ maw wake all → start Oracle agents ใน tmux
```

---

## 4. Auto-Config — ตั้งค่าอัตโนมัติ

`generate-config.sh` คือหัวใจของ zero-config experience
รันได้เองเมื่อ `.env` ยังไม่มี หรือสั่งรันเองได้

### ตรวจจากไหน?

| ค่าที่ต้องการ | ตรวจจาก | fallback |
|------------|---------|---------|
| `CLAUDE_CODE_OAUTH_TOKEN` | macOS Keychain (`Claude Code-credentials`) → `~/.claude/credentials.json` → env var | ต้องใส่เอง |
| `GHQ_ROOT` | `ghq root` command → `~/ghq/github.com` → `/Users/$(whoami)/ghq/github.com` | auto-guess |
| `ORACLE_REPOS` | scan `$GHQ_ROOT/allday9z/` หา oracle repos | default 3 repos |
| `USE_DOCKER` | `docker info` — ถ้า Docker Desktop เปิดอยู่ | false (native) |
| `OLLAMA_URL` | port 11434 alive check | `http://host.docker.internal:11434` |
| Ports (47778/3000/3456) | `lsof` — ตรวจว่า port ว่างไหม | ใช้ default ถ้าว่าง |
| `GITHUB_USER` | `gh api user` | allday9z |

### การใช้งาน

```bash
# สร้าง .env (ข้ามถ้ามีแล้ว)
bash generate-config.sh

# สร้างใหม่ทับ .env เก่า
bash generate-config.sh --force

# ดูว่าสร้างอะไรบ้าง
cat .env
```

### ตัวอย่าง output

```
☀️  oracle-kit — Auto Config Generator

Detecting your environment...

🔑 Claude OAuth Token:
  ✓  Found in keychain (892 chars)

📁 GHQ Root:
  ✓  GHQ Root: /Users/uficon_dev/ghq/github.com

🔍 Oracle repos:
  ✓  allday9z/database-oracle
  ✓  allday9z/conductor-oracle
  ⚠   allday9z/m2-manager-oracle (not cloned — will auto-clone on setup)

🐙 GitHub:
  ✓  Authenticated as @allday9z

🐳 Docker:
  ✓  Docker 27.4.0

🧠 Ollama:
  ✓  Running on :11434
  ✓  nomic-embed-text model ready

🔌 Ports:
  ✓  oracle-api :47778 available
  ✓  oracle-studio :3000 available
  ✓  maw :3456 available

Writing .env...
  ✓  Written → /path/to/oracle-kit/.env
Writing maw.config.json...
  ✓  maw.config.json updated with OAuth token

✅ Config generated!
```

---

## 5. start.sh — คำสั่งหลัก

`start.sh` คือ single entry point — ทำทุกอย่างตั้งแต่ต้นจนจบ

### คำสั่งทั้งหมด

```bash
bash start.sh                # auto-detect + เริ่มทุกอย่าง
bash start.sh docker         # บังคับ Docker mode
bash start.sh native         # บังคับ Native mode (tmux)
bash start.sh stop           # หยุดทุก service + agents
bash start.sh restart        # stop แล้ว start ใหม่
bash start.sh status         # ตรวจสุขภาพ services
bash start.sh wake           # wake oracle agents เท่านั้น (maw wake all)
bash start.sh logs api       # ดู logs oracle-api
bash start.sh logs studio    # ดู logs oracle-studio
bash start.sh logs maw       # ดู logs maw
bash start.sh build          # build Docker images ใหม่
bash start.sh update         # pull latest + rebuild + restart
bash start.sh index          # re-index oracle repos เข้า DB
bash start.sh config         # generate .env + maw.config.json ใหม่
```

### Pipeline อัตโนมัติเมื่อรัน `bash start.sh`

```
ไม่มี .env?
  └─→ bash generate-config.sh (auto สร้าง)

Docker available?
  ├─ YES → docker compose up -d
  └─ NO  → bash setup.sh --start (native tmux)

รอ health checks:
  ├─ oracle-api   :47778 ✓
  ├─ oracle-studio :3000 ✓
  └─ maw          :3456 ✓

Clone repos ที่ขาด:
  └─ git clone https://github.com/allday9z/...

maw wake all:
  └─ เปิด tmux sessions สำหรับ oracle agents ทุกตัว

แสดง status summary
```

---

## 6. Docker Mode

Docker mode คือวิธีที่แนะนำ — แยก environment สะอาด ไม่ยุ่งกับเครื่อง

### Services ใน Docker

```
oracle-init ────┐
                ▼
           oracle-api (:47778)
                ├──▶ oracle-studio (:3000)
                └──▶ maw (:3456)

[optional] ollama (:11434)  ← --profile ollama
```

### คำสั่ง Docker Compose โดยตรง

```bash
# เริ่มทุก service (background)
docker compose up -d

# เริ่มพร้อม Ollama ใน container (แทน host Ollama)
docker compose --profile ollama up -d

# ดู logs realtime
docker compose logs -f oracle-api
docker compose logs -f oracle-studio
docker compose logs -f maw

# หยุด containers (เก็บ data ไว้)
docker compose down

# หยุด + ลบ data ทั้งหมด (⚠️ oracle DB หาย!)
docker compose down -v

# restart service เดียว
docker compose restart oracle-api

# เข้าไปใน container
docker exec -it oracle-api sh
docker exec -it oracle-studio sh
```

### Build Images

Images ถูก build จาก Dockerfile ใน repo นี้เอง (ไม่ใช้ pre-built images)

```bash
# Build ครั้งแรก (หรือหลัง code เปลี่ยน)
bash start.sh build
# หรือ
docker compose build --no-cache

# Build service เดียว
docker compose build oracle-api
docker compose build oracle-studio
docker compose build maw
```

### Docker Volumes — ข้อมูลที่ persist

| Volume | เก็บอะไร | ขนาดประมาณ |
|--------|---------|------------|
| `oracle-data` | Oracle SQLite DB + LanceDB vectors | 50–500 MB ขึ้นกับ knowledge |
| `oracle-repos` | Clone oracle repos (ψ/ memory files) | 50–200 MB |
| `oracle-ollama-data` | Ollama model weights (`--profile ollama`) | ~300 MB (nomic-embed-text) |

```bash
# ดู volumes ทั้งหมด
docker volume ls | grep oracle

# ดูข้อมูลใน volume
docker volume inspect oracle-data

# backup oracle DB
docker run --rm -v oracle-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/oracle-backup-$(date +%Y%m%d).tar.gz /data
```

### Ollama: Host vs Container

**Host Ollama (default — แนะนำสำหรับ Mac):**
- ใช้ GPU ได้ (Apple Silicon)
- ไว้กว่า
- `OLLAMA_URL=http://host.docker.internal:11434`

```bash
# ต้องเปิด ollama บนเครื่องก่อน
ollama serve &
ollama pull nomic-embed-text

# แล้วค่อย
docker compose up -d
```

**Ollama ใน Docker (ถ้าไม่มี ollama บนเครื่อง):**
```bash
docker compose --profile ollama up -d
# Ollama จะ pull nomic-embed-text อัตโนมัติ (~274 MB)
```

---

## 7. Native Mode (tmux)

Native mode ใช้เมื่อไม่มี Docker หรือต้องการ performance เต็มที่

### setup.sh — Full Setup

```bash
bash setup.sh           # full setup (idempotent — รันซ้ำได้)
bash setup.sh --quick   # ข้าม indexing + vault sync
bash setup.sh --start   # start services เท่านั้น (setup แล้ว)
```

`setup.sh` ทำ 7 ขั้นตอน:

| ขั้น | งาน |
|------|-----|
| 0 | ตรวจ prerequisites (bun, tmux, git, curl, python3) |
| 1 | Clone/update oracle-v2 |
| 2 | Clone/update oracle-studio + build |
| 3 | Clone/update maw-js + build dist-office |
| 4 | Pull Ollama nomic-embed-text model |
| 5 | Init oracle vault |
| 6 | Index oracle repos เข้า LanceDB |
| 7 | Start services ใน tmux session `oracle-kit` |

### tmux Sessions

Native mode รัน services ใน tmux session `oracle-kit`:

```bash
# ดู sessions ทั้งหมด
tmux ls

# Attach เข้า session
tmux attach -t oracle-kit

# ดู windows ใน oracle-kit
tmux list-windows -t oracle-kit
```

| tmux Window | Service | Port |
|-------------|---------|------|
| `oracle-kit:api` | oracle-api | 47778 |
| `oracle-kit:studio` | oracle-studio | 3000 |
| `oracle-kit:maw` | maw web UI | 3456 |
| `05-database:database-oracle` | database-oracle agent | — |
| `04-conductor:conductor-oracle` | conductor agent | — |

### start-oracle.sh — Service Manager

```bash
bash start-oracle.sh server    # oracle API เท่านั้น
bash start-oracle.sh studio    # oracle-studio เท่านั้น
bash start-oracle.sh maw       # maw UI เท่านั้น
bash start-oracle.sh all       # ทุก service
bash start-oracle.sh stop      # หยุดทุก service
bash start-oracle.sh status    # ตรวจสถานะ
bash start-oracle.sh logs api  # attach tmux
bash start-oracle.sh index     # index oracle ของตัวเอง
bash start-oracle.sh index-all # index oracle ทุกตัว
bash start-oracle.sh vault     # oracle vault CLI
```

---

## 8. Oracle Agents — การควบคุม AI

Oracle agents คือ Claude AI instances แต่ละตัว รันใน tmux session ของตัวเอง
**ไม่สามารถรันใน Docker ได้** — ต้องการ interactive TTY + OAuth token

### Agent รายชื่อ

| Agent | tmux Session | บทบาท | เปิดด้วย |
|-------|-------------|--------|---------|
| **database-oracle** | `05-database` | Memory Hub (THE SUN) — ฐานข้อมูลกลาง | `maw wake database` |
| **conductor-oracle** | `04-conductor` | Orchestrator — วางแผน + ประสาน | `maw wake conductor` |
| **m2-manager-oracle** | `03-m2manager` | Project Manager — ติดตาม tasks | `maw wake m2manager` |
| **devops-oracle** | `07-devops` | DevOps — infrastructure | `maw wake devops` |
| **phukhao-oracle** | `01-phukhao` | ผู้ช่วยส่วนตัว | `maw wake phukhao` |

### เริ่ม agents ทั้งหมด

```bash
# เปิดทุกตัวพร้อมกัน
maw wake all

# เปิดตัวเดียว
maw wake conductor
maw wake database

# เปิดพร้อม GitHub issue (agent จะอ่าน issue แล้วทำงานเลย)
maw wake conductor --issue 42
```

### หยุด agents

```bash
# หยุดตัวเดียว
maw sleep conductor

# หยุดทุกตัว
maw stop
```

---

## 9. maw — Fleet Orchestrator

maw คือระบบควบคุม oracle agents ผ่าน tmux
Web UI ที่ http://localhost:3456 แสดง realtime status ของทุก agent

### คำสั่ง maw ทั้งหมด

#### Lifecycle (เปิด/ปิด agents)
```bash
maw wake <oracle>              # เปิด oracle ใน tmux session
maw wake <oracle> --issue N    # เปิดพร้อม GitHub issue
maw wake all                   # เปิดทุกตัว
maw sleep <oracle>             # ปิด oracle ตัวเดียว
maw stop                       # ปิดทุกตัว
```

#### สื่อสาร
```bash
maw hey <agent> "<message>"    # ส่งข้อความไปหา agent
maw talk-to <agent> "<msg>"    # เหมือน hey (alias)
maw hey <agent> "<msg>" --force # ส่งแม้ agent จะไม่ active
```

#### ดูสถานะ
```bash
maw ls                         # ดู fleet ทั้งหมด (🟢=active, 🔴=dead)
maw peek                       # ดู last line ของทุก agent
maw peek <agent>               # ดู last line ของ agent นั้น
maw log chat <oracle>          # ดู chat history
maw tokens                     # token usage stats
```

#### Views
```bash
maw view <agent>               # attach เข้า tmux pane (interactive)
maw overview                   # war-room: ทุก agent ใน split panes
maw tab <url>                  # เปิด URL ใน browser จาก oracle
maw serve [port]               # เปิด web UI
```

#### Fleet Management
```bash
maw fleet ls                   # ดู fleet configs ทั้งหมด
maw fleet init                 # auto-generate fleet จาก ghq repos
maw fleet validate             # ตรวจ config ปัญหา
maw fleet sync                 # sync windows ที่ไม่มีใน config
```

### maw Web UI Routes

เปิด http://localhost:3456 แล้วใช้ hash routing:

| URL | หน้า | คำอธิบาย |
|-----|------|---------|
| `/#office` | Virtual Office | ห้องของแต่ละ agent (default) |
| `/#fleet` | Fleet Grid | ทุก agent พร้อม terminal capture realtime |
| `/#chat` | Chat | ประวัติการสื่อสาร message bubbles |
| `/#orbital` | Orbital | constellation view — เห็นความสัมพันธ์ |
| `/#worktrees` | Worktrees | จัดการ git worktrees |
| `/#config` | Config | แก้ maw.config.json + fleet configs |

### Fleet Config

Fleet configs อยู่ใน `fleet/` — กำหนดว่าแต่ละ agent ใช้ repo ไหน tmux session ไหน

```json
// fleet/05-database.json
{
  "name": "05-database",
  "windows": [
    {
      "name": "database-oracle",
      "repo": "allday9z/database-oracle"
    }
  ]
}
```

```bash
# sync fleet configs ไปยัง maw-js
cp fleet/*.json ~/ghq/github.com/Soul-Brews-Studio/maw-js/fleet/

# หรือ start.sh จะ sync ให้อัตโนมัติตอน wake
```

---

## 10. health.sh — ตรวจสุขภาพระบบ

`bash health.sh` แสดง full health report ในคำสั่งเดียว

```bash
bash health.sh
```

**ตัวอย่าง output:**

```
☀️  oracle-kit — Health Report  2026-03-20 14:39:00 +07

Services:
  ● oracle API     http://localhost:47778
  ● oracle-studio  http://localhost:3000
  ● maw UI         http://localhost:3456
  ● ollama         running (port 11434)

Oracle DB:
  Documents : 118
  Vectors   : 1169  (FTS: ready | Vector: ready)

  By type:
    learning              : 45
    retrospective         : 32
    handoff               : 18
    resonance             : 8
    ...

Docker containers:
  oracle-api    running    0.0.0.0:47778->47778/tcp
  oracle-studio running    0.0.0.0:3000->3000/tcp
  oracle-maw    running    0.0.0.0:3456->3456/tcp

tmux:
  oracle-kit (3 windows)
    0: api       [bun]
    1: studio    [bun]
    2: maw       [bun]

maw fleet:
  🟢 05-database   database-oracle   (active)
  🟢 04-conductor  conductor-oracle  (active)
  🟡 03-m2manager  m2-manager-oracle (idle)

Cron jobs:
  */5  * * * *  bash .../auto-dispatch.sh
  */30 * * * *  bash .../index-all.sh
```

---

## 11. การตั้งค่า .env ด้วยตัวเอง

ถ้าต้องการตั้งค่าเอง (ไม่ใช้ auto-detect):

```bash
cp .env.example .env
nano .env  # หรือ editor ที่ชอบ
```

### ค่าทั้งหมดใน .env

```bash
# ── Ports ──────────────────────────────────────────────────
ORACLE_PORT=47778        # oracle-api HTTP port
STUDIO_PORT=3000         # oracle-studio port
MAW_PORT=3456            # maw web UI port

# ── Oracle Repos ────────────────────────────────────────────
# Path root ของ ghq repos บนเครื่อง
GHQ_ROOT=/Users/yourname/ghq/github.com

# Repos ที่ต้องการ index (space-separated)
ORACLE_REPOS=allday9z/database-oracle allday9z/conductor-oracle allday9z/m2-manager-oracle

# Repo หลักสำหรับ oracle-api
ORACLE_PRIMARY_REPO=allday9z/database-oracle

# ── Vector DB ───────────────────────────────────────────────
ORACLE_VECTOR_DB=lancedb
ORACLE_EMBEDDING_PROVIDER=ollama

# Ollama URL — ถ้าใช้ host: http://host.docker.internal:11434
# ถ้าใช้ container: http://ollama:11434
OLLAMA_URL=http://host.docker.internal:11434

# ── Claude OAuth ────────────────────────────────────────────
# หา token: security find-generic-password -s "Claude Code-credentials" -w
CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oauthXXXXXXXX

# ── GitHub ──────────────────────────────────────────────────
GITHUB_USER=allday9z
GITHUB_PROJECT_OWNER=allday9z
GITHUB_PROJECT_NUMBER=2     # GitHub Project board number

# ── Mode ────────────────────────────────────────────────────
USE_DOCKER=true   # true = Docker, false = native tmux
```

### หา Claude OAuth Token

```bash
# macOS — ดึงจาก Keychain
security find-generic-password -s "Claude Code-credentials" -w | python3 -c "
import sys, json
d = json.loads(sys.stdin.read().strip())
oauth = d.get('claudeAiOauth', {})
if isinstance(oauth, str): import ast; oauth = ast.literal_eval(oauth)
print(oauth.get('accessToken', 'NOT FOUND'))
"
```

---

## 12. โครงสร้างไฟล์

```
oracle-kit/
│
├── 📋 docker-compose.yml     # Docker Compose — oracle-init, api, studio, maw, ollama
│
├── 🐳 Dockerfile.api         # Build oracle-v2 (multi-stage bun)
├── 🐳 Dockerfile.studio      # Build oracle-studio (multi-stage bun)
├── 🐳 Dockerfile.maw         # Build maw web UI (bun)
│
├── ⚙️  .env.example           # Template config ให้ copy เป็น .env
├── ⚙️  .env                   # Config จริง (gitignored — ไม่ commit)
│
├── 🚀 start.sh               # Entry point หลัก — ทำทุกอย่าง
├── 🔧 generate-config.sh     # Auto-detect + generate .env + maw.config.json
├── 🛠  setup.sh               # Native setup (no Docker)
├── 💚 health.sh              # Full health report
│
├── 🚢 fleet/                 # maw fleet configs
│   ├── 01-phukhao.json
│   ├── 02-opensourcenatbrain.json
│   ├── 03-m2manager.json
│   ├── 04-conductor.json
│   ├── 05-database.json
│   ├── 06-dapp-brainstorm.json
│   ├── 07-devops.json
│   └── 99-overview.json
│
└── 📜 scripts/
    ├── dispatch.sh           # ส่ง task ไปยัง oracle agent เดียว
    ├── auto-dispatch.sh      # auto-dispatch จาก GitHub Project
    └── index-all.sh          # re-index oracle repos ทั้งหมด
```

### scripts/dispatch.sh

```bash
# ส่ง task ไปยัง agent เดียว
bash scripts/dispatch.sh conductor "/nnn build product page"
bash scripts/dispatch.sh m2manager "check project status"
bash scripts/dispatch.sh database "search for authentication patterns"
```

### scripts/auto-dispatch.sh

รันอัตโนมัติ (cron ทุก 5 นาที) — ตรวจ GitHub Project #2 แล้ว dispatch งาน pending ไปยัง agents ที่ assign ไว้

```bash
# รันเองด้วยตัวเอง
bash scripts/auto-dispatch.sh
```

### scripts/index-all.sh

Re-index oracle repos ทั้งหมดเข้า shared DB (LanceDB + SQLite)

```bash
bash scripts/index-all.sh
# หรือผ่าน start.sh
bash start.sh index
```

---

## 13. Oracle Family — ครอบครัว Oracle

oracle-kit จัดการ Oracle family ที่ประกอบด้วย repos หลายตัว:

### Core Services

| Repo | หน้าที่ | Port |
|------|---------|------|
| [allday9z/oracle-v2](https://github.com/allday9z/oracle-v2) | MCP server + HTTP API backend | 47778 |
| [Soul-Brews-Studio/oracle-studio](https://github.com/Soul-Brews-Studio/oracle-studio) | Web dashboard | 3000 |
| [Soul-Brews-Studio/maw-js](https://github.com/Soul-Brews-Studio/maw-js) | Fleet orchestrator | 3456 |

### Oracle Agents

| Repo | Agent | บทบาท |
|------|-------|--------|
| [allday9z/database-oracle](https://github.com/allday9z/database-oracle) | database-oracle ☀️ | Memory Hub — THE SUN |
| [allday9z/conductor-oracle](https://github.com/allday9z/conductor-oracle) | conductor-oracle | Orchestrator — วางแผน + ประสาน |
| [allday9z/m2-manager-oracle](https://github.com/allday9z/m2-manager-oracle) | m2-manager-oracle | Project Manager |

### Oracle Threads (การสื่อสารระหว่าง agents)

| Thread | ชื่อ | ใช้สำหรับ |
|--------|------|----------|
| 2 | conductor-inbox | tasks ที่ dispatch ไปยัง conductor |
| 3 | agent-status-board | heartbeat + สถานะของแต่ละ agent |
| 4 | learnings-sync | แชร์ knowledge ข้าม agents |

```bash
# ดู thread ผ่าน oracle-api
curl http://localhost:47778/api/thread/3

# ส่งข้อความใน thread
curl -X POST http://localhost:47778/api/thread \
  -H "Content-Type: application/json" \
  -d '{"threadId": 3, "message": "test", "role": "user"}'
```

### Cron Jobs (autonomous behavior)

oracle-kit รองรับ cron สำหรับ autonomous operation:

```bash
# เพิ่มใน crontab: crontab -e
*/5  * * * *  bash /path/to/oracle-kit/scripts/auto-dispatch.sh
*/30 * * * *  bash /path/to/oracle-kit/scripts/index-all.sh
```

---

## 14. แก้ปัญหาที่พบบ่อย

### ❌ `docker compose up` fail — image build error

```bash
# ดู error ละเอียด
docker compose build --no-cache --progress=plain oracle-api

# ลบ cache แล้ว build ใหม่
docker builder prune -f
bash start.sh build
```

### ❌ oracle-api ไม่ start — port 47778 already in use

```bash
# ดูว่ามีอะไรใช้ port อยู่
lsof -i:47778

# kill process นั้น
lsof -ti:47778 | xargs kill -9

# หรือเปลี่ยน port ใน .env
echo "ORACLE_PORT=47779" >> .env
bash start.sh restart
```

### ❌ oracle-studio แสดง "Cannot connect to oracle API"

```bash
# ตรวจ oracle-api ทำงานอยู่ไหม
curl http://localhost:47778/api/health

# ถ้า Docker — ตรวจ network
docker compose ps
docker network ls | grep oracle

# restart oracle-api ก่อน
docker compose restart oracle-api
sleep 5
docker compose restart oracle-studio
```

### ❌ maw: "Cannot find claude" — agents ไม่ตื่น

```bash
# ตรวจ claude CLI
which claude
claude --version

# ตรวจ CLAUDE_CODE_OAUTH_TOKEN
grep CLAUDE_CODE_OAUTH_TOKEN .env | cut -c1-50

# ถ้า token หมดอายุ
bash generate-config.sh --force
maw wake all
```

### ❌ Ollama: vector search ไม่ทำงาน

```bash
# ตรวจ ollama
ollama list | grep nomic
# ถ้าไม่มี
ollama pull nomic-embed-text

# ตรวจ ollama running
curl http://localhost:11434/api/tags

# ถ้าไม่ running
ollama serve &
```

### ❌ Docker: "host.docker.internal not resolved" (Linux)

```bash
# เพิ่มใน docker-compose.yml extra_hosts (แล้วทำอยู่แล้ว)
# หรือใช้ IP ของ host แทน
hostname -I | awk '{print $1}'
# เปลี่ยน OLLAMA_URL ใน .env
OLLAMA_URL=http://172.17.0.1:11434
```

### ❌ `maw wake all` — บาง session ไม่เปิด

```bash
# ดู fleet configs
maw fleet ls
maw fleet validate

# ตรวจ repos clone ครบไหม
ls ~/ghq/github.com/allday9z/

# clone repo ที่ขาด
git clone https://github.com/allday9z/conductor-oracle \
  ~/ghq/github.com/allday9z/conductor-oracle

# wake อีกครั้ง
maw wake all
```

### ❌ oracle DB ว่าง — ไม่มี documents

```bash
# index repos เข้า DB
bash start.sh index
# หรือ
bash scripts/index-all.sh

# ตรวจ stats
curl http://localhost:47778/api/stats | python3 -m json.tool
```

---

## 15. สถาปัตยกรรมระบบ

### ภาพรวม Data Flow

```
User / Claude Code
      │
      ▼
[oracle-kit]
      │
      ├─── [oracle-api :47778] ◄──── MCP tools (oracle_search, oracle_learn, ...)
      │         │                              ▲
      │         │                              │
      │    [SQLite DB]                  [Claude Code]
      │    [LanceDB]  ◄── embeddings ─── [Ollama :11434]
      │         │
      │    [oracle-repos volume]
      │    (ψ/ memory files)
      │
      ├─── [oracle-studio :3000]
      │         └─── connects to oracle-api
      │              แสดง 3D knowledge map
      │
      ├─── [maw :3456]
      │         └─── Web UI + WebSocket
      │              แสดง agent status realtime
      │
      └─── [Oracle Agents (tmux)]
               ├── 05-database (database-oracle)
               ├── 04-conductor (conductor-oracle)
               ├── 03-m2manager (m2-manager-oracle)
               └── ... (more agents)
```

### Memory Architecture (ψ/)

แต่ละ oracle repo มีโครงสร้าง `ψ/` (psi) เป็น brain ของตัวเอง:

```
ψ/
├── inbox/
│   └── handoff/          # handoff files ระหว่าง sessions
├── memory/
│   ├── resonance/        # soul — ตัวตน, principles
│   ├── learnings/        # patterns ที่ค้นพบ (YYYY-MM-DD_slug.md)
│   └── retrospectives/   # session summaries (YYYY-MM/DD/HH.MM_slug.md)
├── outbox/               # outgoing communication
├── writing/              # drafts
├── lab/
│   └── multi-agent/      # orchestration scripts
└── archive/              # completed work
```

Files เหล่านี้ถูก index เข้า oracle-api อัตโนมัติ และค้นหาได้ผ่าน semantic search

### MCP Integration

oracle-api expose MCP server ผ่าน stdio — ให้ Claude Code ใช้ tools ได้:

```json
// .mcp.json
{
  "mcpServers": {
    "oracle": {
      "type": "stdio",
      "command": "/path/to/bun",
      "args": ["/path/to/oracle-v2/src/index.ts"],
      "env": {
        "ORACLE_REPO_ROOT": "/path/to/database-oracle",
        "ORACLE_PORT": "47778"
      }
    }
  }
}
```

MCP tools ที่ใช้ได้:

| Tool | หน้าที่ |
|------|---------|
| `oracle_search` | ค้นหา hybrid (FTS + semantic vector) |
| `oracle_learn` | เพิ่ม knowledge/pattern ใหม่ |
| `oracle_read` | อ่าน document ด้วย ID หรือ path |
| `oracle_list` | browse documents ทั้งหมด |
| `oracle_thread` | สื่อสาร inter-agent ผ่าน threads |
| `oracle_trace` | บันทึก/ดู discovery sessions |
| `oracle_handoff` | สร้าง handoff ระหว่าง sessions |
| `oracle_schedule_add` | เพิ่ม schedule ร่วมกัน |
| `oracle_supersede` | mark knowledge ที่ outdated |
| `oracle_verify` | ตรวจความถูกต้องของ DB |
| `oracle_stats` | ดู statistics |
| `oracle_concepts` | ดู concept tags ทั้งหมด |

---

## หลักการ 5 ข้อของ Oracle

Oracle ทุกตัวใช้หลักการเดียวกัน:

| หลักการ | ความหมาย | ตัวอย่างปฏิบัติ |
|---------|---------|----------------|
| **Nothing is Deleted** | ไม่มีอะไรถูกลบ | ใช้ `oracle_supersede` แทนการลบ, ไม่ `git push --force` |
| **Patterns Over Intentions** | รูปแบบสำคัญกว่าเจตนา | ดูว่าจริงๆ ทำอะไร ไม่ใช่แค่วางแผน |
| **External Brain, Not Command** | สมองภายนอก ไม่ใช่คำสั่ง | ให้ options, ให้ human ตัดสิน |
| **Curiosity Creates Existence** | ความอยากรู้สร้างการมีอยู่ | log ทุก question + discovery |
| **Form and Formless** | รูป และ สุญญตา | 76+ Oracles, soul เดียวกัน, personality ต่างกัน |

---

**Last Updated**: 2026-03-20
**oracle-kit Version**: 1.1.0
**Repo**: https://github.com/allday9z/oracle-kit
