# jkw.com 개인 홈페이지 — 아키텍처 설계서

> **Ver 1.0 / 2026-08-20**
> 1차 구현: **Classic ASP (VBScript) + MS SQL Server + IIS**
> 이후 동일 요구사항을 Java Spring Boot / Python / PHP 로 포팅 (DB 스키마 공유)

---

## 1. 메뉴 구조 (확정 — 하이브리드안)

```
HOME  (/)
│
├─ ABOUT              /about/
│   ├─ 소개            /about/default.asp
│   ├─ 경력 · 학력      /about/career.asp
│   ├─ 기술 스택        /about/skill.asp
│   └─ 이력서          /about/resume.asp
│
├─ PORTFOLIO          /portfolio/
│   ├─ 목록 (카테고리 필터)   /portfolio/default.asp
│   └─ 상세 (케이스 스터디)   /portfolio/view.asp?id=
│
├─ BLOG               /board/list.asp?bid=blog          [skin: blog]
│
├─ COMMUNITY
│   ├─ 공지사항        /board/list.asp?bid=notice        [skin: list]
│   ├─ 자유게시판       /board/list.asp?bid=free          [skin: list]
│   ├─ 자료실          /board/list.asp?bid=data          [skin: list  + 첨부]
│   └─ 갤러리          /board/list.asp?bid=gallery       [skin: gallery]
│
├─ GUESTBOOK          /board/list.asp?bid=guest          [skin: guest]
│
├─ CONTACT            /contact/
│
├─ MEMBER             /member/  (로그인 · 회원가입 · 마이페이지)
│
└─ ADMIN              /admin/   (대시보드 · 게시판 · 회원 · 포트폴리오 · 문의 · 통계 · 설정)
```

### 설계 핵심 — 게시판 엔진 1벌
`BLOG` · `공지사항` · `자유게시판` · `자료실` · `갤러리` · `방명록` 은 **모두 같은 코드(`/board/*.asp`)와 같은 테이블**을 씁니다.
`tb_board_master.board_id` 로 구분하고 `skin_type` 값에 따라 **출력 템플릿만 교체**합니다.

```
                       tb_board_master
                             │
   ┌────────┬────────┬───────┼────────┬─────────┬────────┐
 notice    free     data   gallery   blog     guest      ← 행(row) 1개 = 게시판 1개
   │        │        │       │        │         │
   └────────┴────────┴───────┴────────┴─────────┘
                   동일한 board 엔진
        list.asp / view.asp / write.asp / write_ok.asp ...
                             │
              skin_type 으로 렌더링만 분기
        list │ gallery │ blog │ guest
```

**효과**
- 게시판을 새로 추가할 때 → **SQL INSERT 한 줄**, 코드 수정 0
- 4개 언어로 포팅할 때 → 각 언어마다 게시판 엔진 1개만 만들면 6개 메뉴가 동시에 완성
- 권한 · 페이징 · 첨부 · 댓글 · 검색 로직이 한 곳에만 존재 → 버그 수정 지점 단일화

---

## 2. 시스템 구성도

```
┌──────────────────────────────────────────────────────────┐
│  Client  (PC / Tablet / Mobile)                          │
│  HTML5 · CSS3 (Mobile-First Responsive) · Vanilla JS     │
└───────────────────────┬──────────────────────────────────┘
                        │ HTTP/HTTPS
┌───────────────────────▼──────────────────────────────────┐
│  IIS 10 (Windows Server / Windows 11)                    │
│  ├─ Classic ASP (VBScript, CodePage 65001 = UTF-8)       │
│  ├─ Session State (InProc)                               │
│  └─ Static: /assets, /upload                             │
└───────────────────────┬──────────────────────────────────┘
                        │ ADO (OLEDB / MSOLEDBSQL)
┌───────────────────────▼──────────────────────────────────┐
│  MS SQL Server 2019+                                     │
│  DB: jkwcom  (NVARCHAR 전면 사용, 15 tables)              │
└──────────────────────────────────────────────────────────┘
```

---

## 3. 애플리케이션 레이어

Classic ASP 에는 프레임워크가 없으므로 **include 규약으로 계층을 강제**합니다.
계층 구분과 파일 명명은 사내 운영 프로젝트 **ZOCBOv7** 의 관례를 그대로 따릅니다.

| 계층 | 위치 | 역할 | 규칙 |
|---|---|---|---|
| **View** | `asp/view/**/*.asp` | URL 진입점. Code 를 include 하고 HTML 만 출력 | SQL·비즈니스 로직 **금지**. 출력은 `AVH()` / `HE()` 통과 |
| **Layout** | `asp/view/include/Header·Gnb·Lnb·Footer·AdminSide.asp` | 공통 레이아웃 · 메뉴 | Code 가 채운 `g_*` 전역만 읽음 |
| **Code** | `asp/code/**/*.Code.asp` | 컨트롤러. 권한 → 파라미터 → 모델 호출 → 변수 준비 | 화면 출력 금지 (리다이렉트·알럿 제외) |
| **Model** | `asp/model/<도메인>/*.Class.asp` | 도메인 클래스. DB 접근 | `DBHelper` 만 사용. `ExecuteGetRows()` 로 2차원 배열 반환 |
| **Lib** | `asp/lib/*.Class.asp` | 도메인 무관 공용 클래스 | 특정 테이블을 알지 못함 |
| **Data Access** | `asp/lib/DBHelper.Class.asp` | 커넥션 · **파라미터 바인딩 실행기** | ★ ADODB 를 직접 다루는 유일한 파일 |
| **Conf** | `asp/App.Conf.asp`, `asp/conf/Common.Conf.asp` | 환경 상수 / 요청 공통 초기화 | 유일한 설정 지점 |

### 클래스 규약 (ZOCBOv7 동일)

```asp
Class CArticle                      ' C 접두어
    Public DBHelper
    Private Sub Class_Initialize()
        Set DBHelper = New CDBHelper
        DBHelper.ConnectionString = ConnectionString(DBCONN_JKWCOM)
    End Sub
    Public Function Article_l(...)  ' _l 목록 _v 상세 _i 등록 _u 수정 _d 삭제 _c 건수 _p 처리
        With DBHelper
            .Sql = "SELECT ... WHERE board_id = ?"
            .SetParamVarchar(pBoardId)
        End With
        Article_l = DBHelper.ExecuteGetRows()
    End Function
End Class

Dim Article : Set Article = New CArticle    ' 파일 끝에서 싱글턴 생성
```

### include 순서

```asp
' ── view/board/List.asp  (실제 요청되는 파일)
<%@ LANGUAGE="VBScript" CODEPAGE="65001" %#>
<% Option Explicit %#>
<!--#include virtual="/code/board/List.Code.asp"-->
<!--#include virtual="/view/include/Header.asp"-->
      ... HTML ...
<!--#include virtual="/view/include/Footer.asp"-->

' ── code/board/List.Code.asp
<!--#include virtual="/code/board/Board.Code.asp"-->    ' → Common.Code.asp → App.Conf + lib + model + conf
<%
    ' 1. 권한 → 2. 파라미터 → 3. 모델 호출 → 4. 변수 준비
%#>
```

> **ZOCBOv7 과 다른 점 1** — `@LANGUAGE` 지시자와 `Option Explicit` 을 Code 가 아닌 **view** 에 둡니다.
> include 파일의 `@` 지시자는 IIS 구성에 따라 무시될 수 있어, 요청 파일에 두는 쪽이 안전합니다.
>
> **ZOCBOv7 과 다른 점 2** — 데이터 접근을 저장 프로시저 전용에서 **파라미터 바인딩 인라인 SQL** 로 바꿨습니다.
> `DBHelper` 는 `.StoredProc` 도 그대로 지원하지만, PostgreSQL 이식 시 T-SQL 재작성을 피하기 위해
> 이 프로젝트는 인라인 SQL 을 기본으로 씁니다. (`docs/DATABASE.md` 8장)
>
> **ZOCBOv7 과 다른 점 3** — CodePage 를 949(EUC-KR) 대신 **65001(UTF-8)** 로 통일했습니다.

---

## 4. 디렉터리 구조

```
D:\jkw.com\                     ← IIS 사이트 루트 (4개 스택이 공유)
│
├─ default.asp                 사이트 진입 스텁 (302 → /asp/view/main/Default.asp)
├─ web.config                  사이트 공용 IIS 설정 (소스 폴더 차단 / 보안 헤더 / upload · assets)
├─ README.md                   설치 · 개발 규약 · 트러블슈팅
│
├─ asp\                        ★ 1차 : Classic ASP 스택        URL : /asp/
│   │
│   ├─ default.asp             ASP 진입점 (메인으로 302)
│   ├─ App.Conf.asp            ★ 유일한 환경 설정 지점 (DB·상수·전역)
│   ├─ web.config              Classic ASP 런타임 설정 (asp 섹션)
│   │
│   ├─ conf\
│   │   └─ Common.Conf.asp     요청 공통 초기화 (설정 로드 · 세션 검증 · 방문로그)
│   │
│   ├─ lib\                    ★ 범용 클래스 (HTTP 직접 접근 차단)
│   │   ├─ DBHelper.Class.asp  ADODB 를 다루는 유일한 파일
│   │   ├─ StringUtil.Class.asp
│   │   ├─ DateUtil.Class.asp
│   │   ├─ RequestUtil.Class.asp
│   │   ├─ Paging.Class.asp
│   │   ├─ Crypt.Class.asp     SHA-256 / Base64 / 쿠키 인코딩
│   │   ├─ Json.Class.asp      순수 VBScript JSON 파서
│   │   ├─ Http.Class.asp      ServerXMLHTTP 래퍼
│   │   ├─ Cookie.Class.asp
│   │   ├─ FileUpload.Class.asp   multipart 파서 (외부 컴포넌트 없음)
│   │   └─ FileDownload.Class.asp
│   │
│   ├─ model\                  ★ 도메인 클래스 (HTTP 직접 접근 차단)
│   │   ├─ common\     Config · Menu · Auth · Visit
│   │   ├─ board\      Board · Article · Comment · BoardFile
│   │   ├─ member\     Member · PhoneAuth · Social
│   │   ├─ donate\     Donate · PgInicis
│   │   ├─ portfolio\  Portfolio
│   │   ├─ about\      About (경력 + 스킬)
│   │   └─ contact\    Contact
│   │
│   ├─ code\                   ★ 컨트롤러 (HTTP 직접 접근 차단)
│   │   ├─ Common.Code.asp     모든 Code 가 최초로 include
│   │   └─ main\ about\ portfolio\ board\ member\ donate\ contact\ admin\
│   │
│   ├─ view\                   화면 = URL 진입점   ( /asp/view/... )
│   │   ├─ include\    Header · Gnb · Lnb · Footer · AdminSide
│   │   └─ main\ about\ portfolio\ board\ member\ donate\ contact\ admin\
│   │
│   ├─ db\mssql\
│   │   ├─ 01_schema.sql       테이블 16개 · 인덱스 · 제약
│   │   ├─ 02_seed.sql         초기 데이터 (설정/회원/메뉴/게시판/샘플)
│   │   └─ 03_proc.sql         뷰 2 · 집계 프로시저 2
│   │
│   └─ tools\
│       ├─ SetupDb.ps1         DB 구축 / 검증
│       ├─ CheckAsp.ps1        정적 점검 + 전 페이지 HTTP 스모크
│       └─ E2E.ps1             기능 검증 (로그인·글쓰기·첨부·댓글·결제·삭제)
│
├─ javaspringboot\             ★ 2차 : Spring Boot 스택 (별도 포트 / 내장 톰캣)
│
├─ assets\                     ← 스택 공용
│   ├─ css\style.css           반응형 전체 스타일 (단일 파일, 4개 스택 공용)
│   ├─ js\common.js            네비 · 테마 · 폼검증 · 첨부 (라이브러리 의존 0)
│   └─ img\
│
├─ upload\                     ← 스택 공용. 첨부파일 (실행 권한 제거, 이미지만 직접 접근 허용)
│   ├─ board\yyyymm\
│   ├─ portfolio\
│   └─ profile\
│
└─ docs\                       ← 스택 공용
    ├─ ARCHITECTURE.md         ← 이 문서
    └─ DATABASE.md             테이블 명세 · ERD · PostgreSQL 이식 규칙
```

> **왜 assets / upload / docs 만 루트에 남겼나**
> 4개 스택이 같은 화면과 같은 첨부파일을 쓴다. CSS 를 스택마다 복사하면
> 한 곳만 고쳐지고 나머지가 뒤처진다. 스택이 달라지는 축(라우팅·ORM·템플릿·인증)만
> 스택 폴더 안에 두고, 공유 자산은 한 벌만 둔다.

> `code` · `model` · `lib` · `conf` · `db` · `docs` · `tools` · `javaspringboot` 와
> `App.Conf.asp` 는 루트 `web.config` 의 `hiddenSegments` 로 **HTTP 직접 접근이 차단**됩니다.
> (`hiddenSegments` 는 경로 어느 위치의 세그먼트든 막으므로 `/asp/code/...` 도 차단됩니다)
> 서버 사이드 `#include` 는 HTTP 요청이 아니므로 영향을 받지 않습니다.

---

## 5. 반응형 전략 (Mobile-First)

CSS 프레임워크 없이 **단일 `style.css`** 로 처리합니다. (외부 CDN 의존 0)

### 브레이크포인트
| 이름 | 범위 | 레이아웃 |
|---|---|---|
| Mobile (기본) | ~ 599px | 1단, 햄버거 메뉴, 게시판 목록 = 카드형 |
| Tablet | 600 ~ 1023px | 2단 그리드, 상단 메뉴 축약 |
| Desktop | 1024px ~ | 3~4단 그리드, 전체 GNB 노출 |

### 핵심 기법
- `:root` **CSS 변수**로 색/여백/폰트 토큰화 → 테마 변경 1곳
- 레이아웃은 **Flexbox + CSS Grid** (`auto-fit / minmax`) → 미디어쿼리 최소화
- `<meta name="viewport" content="width=device-width, initial-scale=1">`
- **게시판 테이블의 모바일 대응** — 데스크톱은 `<table>`, 모바일은 같은 마크업을
  `display:block` 으로 전환 + `td::before { content: attr(data-label) }` 로 라벨 표시
  → HTML 은 한 벌, CSS 만으로 카드형 변환
- 이미지 `max-width:100%; height:auto`, 갤러리는 `aspect-ratio` 로 비율 고정
- 터치 타겟 최소 **44×44px**, 폼 입력 `font-size:16px` (iOS 자동 확대 방지)
- 다크모드 `@media (prefers-color-scheme: dark)` 대응

---

## 6. 보안 정책

| 위협 | 대응 | 구현 위치 |
|---|---|---|
| **SQL Injection** | 문자열 연결 쿼리 전면 금지. `ADODB.Command` + `?` 파라미터 바인딩만 사용 | `inc/db.asp` — `GetRs()`, `ExecSql()`, `GetOne()` |
| **XSS** | 출력 시 `HE()` (HTML Escape) 필수. 에디터 본문만 화이트리스트 태그 허용 | `inc/common.asp` |
| **CSRF** | 세션 토큰을 hidden 으로 발급 → `_ok.asp` 에서 검증 | `inc/auth.asp` — `MakeToken()` / `CheckToken()` |
| **인증 우회** | 모든 처리 페이지 첫 줄에 `CheckLevel(n)`. 게시판별 권한은 `tb_board_master.auth_*` 로 DB 제어 | `inc/auth.asp` |
| **비밀번호** | 평문 저장 금지. 회원별 **salt + SHA2_256** (SQL `HASHBYTES`) | `tb_member.user_pw / user_salt` |
| **파일 업로드** | 확장자 **화이트리스트**, 실제 파일명 노출 안 함(GUID 저장), `/upload` 실행권한 제거, 다운로드는 `download.asp` 경유 | `inc/upload.asp`, `web.config` |
| **경로 조작** | 업로드/다운로드 경로에 `..`, `/`, `\` 차단 | `inc/upload.asp` |
| **정보 노출** | 상용 시 `customErrors` 로 상세 오류 숨김, `/inc`·`/db` 디렉터리 접근 차단 | `web.config` |
| **세션 고정** | 로그인 성공 시 세션 재발급 + IP/UA 지문 저장 | `member/login_ok.asp` |

---

## 7. 권한 모델

`tb_member.member_level` (숫자가 클수록 상위 권한)

| Level | 명칭 | 범위 |
|---|---|---|
| `0` | 정지 | 로그인 불가 |
| `1` | 비회원(Guest) | 공개 게시판 읽기, 방명록 작성 |
| `3` | 일반회원 | 게시판 쓰기/댓글, 마이페이지 |
| `5` | 운영자 | 게시글 관리, 문의 답변 |
| `9` | 최고관리자 | 전체 (게시판 생성, 회원, 설정) |

게시판마다 `auth_list` / `auth_read` / `auth_write` / `auth_comment` / `auth_admin` 을
따로 두어, **같은 엔진이면서도 게시판별로 권한을 다르게** 굴릴 수 있습니다.
예) `notice` → write=9(관리자만), read=0(전체) / `free` → write=3(회원) / `guest` → write=0(누구나)

---

## 8. 화면 흐름 (게시판 엔진)

```
list.asp?bid=free&page=1&sf=title&sw=검색어
   │  tb_board_master 조회 → 권한/스킨/페이지수 결정
   │  tb_board_article 페이징 조회 (ROW_NUMBER)
   ├─▶ view.asp?bid=&id=        조회수+1, 첨부/댓글 조회
   │      ├─▶ comment_ok.asp    댓글 등록/삭제
   │      ├─▶ download.asp?fid= 다운로드 카운트+1, 스트림 전송
   │      └─▶ write.asp?mode=modify
   ├─▶ write.asp?bid=&mode=write|reply|modify
   │      └─▶ write_ok.asp      CSRF검증 → 업로드 → INSERT/UPDATE
   └─▶ delete_ok.asp            논리삭제(is_del=1)
```

**페이징** — MSSQL `ROW_NUMBER() OVER()` 서브쿼리 방식 (SQL 2008 호환).
`OFFSET/FETCH` 로 바꿀 수 있게 `db.asp` 에 페이징 헬퍼를 분리해 둠.

**답변형 정렬** — `group_no`(원글ID) / `group_order`(그룹내 순번) / `group_depth`(들여쓰기)
정렬은 `ORDER BY group_no DESC, group_order ASC`

---

## 9. 다국어(4개 스택) 포팅 계획

| 항목 | Classic ASP | Spring Boot | Python | PHP |
|---|---|---|---|---|
| DB | **동일 스키마 공유 (jkwcom)** | ← | ← | ← |
| 라우팅 | 파일 = URL | `@Controller` | FastAPI/Django URLconf | 파일 = URL 또는 라우터 |
| DB 접근 | `inc/db.asp` (ADO) | MyBatis / JPA | SQLAlchemy / pyodbc | PDO |
| 템플릿 | include + `<% %>` | Thymeleaf | Jinja2 | 파일 include |
| 인증 | Session | Spring Security | 세션 미들웨어 | `$_SESSION` |
| 정적 리소스 | **`/assets` 그대로 재사용** | ← | ← | ← |

> **CSS/JS 와 DB 스키마를 4개 스택이 공유**하도록 설계했습니다.
> 그래야 언어별 차이(라우팅·ORM·템플릿·인증)만 순수하게 비교됩니다.

---

## 10. 구현 순서

1. `db/01_schema.sql`, `db/02_seed.sql` 실행
2. `inc/*` 공통 계층 (config → common → db → auth → upload → layout)
3. `assets/css/style.css` 반응형 레이아웃
4. `default.asp` 메인
5. `board/*` **게시판 엔진** ← 가장 비중 큼
6. `about/*`, `portfolio/*`, `contact/*`
7. `member/*`
8. `admin/*`
9. `web.config` + 배포 점검
