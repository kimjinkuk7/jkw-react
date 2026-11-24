# jkw.com — 데이터베이스 설계서 (SSOT)

> 이 문서가 **단일 진실 원천(Single Source of Truth)** 입니다.
> `db/mssql/*.sql` 과 (추후) `db/postgresql/*.sql` 은 이 문서에서 파생됩니다.
>
> 1차: **MS SQL Server 2019 (15.0)** — Classic ASP 용 · DB명 `jkwcom`
> 2차: **PostgreSQL** — Spring Boot / Python / PHP 공용

---

## 1. ERD

```
┌──────────────┐
│  tb_config   │  사이트 설정 (독립)
└──────────────┘

┌──────────────┐         ┌──────────────────┐
│  tb_member   │◄────────│  tb_login_log    │
│  member_id   │         └──────────────────┘
└──────┬───────┘
       │ writer_id
       │
       │        ┌────────────────────┐
       │        │ tb_board_master    │  ★ 게시판 정의 = 메뉴 1개
       │        │ board_id (PK)      │
       │        └────┬───────────┬───┘
       │             │ board_id  │ board_id
       │             ▼           ▼
       │   ┌───────────────────┐ │
       │   │ tb_board_category │ │
       │   │ category_id (PK)  │ │
       │   └─────────┬─────────┘ │
       │             │ category_id
       │             ▼           ▼
       │        ┌─────────────────────────┐
       └───────►│  tb_board_article       │
                │  article_id (PK)        │
                │  group_no/order/depth   │ ← 답변형 계층
                └───┬─────────────────┬───┘
        article_id  │                 │  article_id
                    ▼                 ▼
        ┌────────────────────┐  ┌──────────────────┐
        │ tb_board_comment   │  │  tb_board_file   │
        │ comment_id (PK)    │  │  file_id (PK)    │
        │ parent_id (자기참조)│  └──────────────────┘
        └────────────────────┘


┌──────────────────┐  N:M  ┌────────────────────┐  N:M  ┌───────────┐
│  tb_portfolio    │◄──────│ tb_portfolio_skill │──────►│ tb_skill  │
│  portfolio_id    │       │ (portfolio_id,     │       │ skill_id  │
└──────────────────┘       │  skill_id)         │       └───────────┘
                           └────────────────────┘

┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  tb_career   │   │  tb_contact  │   │   tb_menu    │  parent_id 자기참조
└──────────────┘   └──────────────┘   └──────────────┘

┌──────────────┐  집계   ┌──────────────┐
│ tb_visit_log │────────►│ tb_visit_stat│
└──────────────┘         └──────────────┘
```

---

## 2. 테이블 목록 (16개)

| # | 테이블 | 역할 | PK | 예상 규모 |
|---|---|---|---|---|
| 1 | `tb_config` | 사이트 전역 설정 (key/value) | `config_key` | ~20행 |
| 2 | `tb_member` | 회원 | `member_id` | 소 |
| 3 | `tb_menu` | GNB 메뉴 (2 depth) | `menu_id` | ~15행 |
| 4 | **`tb_board_master`** | **★ 게시판 정의 — 행 1개 = 게시판 1개** | `board_id` | 6행 |
| 5 | `tb_board_category` | 게시판별 분류 | `category_id` | 소 |
| 6 | **`tb_board_article`** | **게시글 (전 게시판 공용)** | `article_id` | 대 |
| 7 | `tb_board_comment` | 댓글 / 대댓글 | `comment_id` | 대 |
| 8 | `tb_board_file` | 첨부파일 | `file_id` | 중 |
| 9 | `tb_portfolio` | 포트폴리오 | `portfolio_id` | 소 |
| 10 | `tb_skill` | 기술 스택 | `skill_id` | 소 |
| 11 | `tb_portfolio_skill` | 포트폴리오↔스킬 (N:M) | 복합 | 소 |
| 12 | `tb_career` | 경력/학력/수상/자격 | `career_id` | 소 |
| 13 | `tb_contact` | 문의하기 | `contact_id` | 중 |
| 14 | `tb_login_log` | 로그인 감사 로그 | `log_id` | 중 |
| 15 | `tb_visit_log` | 방문 raw 로그 | `log_id` | 대 |
| 16 | `tb_visit_stat` | 일별 집계 | `visit_date` | 소 |

---

## 3. 핵심 설계 — `tb_board_master`

게시판 6개(공지·자유·자료실·갤러리·블로그·방명록)가 **같은 코드, 같은 테이블**을 씁니다.

### 시드된 6개 게시판

| board_id | 이름 | skin_type | 댓글 | 첨부 | 분류 | 비밀글 | 답변형 | `auth_write` |
|---|---|---|---|---|---|---|---|---|
| `notice` | 공지사항 | `list` | O | O | – | – | – | **9** 관리자 |
| `free` | 자유게시판 | `list` | O | O | O | O | O | **3** 회원 |
| `data` | 자료실 | `list` | O | O(5개/50MB) | O | – | – | **5** 운영자 |
| `gallery` | 갤러리 | `gallery` | O | O(10개, 이미지만) | O | – | – | **3** 회원 |
| `blog` | BLOG | `blog` | O | O | O | – | – | **9** 관리자 |
| `guest` | 방명록 | `guest` | – | – | – | O | – | **0** 누구나 |

### 게시판을 새로 추가하려면
```sql
INSERT INTO tb_board_master (board_id, board_name, skin_type, auth_write, sort_no)
VALUES ('qna', N'Q&A', 'list', 3, 70);

INSERT INTO tb_menu (parent_id, menu_code, menu_name, menu_url, menu_depth, sort_no)
VALUES ((SELECT menu_id FROM tb_menu WHERE menu_code='community'),
        'comm_qna', N'Q&A', '/board/list.asp?bid=qna', 2, 50);
```
**ASP 코드 수정: 0줄.**

### 스킨 4종
| skin_type | 목록 렌더링 | 사용처 |
|---|---|---|
| `list` | 테이블형 (모바일에서 CSS로 카드 전환) | 공지·자유·자료실 |
| `gallery` | 썸네일 그리드 (`gallery_col` 컬럼) | 갤러리 |
| `blog` | 요약+태그 카드 리스트 | 블로그 |
| `guest` | 목록 없이 본문 나열 + 하단 입력폼 | 방명록 |

---

## 4. 권한 모델

`tb_member.member_level` — 숫자가 클수록 상위 권한.

| Level | 명칭 | 설명 |
|---|---|---|
| `0` | 정지 | 로그인 차단 |
| `1` | 비회원 | 세션 없는 방문자 (DB에 저장되지 않는 가상 레벨) |
| `3` | 일반회원 | 게시판 쓰기/댓글, 마이페이지 |
| `5` | 운영자 | 게시글·문의 관리 |
| `9` | 최고관리자 | 전체 |

게시판마다 `auth_list` / `auth_read` / `auth_write` / `auth_comment` / `auth_admin` 을 개별 지정
→ **같은 엔진이면서 게시판별로 다른 권한 정책**이 성립.

권한 판정: `현재 세션 레벨 >= 해당 게시판의 auth_* 값`

---

## 5. 비밀번호 해시 규약 ★ (4개 스택 호환의 핵심)

```
user_pw = LOWER( HEX( SHA2_256( user_salt || 평문비밀번호 ) ) )     -- 64자
user_salt = 32자 hex 랜덤 (회원별)
```

**제약: 비밀번호는 ASCII 문자만 허용** (영문·숫자·특수문자). 한글 비밀번호 금지.
→ 인코딩 차이(UTF-16 vs UTF-8 vs CP949)가 사라져 모든 스택에서 동일한 해시가 나옵니다.

| 스택 | 구현 |
|---|---|
| MS SQL | `LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', @salt + @pw), 2))` |
| PostgreSQL | `encode(digest(salt \|\| pw, 'sha256'), 'hex')` — `CREATE EXTENSION pgcrypto;` |
| Java | `MessageDigest.getInstance("SHA-256").digest((salt+pw).getBytes("UTF-8"))` → hex |
| Python | `hashlib.sha256((salt+pw).encode()).hexdigest()` |
| PHP | `hash('sha256', $salt . $pw)` |

> Classic ASP 에는 SHA-256 내장 구현이 없으므로 **SQL Server 의 `HASHBYTES` 를 계산기로 사용**합니다
> (`inc/auth.asp` 의 `Sha256Hex()` 헬퍼). 결과값 규약은 위와 동일하므로 이식성에 영향 없음.

**향후 개선 여지** — 지금은 단순 SHA-256 1회입니다. 개인 사이트 수준에선 충분하지만,
운영 규모가 커지면 PBKDF2/bcrypt(반복 스트레칭) 로 올리는 것을 권장합니다.
그 경우 `user_pw` 컬럼 앞에 `$알고리즘$` 접두어를 붙여 마이그레이션하면 됩니다.

---

## 6. 답변형 게시판 정렬 규약

```
group_no     원글의 article_id (원글은 자기 자신)
group_order  그룹 내 정렬 순서 (원글=0, 답변이 달릴수록 증가)
group_depth  들여쓰기 단계 (원글=0)
parent_id    바로 위 글의 article_id
```

**정렬**
```sql
ORDER BY is_notice DESC, group_no DESC, group_order ASC
```

**답변 등록 시** — 같은 그룹에서 `group_order` 가 기준값보다 큰 행을 먼저 +1 해서 자리를 만든 뒤 삽입:
```sql
UPDATE tb_board_article
   SET group_order = group_order + 1
 WHERE board_id = ? AND group_no = ? AND group_order > ?;
```

---

## 7. 페이징 규약

`ROW_NUMBER()` 를 쓰지 않고 **`OFFSET / FETCH`** 로 통일합니다.
(SQL Server 2012+, PostgreSQL 모두 동일 구문 → 쿼리를 그대로 이식 가능)

```sql
SELECT ...
  FROM tb_board_article
 WHERE board_id = ? AND is_del = 0
 ORDER BY is_notice DESC, group_no DESC, group_order ASC
OFFSET ? ROWS FETCH NEXT ? ROWS ONLY;
```

---

## 8. MSSQL → PostgreSQL 타입 매핑표

이 표대로 치환하면 `db/postgresql/01_schema.sql` 이 기계적으로 만들어집니다.

| MS SQL Server | PostgreSQL | 비고 |
|---|---|---|
| `INT IDENTITY(1,1)` | `INTEGER GENERATED BY DEFAULT AS IDENTITY` | |
| `BIGINT IDENTITY(1,1)` | `BIGINT GENERATED BY DEFAULT AS IDENTITY` | |
| `NVARCHAR(n)` | `VARCHAR(n)` | PG는 DB 인코딩이 UTF-8이면 그 자체로 유니코드 |
| `NVARCHAR(MAX)` | `TEXT` | |
| `VARCHAR(n)` | `VARCHAR(n)` | |
| `CHAR(64)` | `CHAR(64)` | |
| `BIT` | `BOOLEAN` | ASP는 0/1, PG는 true/false — 앱 계층에서 변환 |
| `TINYINT` | `SMALLINT` | PG에 TINYINT 없음 |
| `DATETIME2(0)` | `TIMESTAMP(0)` | |
| `DATE` | `DATE` | |
| `DECIMAL(3,1)` | `NUMERIC(3,1)` | |
| `CURRENT_TIMESTAMP` | `CURRENT_TIMESTAMP` | **동일** ✔ |
| `COALESCE()` | `COALESCE()` | **동일** ✔ |
| `CONCAT()` | `CONCAT()` | **동일** ✔ |
| `OFFSET..FETCH` | `OFFSET..FETCH` | **동일** ✔ |
| `HASHBYTES('SHA2_256', s)` | `digest(s, 'sha256')` | pgcrypto 확장 필요 |
| `NEWID()` | `gen_random_uuid()` | |
| `DATEADD(DAY,-7,x)` | `x - INTERVAL '7 days'` | |
| `CAST(x AS DATE)` | `x::date` 또는 `CAST(x AS DATE)` | |
| `MERGE` | `INSERT .. ON CONFLICT DO UPDATE` | 집계 프로시저에서만 사용 |
| `dbo.` 스키마 | `public.` (또는 생략) | |

### 이미 지켜둔 이식성 규칙
- 식별자 전부 **소문자 snake_case** (PG의 대소문자 폴딩 대응)
- PG 예약어 회피 — `user`→`login_id`, `role`→`job_role`, `group`→`group_no`, `order`→`sort_no`
- 트리거 0개, 프로시저 2개(집계 전용) — 재작성 비용 최소
- 비즈니스 로직은 전부 애플리케이션 계층

---

## 9. 인덱스 전략

| 인덱스 | 대상 쿼리 |
|---|---|
| `ix_article_list (board_id, is_del, is_notice DESC, group_no DESC, group_order ASC)` | **게시판 목록** — 가장 빈번 |
| `ix_article_regdt (board_id, reg_dt DESC)` | 메인 최근글 위젯 |
| `ix_article_cate (board_id, category_id)` | 분류 필터 |
| `ix_comment_article (article_id, is_del, comment_id)` | 상세 페이지 댓글 |
| `ix_file_article (article_id, sort_no)` | 상세 페이지 첨부 |
| `uq_member_loginid (login_id)` | 로그인 |
| `ix_visitlog_date (visit_date, ip)` | 일별 집계 (`COUNT DISTINCT ip`) |

---

## 10. 데이터 정리 정책

| 대상 | 정책 | 수단 |
|---|---|---|
| 게시글/댓글 삭제 | **논리 삭제** (`is_del = 1`) — 복구 가능 | 앱 |
| 회원 탈퇴 | 논리 삭제 (`is_del = 1`), 작성글은 유지 | 앱 |
| 첨부파일 | 게시글 물리삭제 시 `ON DELETE CASCADE` + 물리파일 삭제 | 관리자 기능 |
| `tb_visit_log` | 90일 경과분 삭제 (집계 후) | `usp_visit_log_purge` |
| `tb_login_log` | 90일 경과분 삭제 | `usp_visit_log_purge` |

---

## 11. 실행 순서

```powershell
Start-Service MSSQLSERVER                                  # 관리자 권한

sqlcmd -S localhost -E -i D:\jkw.com\db\mssql\01_schema.sql
sqlcmd -S localhost -E -i D:\jkw.com\db\mssql\02_seed.sql
sqlcmd -S localhost -E -i D:\jkw.com\db\mssql\03_proc.sql
```

기본 계정
| 구분 | 아이디 | 비밀번호 |
|---|---|---|
| 최고관리자 | `admin` | `admin1234!` |
| 일반회원 | `test` | `test1234!` |

> ⚠️ 운영 전 반드시 변경하세요. 또한 ASP 전용 SQL 로그인 계정(`jkwcom_app`)을 별도로 만들고
> `db_datareader` + `db_datawriter` 만 부여하는 것을 권장합니다 (`sa` 사용 금지).
