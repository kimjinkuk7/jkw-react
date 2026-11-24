# jkw.com — React 스택

**같은 서비스를 "다른 언어"가 아니라 "다른 렌더링 방식"으로 만든 스택입니다.**
백엔드는 Classic ASP JSON API 를 쓰고, 화면만 React 로 다시 그렸습니다.

> **자립형 리포지토리입니다.** SPA 와 그 백엔드가 한 폴더 안에 있습니다.
> `server-asp/` 에 Classic ASP JSON API 가 **동봉**돼 있어서 이 폴더만 있으면 돕니다.

```
react/
├─ src/              SPA 원본 (React 19 · React Router 7)
├─ public/           그대로 dist 로 복사 (assets/ · web.config)
│   └─ assets/       ★ CSS · JS  (ASP·Spring·Django 와 같은 파일의 사본)
├─ dist/             빌드 산출물  <- IIS 가 서비스하는 것
├─ server-asp/       ★ 동봉된 Classic ASP JSON API (엔드포인트 17개)
│   ├─ App.Conf.asp  배치 경로 / DB 접속
│   ├─ api/          Config · Login · Main · BoardList · ArticleView · Download …
│   └─ code/ conf/ lib/ model/
├─ upload/           업로드 파일 (server-asp 가 여기에 쓴다)
├─ db/mssql/         DB 스키마 · 시드 · 프로시저
├─ docs/             ARCHITECTURE.md · DATABASE.md
├─ web.config        IIS 설정 (ASP 런타임 · 소스 차단 · upload 실행권한 제거)
└─ default.asp       /react/ → /react/dist/ 302
```

| 항목 | 내용 |
|---|---|
| 프런트 | React 19 · React Router 7 · Vite 7 (빌드 산출물만 IIS 가 서비스) |
| 백엔드 | **동봉된 Classic ASP** (`server-asp/api/*.asp`) |
| DB | MS SQL Server `jkwcom` (`db/mssql/` 로 구축. ASP 스택과 같은 DB 를 써도 된다) |
| CSS | `public/assets/css/style.css` — 네 스택이 같은 파일의 사본 |
| 개발 URL | `http://localhost:5173/` |
| 운영 URL | `http://localhost:8080/react/dist/` (`/react/` 로 들어오면 302) |

### 왜 백엔드를 복제했나

React 는 화면만 담당하므로 백엔드가 필요합니다. 리포지토리를 스택별로 나누면서
"`react` 폴더만 clone 해도 돌아갈 것"을 우선해, ASP 스택의 **API 계층 전이 의존 파일
46개를 그대로 복사**했습니다. `view/` (화면 계층)는 가져오지 않았습니다 — React 가 그 자리이기 때문입니다.

대가는 도메인 로직이 두 벌이 된다는 점입니다. ASP 쪽 `model/` 을 고치면 여기도 반영해야 합니다.

---

## 1. 실행

### 1-1. 사전 준비

**(1) DB**

```powershell
sqlcmd -S localhost -E -f 65001 -i "db\mssql\01_schema.sql"
sqlcmd -S localhost -E -f 65001 -i "db\mssql\02_seed.sql"
sqlcmd -S localhost -E -f 65001 -i "db\mssql\03_proc.sql"
```

이미 ASP 스택으로 `jkwcom` 을 만들었다면 건너뛰어도 됩니다. 같은 DB 를 그대로 봅니다.

**(2) IIS — Classic ASP + asp 섹션 잠금 해제**

```powershell
# 관리자 권한 PowerShell
Enable-WindowsOptionalFeature -Online -FeatureName IIS-ASP -All -NoRestart
& "$env:windir\system32\inetsrv\appcmd.exe" unlock config -section:system.webServer/asp
iisreset
```

> **★ `<asp>` 섹션은 IIS 애플리케이션 루트의 `web.config` 에서만 적용됩니다.**
> 하위 디렉터리에 두면 IIS 가 **오류 없이 조용히 무시**합니다. (2026-11-24 실측)
> `server-asp` 의 include 는 전부 상대경로라 `enableParentPaths` 가 **필수**입니다.
> 이 폴더를 사이트 루트가 아닌 하위 폴더(`<사이트루트>\react`)에 두면
> 사이트 루트 `web.config` 에도 같은 `<asp>` 블록을 넣어야 API 가 500 이 나지 않습니다.

### 1-2. 개발 (권장)

```powershell
npm install
npm run dev          # http://localhost:5173/
```

Vite dev 서버가 `/react/server-asp` · `/react/upload` 를 `localhost:8080` 으로 프록시합니다.
브라우저 입장에서는 같은 출처이므로 **ASP 세션 쿠키가 그대로 붙습니다.** (CORS 설정 불필요)
CSS/JS 는 `public/assets/` 에 있어 dev 서버가 직접 서빙합니다 (프록시 대상 아님).

### 1-3. 배포

```powershell
npm run build        # -> dist\
```

`dist` 는 IIS 가 바로 서비스합니다. 별도 복사가 필요 없습니다.

```
http://localhost:8080/react/        ->  302  ->  /react/dist/
http://localhost:8080/react/dist/
```

### 1-4. 배치 경로를 바꾸려면

| 바꿀 곳 | 사이트 루트 아래 `react` 폴더 (기본) | 이 폴더가 사이트 루트 |
|---|---|---|
| `server-asp/App.Conf.asp` `APP_ROOT` | `"/react/server-asp"` | `"/server-asp"` |
| `server-asp/App.Conf.asp` `UPLOAD_ROOT` | `"/react/upload"` | `"/upload"` |
| `server-asp/App.Conf.asp` `SPA_ROOT` | `"/react/dist"` | `"/dist"` |
| `default.asp` `SPA_PATH` | `"/react/dist/"` | `"/dist/"` |
| `vite.config.js` `base` (build) | `'/react/dist/'` | `'/dist/'` |
| `.env.local` `VITE_API_BASE` | (기본값 사용) | `/server-asp/api` |

### 1-5. 디버그 빌드 (번들을 읽어야 할 때)

`dist\assets\index-*.js` 는 **압축된 결과물**입니다. 사람이 읽는 원본은 `src\` 이고,
`dist` 를 직접 고치면 다음 빌드에 덮어써집니다.

브라우저에서 실제로 도는 코드를 따라가야 할 때만 아래로 빌드합니다.

```powershell
npm run build:debug      # 압축 해제 + 소스맵
npm run build            # ★ 확인 끝나면 반드시 되돌릴 것
```

| | `build` | `build:debug` |
|---|---|---|
| 번들 | 305 KB (1줄) | **805 KB (18,580줄)** |
| 소스맵 | 없음 | 1,577 KB |
| 개발자도구 Sources | 압축본만 보임 | **원본 `.jsx` 가 그대로 보임** |
| 변수명 | `np`, `c.jsx`, `x1` | `createRoot`, `AppProvider`, `App` |

디버그 빌드는 전송량이 **3배 가까이 늘고 소스가 그대로 노출**됩니다. 로컬 확인용으로만 쓰세요.

> 소스맵(`.map`)은 IIS 기본 MIME 목록에 없어 그냥 두면 404 가 납니다.
> `react/public/web.config` 에 `application/json` 으로 등록해 뒀습니다.

---

## 2. 검증

```powershell
# 동봉 백엔드 전 기능 E2E (로그인 / 글쓰기 / 첨부 / 댓글 / 삭제 / CSRF / 로그아웃)
powershell -ExecutionPolicy Bypass -File tools\CheckApi.ps1

# 이 폴더가 사이트 루트라면
powershell -ExecutionPolicy Bypass -File tools\CheckApi.ps1 -ApiPath /server-asp/api
```

`-ApiPath` 는 `src/app/config.js` 의 `API_BASE` 와 같아야 합니다.

`CheckApi.ps1` 은 실제 글을 쓰고 지웁니다. **운영 DB 에는 돌리지 마세요.**

SPA 화면이 실제로 그려지는지는 헤드리스 브라우저로 확인합니다.

```powershell
foreach ($r in '', 'about', 'portfolio', 'board/free', 'contact', 'login') {
  & "C:\Program Files\Google\Chrome\Application\chrome.exe" --headless --disable-gpu `
    --virtual-time-budget=6000 --dump-dom "http://localhost:8080/react/dist/$r" |
    Select-String -Pattern '<h2' | Select-Object -First 1
}
```

---

## 3. 폴더 구조

```
react\                          ← 이 리포지토리
│
├─ index.html                   Vite 진입 (public/assets 의 style.css 를 link)
├─ vite.config.js               base / dev 프록시
├─ package.json
├─ web.config                   ★ 이 폴더용 IIS 설정 (ASP 런타임 · 소스 차단 · upload)
├─ default.asp                  /react/ -> /react/dist/ 302 스텁
├─ .env.example                 VITE_API_BASE / VITE_ASP_VIEW
│
├─ src\                         ★ 사람이 읽는 원본
│   ├─ app\config.js            ★ 유일한 "위치" 설정 (API_BASE · ASP_VIEW_ROOT)
│   ├─ api\client.js            fetch 래퍼 (봉투 해제 · CSRF · 오류 변환)
│   ├─ app\AppContext.jsx       부트스트랩 1회 + 로그인/로그아웃
│   ├─ app\useAsync.js          loading/data/error + 경쟁조건 처리
│   ├─ app\navMap.js            tb_menu(ASP URL) -> React 라우트 변환
│   ├─ components\              Layout Header Footer Pagination Breadcrumb …
│   └─ pages\                   Home About Portfolio* Board* Article* Login Contact
│
├─ public\                      빌드하면 dist 루트로 그대로 복사된다
│   ├─ assets\css\style.css     ★ 네 스택이 같은 파일의 사본
│   ├─ assets\js\common.js      (SPA 는 불러오지 않는다. 4-4 참고)
│   └─ web.config               dist 전용 (SPA 딥링크 404 -> index.html + 캐시 정책)
│
├─ dist\                        빌드 산출물 ← IIS 가 서비스하는 화면
│
├─ server-asp\                  ★ 동봉된 Classic ASP JSON API
│   ├─ App.Conf.asp             배치 경로(APP_ROOT · UPLOAD_ROOT · SPA_ROOT) / DB 접속
│   ├─ api\                     진입점 17개
│   │   Config / Login / Logout / Main / About
│   │   PortfolioList / PortfolioView
│   │   BoardList / ArticleView / ArticleWrite / ArticleDelete
│   │   CommentWrite / CommentDelete / FileUpload / FileDelete / Contact
│   │   Download                ★ 첨부 다운로드 (ASP 화면 계층 없이 동작하도록 추가)
│   ├─ code\api\
│   │   Api.Code.asp            API 공통 (응답 봉투 · 본문 파싱 · CSRF · 권한)
│   │   ApiBoard.Code.asp       게시판 공통 (bid 검증 — 실패 시 HTML 이 아니라 JSON)
│   ├─ code\Common.Code.asp     공통 헬퍼 (UpUrl 업로드 경로 정규화 포함)
│   ├─ lib\JsonOut.Class.asp    ★ JSON "생성기" (Json.Class.asp 는 파서 전용)
│   ├─ lib\ model\ conf\        도메인 로직 (ASP 스택에서 복사)
│   └─ (view 계층 없음 — React 가 그 자리다)
│
├─ upload\   board\ portfolio\ profile\      server-asp 가 여기에 쓴다
├─ db\mssql\ 01_schema.sql 02_seed.sql 03_proc.sql
├─ docs\     ARCHITECTURE.md  DATABASE.md
└─ tools\CheckApi.ps1           API E2E
```

---

## 4. API 규약

### 4-1. 응답 봉투

```jsonc
// 성공
{ "ok": true,  "data": { ... } }
// 실패
{ "ok": false, "error": { "code": "LOGIN_REQUIRED", "message": "로그인이 필요합니다." } }
```

HTTP 상태코드도 함께 맞춥니다. `400 BAD_REQUEST` · `401 LOGIN_REQUIRED` ·
`403 FORBIDDEN|CSRF|GUEST_PW|SECRET_LOCKED` · `404 NOT_FOUND` · `405 METHOD_NOT_ALLOWED` ·
`429 RATE_LIMIT` · `500 SAVE_FAILED`.

`src/api/client.js` 가 봉투를 벗겨 `data` 만 돌려주고, 실패는 `ApiError` 로 던집니다.
그래서 화면 코드에는 `res.ok` 분기가 한 줄도 없습니다.

### 4-2. 엔드포인트

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET  | `server-asp/api/Config.asp` | 부트스트랩 : 사이트설정 · 메뉴 · 게시판 · 내 세션 · CSRF |
| POST | `server-asp/api/Login.asp` | 로그인 (새 CSRF 토큰 동봉) |
| POST | `server-asp/api/Logout.asp` | 로그아웃 |
| GET  | `server-asp/api/Main.asp` | 메인 (히어로 · 지표 · 대표 PF · 최근글) |
| GET  | `server-asp/api/About.asp` | 경력 + 기술스택 |
| GET  | `server-asp/api/PortfolioList.asp` | `?category=&page=&size=` |
| GET  | `server-asp/api/PortfolioView.asp` | `?id=` |
| GET  | `server-asp/api/BoardList.asp` | `?bid=&page=&cid=&sf=&sw=` |
| GET  | `server-asp/api/ArticleView.asp` | `?bid=&id=` (본문 + 첨부 + 댓글) |
| POST | `server-asp/api/ArticleWrite.asp` | `?bid=` + body `{mode,id,title,content,…}` |
| POST | `server-asp/api/ArticleDelete.asp` | `?bid=` + body `{id,guestPw}` |
| POST | `server-asp/api/CommentWrite.asp` | `?bid=` + body `{articleId,parentId,content,…}` |
| POST | `server-asp/api/CommentDelete.asp` | `?bid=` + body `{articleId,commentId,guestPw}` |
| POST | `server-asp/api/FileUpload.asp` | `?bid=&id=&_csrf=` + **multipart** (`upfile1..N`) |
| POST | `server-asp/api/FileDelete.asp` | `?bid=` + body `{fileId}` |
| POST | `server-asp/api/Contact.asp` | 문의 접수 |

### 4-3. CSRF

ASP 세션이 토큰을 들고 있고 POST 마다 대조합니다.
`Config.asp` 가 준 토큰을 `X-CSRF-Token` 헤더(없으면 본문 `_csrf`)로 보냅니다.

**로그인·로그아웃하면 세션이 재발급되어 토큰이 바뀝니다.**
`AppContext` 가 두 경우 모두 `Config.asp` 를 다시 호출해 토큰을 갱신합니다.

---

### 🔑 PG 키는 비어 있습니다

공개 저장소라 `server-asp/App.Conf.asp` 의 PG 키와 `CRYPT_KEY` 를
**플레이스홀더로 커밋**합니다. 결제 화면은 ASP 스택 쪽으로 링크되므로
이 리포지토리만 띄울 때는 영향이 없고, 키가 비어 있으면 그 모듈이 비활성될 뿐입니다.

Classic ASP 는 조건부 `include` 가 안 되므로 로컬 설정 파일로 분리할 수 없습니다.
키를 채운 뒤에는 **커밋 전에 `git diff server-asp/App.Conf.asp` 로 확인**하세요.

---
## 5. 설계 판단 (왜 이렇게 했는가)

### 5-1. 왜 `bid` 는 쿼리스트링인가

Classic ASP 는 **`Request.Form` 을 한 번이라도 읽으면 `Request.BinaryRead` 가 실패**합니다.
이 API 의 POST 본문은 JSON 이라 BinaryRead 로 원문 바이트를 직접 읽어야 하고,
첨부 업로드는 multipart 라 역시 BinaryRead 입니다.
그래서 **본문을 읽기 전에 알아야 하는 값(`bid`, 업로드의 `id`/`_csrf`)은 전부 URL 로** 받습니다.
1차 스택의 `code/board/Board.Code.asp` 가 같은 이유로 QueryString 만 읽습니다.

### 5-2. 왜 글 저장과 첨부 업로드가 두 요청인가

같은 이유입니다. 한 요청에서 JSON 본문과 파일을 동시에 받을 수 없습니다.
`ArticleWrite.asp`(JSON) 로 글을 저장해 `article_id` 를 받고,
그 id 로 `FileUpload.asp`(multipart) 를 호출합니다.

### 5-3. 왜 `assets/js/common.js` 를 불러오지 않는가 (파일은 들고 있으면서)

`common.js` 는 문서 로드 시점에 `.nav-toggle` / `.theme-toggle` 을 찾아 이벤트를 겁니다.
SPA 는 그 시점에 DOM 이 비어 있고, 이후 React 가 노드를 갈아끼우므로 핸들러가 죽은 노드에 남습니다.
그래서 메뉴 토글 · 테마 전환 · 폼 검증은 React 상태로 직접 구현했습니다.
단 **테마 저장 키는 `jkw-theme` 로 ASP 스택과 같습니다.** 두 스택을 오가도 테마가 유지됩니다.

### 5-4. 왜 방문 통계를 푸터에 안 찍는가

ASP 는 화면 요청 1건 = 방문 1건이지만, SPA 는 화면 하나에 API 를 여러 번 호출합니다.
그래서 `conf/Common.Conf.asp` 에서 **`/api/` 요청을 방문 집계에서 제외**했고,
푸터에도 숫자를 띄우지 않습니다. 두 스택의 통계가 어긋나 보이는 것을 막기 위함입니다.

### 5-5. React 로 옮기지 않은 화면

회원가입 · 소셜 로그인 · 휴대폰 인증 · 후원(결제) · 관리자 는 **ASP 화면으로 링크**합니다.

- 소셜 로그인과 PG 결제는 **리다이렉트 URI / 콜백 URL 이 ASP 페이지 주소로 외부 콘솔에 등록**되어 있습니다.
  React 로 옮기려면 구글·네이버·카카오·토스·이니시스 콘솔 설정을 전부 바꿔야 해서 이 스택의 범위를 넘습니다.
- 어디로 보낼지는 `src/app/config.js` 의 `ASP_VIEW_ROOT` 한 곳이 정합니다.
  `.env.local` 에서 `VITE_ASP_VIEW=` (빈 값) 로 두면 **그 링크들을 화면에서 숨깁니다.**
  ASP 스택 없이 이 리포지토리만 띄울 때 쓰세요.
- 첨부 **다운로드**는 예외입니다. 동봉 백엔드에 `api/Download.asp` 를 두어
  **이 리포지토리 안에서 처리**합니다. 권한 검사와 다운로드 카운트가 필요해
  정적 파일로 바로 내려줄 수 없기 때문입니다.

### 5-6. SPA 딥링크를 URL Rewrite 없이 처리한 방법

이 서버에는 **URL Rewrite 모듈이 설치돼 있지 않습니다**(2026-11-20 확인).
그래서 IIS 기본 모듈인 `httpErrors` 로 404 를 `index.html` 로 돌립니다 (`react/public/web.config`).

실측 결과 `/react/dist/board/free` 와 `/react/dist/portfolio/1` 모두 **HTTP 200 + index.html** 로 응답합니다.

### 5-7. 전역 이름을 길게 지은 이유

VBScript 는 대소문자를 구분하지 않고, **전역 `Function` 과 같은 이름으로 `Dim` 하면
"다시 정의된 이름"(800a0411) 으로 페이지 전체가 죽습니다.**

처음에 본문 파서를 `BS` / `BI` / `BB` 로 지었더니,
호출하는 쪽 루프 변수 `Dim bi` 와 `Function BI()` 가 충돌해 `Config.asp` 가 통째로 500 이 났습니다.
지금은 `BodyStr` / `BodyInt` / `BodyBool`, JSON 출력 객체는 `JOut` 입니다.

같은 사고를 미리 잡도록 ASP 스택의 `tools/CheckAsp.ps1` 도 고쳤습니다.
한 줄짜리 프로시저(`Sub X() : … : End Sub`)를 열린 블록으로 오인해
그 뒤의 전역 선언을 검사에서 빠뜨리던 버그가 있었습니다.

---

## 6. 트러블슈팅

| 증상 | 원인 / 해결 |
|---|---|
| 화면에 "서버에 연결하지 못했습니다" | `server-asp/api/Config.asp` 가 안 뜬다. ASP 스택 자체를 먼저 확인 |
| API 가 전부 500 | `<asp enableParentPaths="true">` 미적용. 이 섹션은 **IIS 애플리케이션 루트에서만** 먹는다 (1-1 참고). `server-asp` 의 include 는 전부 상대경로라 이게 없으면 전멸한다 |
| 업로드 이미지가 404 | `App.Conf.asp` 의 `UPLOAD_ROOT` 와 실제 폴더 위치가 맞는지 확인 (1-4 표). 다른 스택이 올린 첨부라면 그 스택의 `upload` 폴더를 복사해야 한다 |
| 모든 POST 가 403 CSRF | 로그인/로그아웃 후 `Config.asp` 를 다시 안 불렀다 |
| 로그인은 되는데 다음 요청에서 풀림 | 쿠키가 안 붙는다. dev 는 프록시를 써야 한다 (`vite.config.js`) |
| JSON 대신 HTML 이 온다 | ASP 런타임 오류. 응답 원문이 `ApiError.message` 에 실려 화면에 그대로 보인다 |
| 한글이 깨진다 | `Response.CodePage = 65001` (App.Conf.asp) + 본문을 ADODB.Stream UTF-8 로 디코딩하는지 확인 |
| 딥링크 새로고침이 404 | `react/dist/web.config` 가 빌드에 포함됐는지 확인 (`public/` 에 원본이 있다) |
| `package.json` 이나 `src/` 가 보인다 | 이 폴더의 `web.config` `hiddenSegments` / `fileExtensions` 가 적용되는지 확인 |
| `server-asp/App.Conf.asp` 가 열린다 | 같은 곳. `App.Conf.asp` 와 `code` / `model` / `lib` / `conf` 가 `hiddenSegments` 에 있어야 한다 |
