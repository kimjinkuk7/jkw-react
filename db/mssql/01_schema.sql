/* ============================================================================
   jkw.com 개인 홈페이지 - MS SQL Server 스키마
   ----------------------------------------------------------------------------
   Target   : SQL Server 2019 (15.0) 이상
   Charset  : 전 컬럼 NVARCHAR (UTF-16) / 애플리케이션은 UTF-8(CodePage 65001)
   Naming   : 소문자 snake_case  (PostgreSQL 이식성 확보)
   Portable : GETDATE() 대신 CURRENT_TIMESTAMP, ISNULL 대신 COALESCE
              예약어(user/role/order/group) 단독 사용 금지
   ----------------------------------------------------------------------------
   실행 : sqlcmd -S localhost -E -i 01_schema.sql
   ============================================================================ */

SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------------
   0. 데이터베이스
   --------------------------------------------------------------------------- */
IF DB_ID('jkwcom') IS NULL
BEGIN
    CREATE DATABASE jkwcom COLLATE Korean_Wansung_CI_AS;
END
GO

USE jkwcom;
GO

/* ---------------------------------------------------------------------------
   0-1. 기존 객체 제거 (역순 - FK 의존성 고려)
   --------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.tb_phone_auth',      'U') IS NOT NULL DROP TABLE dbo.tb_phone_auth;
IF OBJECT_ID('dbo.tb_payment_log',     'U') IS NOT NULL DROP TABLE dbo.tb_payment_log;
IF OBJECT_ID('dbo.tb_donation',        'U') IS NOT NULL DROP TABLE dbo.tb_donation;
IF OBJECT_ID('dbo.tb_member_social',   'U') IS NOT NULL DROP TABLE dbo.tb_member_social;
IF OBJECT_ID('dbo.tb_visit_stat',      'U') IS NOT NULL DROP TABLE dbo.tb_visit_stat;
IF OBJECT_ID('dbo.tb_visit_log',       'U') IS NOT NULL DROP TABLE dbo.tb_visit_log;
IF OBJECT_ID('dbo.tb_login_log',       'U') IS NOT NULL DROP TABLE dbo.tb_login_log;
IF OBJECT_ID('dbo.tb_contact',         'U') IS NOT NULL DROP TABLE dbo.tb_contact;
IF OBJECT_ID('dbo.tb_career',          'U') IS NOT NULL DROP TABLE dbo.tb_career;
IF OBJECT_ID('dbo.tb_portfolio_skill', 'U') IS NOT NULL DROP TABLE dbo.tb_portfolio_skill;
IF OBJECT_ID('dbo.tb_skill',           'U') IS NOT NULL DROP TABLE dbo.tb_skill;
IF OBJECT_ID('dbo.tb_portfolio',       'U') IS NOT NULL DROP TABLE dbo.tb_portfolio;
IF OBJECT_ID('dbo.tb_board_file',      'U') IS NOT NULL DROP TABLE dbo.tb_board_file;
IF OBJECT_ID('dbo.tb_board_comment',   'U') IS NOT NULL DROP TABLE dbo.tb_board_comment;
IF OBJECT_ID('dbo.tb_board_article',   'U') IS NOT NULL DROP TABLE dbo.tb_board_article;
IF OBJECT_ID('dbo.tb_board_category',  'U') IS NOT NULL DROP TABLE dbo.tb_board_category;
IF OBJECT_ID('dbo.tb_board_master',    'U') IS NOT NULL DROP TABLE dbo.tb_board_master;
IF OBJECT_ID('dbo.tb_menu',            'U') IS NOT NULL DROP TABLE dbo.tb_menu;
IF OBJECT_ID('dbo.tb_member',          'U') IS NOT NULL DROP TABLE dbo.tb_member;
IF OBJECT_ID('dbo.tb_config',          'U') IS NOT NULL DROP TABLE dbo.tb_config;
GO


/* ============================================================================
   1. tb_config  -  사이트 전역 설정 (key/value)
   ============================================================================ */
CREATE TABLE dbo.tb_config
(
    config_key      VARCHAR(50)     NOT NULL,
    config_value    NVARCHAR(MAX)   NULL,
    config_group    VARCHAR(30)     NOT NULL DEFAULT 'site',   -- site / seo / mail / upload
    config_desc     NVARCHAR(200)   NULL,
    upd_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_config PRIMARY KEY (config_key)
);
GO


/* ============================================================================
   2. tb_member  -  회원
   ----------------------------------------------------------------------------
   member_level : 0=정지  1=비회원(미사용)  3=일반회원  5=운영자  9=최고관리자
   user_pw      : LOWER(HEX(SHA2_256(user_salt || 평문비밀번호)))  = 64자
                  ※ 비밀번호는 ASCII 문자만 허용 (PostgreSQL/Java/PHP 해시 호환)
   ============================================================================ */
CREATE TABLE dbo.tb_member
(
    member_id       INT             NOT NULL IDENTITY(1,1),
    login_id        VARCHAR(30)     NOT NULL,               -- 로그인 아이디
    user_pw         CHAR(64)        NOT NULL,               -- SHA2_256 hex
    user_salt       CHAR(32)        NOT NULL,               -- 회원별 salt
    user_name       NVARCHAR(50)    NOT NULL,
    nickname        NVARCHAR(50)    NOT NULL,
    email           VARCHAR(100)    NOT NULL,
    mobile          VARCHAR(20)     NULL,
    -- 휴대폰 인증 기록. 어떤 방식으로 인증했는지 반드시 남긴다.
    -- mock = 시연용(실제 인증 아님) / firebase / sms  → App.Conf.asp 의 PHONE_AUTH_MODE
    mobile_verified_dt   DATETIME2(0)  NULL,
    mobile_verify_type   VARCHAR(10)   NULL,
    homepage        VARCHAR(200)    NULL,
    profile_img     VARCHAR(200)    NULL,
    intro           NVARCHAR(500)   NULL,
    -- 0 = 비밀번호로 로그인할 수 없는 계정 (소셜 전용). 소셜 가입 회원은 임의 비밀번호를
    --     갖게 되므로, 비밀번호 확인을 요구하는 화면(비밀번호 변경·탈퇴)에서 구분해야 한다.
    pw_login_use    BIT             NOT NULL DEFAULT 1,
    member_level    TINYINT         NOT NULL DEFAULT 3,
    is_email_recv   BIT             NOT NULL DEFAULT 0,     -- 메일 수신 동의
    login_count     INT             NOT NULL DEFAULT 0,
    last_login_dt   DATETIME2(0)    NULL,
    last_login_ip   VARCHAR(45)     NULL,
    pw_fail_count   TINYINT         NOT NULL DEFAULT 0,     -- 로그인 5회 실패 시 잠금
    lock_until_dt   DATETIME2(0)    NULL,
    is_use          BIT             NOT NULL DEFAULT 1,
    is_del          BIT             NOT NULL DEFAULT 0,
    reg_ip          VARCHAR(45)     NULL,
    reg_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    upd_dt          DATETIME2(0)    NULL,
    CONSTRAINT pk_member         PRIMARY KEY (member_id),
    CONSTRAINT uq_member_loginid UNIQUE (login_id),
    CONSTRAINT ck_member_level   CHECK (member_level IN (0,1,3,5,9))
);
GO
CREATE INDEX ix_member_email  ON dbo.tb_member (email);
CREATE INDEX ix_member_regdt  ON dbo.tb_member (reg_dt DESC);
GO


/* ============================================================================
   3. tb_menu  -  사이트 메뉴 (GNB 자동 생성 / 2 depth)
   ============================================================================ */
CREATE TABLE dbo.tb_menu
(
    menu_id         INT             NOT NULL IDENTITY(1,1),
    parent_id       INT             NULL,
    menu_code       VARCHAR(30)     NOT NULL,               -- 현재메뉴 하이라이트 키
    menu_name       NVARCHAR(50)    NOT NULL,
    menu_url        VARCHAR(200)    NULL,
    menu_target     VARCHAR(10)     NOT NULL DEFAULT '_self',
    menu_depth      TINYINT         NOT NULL DEFAULT 1,
    sort_no         INT             NOT NULL DEFAULT 0,
    auth_level      TINYINT         NOT NULL DEFAULT 0,     -- 노출 최소 권한 (0=전체)
    is_use          BIT             NOT NULL DEFAULT 1,
    reg_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_menu        PRIMARY KEY (menu_id),
    CONSTRAINT uq_menu_code   UNIQUE (menu_code),
    CONSTRAINT fk_menu_parent FOREIGN KEY (parent_id) REFERENCES dbo.tb_menu (menu_id)
);
GO
CREATE INDEX ix_menu_sort ON dbo.tb_menu (menu_depth, sort_no);
GO


/* ============================================================================
   4. tb_board_master  -  ★ 게시판 정의 (행 1개 = 게시판 1개)
   ----------------------------------------------------------------------------
   이 테이블 덕분에 공지/자유/자료실/갤러리/블로그/방명록이
   동일한 코드(/board/List.asp 등)로 동작한다.
   skin_type 으로 화면만 바꾸고, auth_* 로 게시판별 권한을 따로 준다.
   ============================================================================ */
CREATE TABLE dbo.tb_board_master
(
    board_id        VARCHAR(20)     NOT NULL,               -- notice / free / data / gallery / blog / guest
    board_name      NVARCHAR(50)    NOT NULL,
    board_desc      NVARCHAR(300)   NULL,
    skin_type       VARCHAR(20)     NOT NULL DEFAULT 'list',-- list / gallery / blog / guest
    list_count      INT             NOT NULL DEFAULT 15,    -- 페이지당 글 수
    page_block      INT             NOT NULL DEFAULT 10,    -- 페이지번호 블록 크기
    gallery_col     TINYINT         NOT NULL DEFAULT 3,     -- 갤러리 스킨 컬럼 수(데스크톱)

    use_comment     BIT             NOT NULL DEFAULT 1,
    use_file        BIT             NOT NULL DEFAULT 0,
    use_category    BIT             NOT NULL DEFAULT 0,
    use_secret      BIT             NOT NULL DEFAULT 0,     -- 비밀글
    use_reply       BIT             NOT NULL DEFAULT 0,     -- 답변형(계층) 사용
    use_editor      BIT             NOT NULL DEFAULT 1,     -- HTML 에디터
    use_notice      BIT             NOT NULL DEFAULT 1,     -- 공지 상단고정

    file_max_count  TINYINT         NOT NULL DEFAULT 3,
    file_max_size   INT             NOT NULL DEFAULT 10240, -- KB
    file_ext_allow  VARCHAR(300)    NOT NULL DEFAULT 'jpg,jpeg,gif,png,webp,pdf,zip,hwp,doc,docx,xls,xlsx,ppt,pptx,txt',

    auth_list       TINYINT         NOT NULL DEFAULT 0,     -- 목록 열람 최소 권한
    auth_read       TINYINT         NOT NULL DEFAULT 0,     -- 본문 열람
    auth_write      TINYINT         NOT NULL DEFAULT 3,     -- 글쓰기
    auth_comment    TINYINT         NOT NULL DEFAULT 3,     -- 댓글
    auth_admin      TINYINT         NOT NULL DEFAULT 9,     -- 게시판 관리

    sort_no         INT             NOT NULL DEFAULT 0,
    is_use          BIT             NOT NULL DEFAULT 1,
    reg_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    upd_dt          DATETIME2(0)    NULL,
    CONSTRAINT pk_board_master PRIMARY KEY (board_id),
    CONSTRAINT ck_board_skin   CHECK (skin_type IN ('list','gallery','blog','guest'))
);
GO


/* ============================================================================
   5. tb_board_category  -  게시판별 분류
   ============================================================================ */
CREATE TABLE dbo.tb_board_category
(
    category_id     INT             NOT NULL IDENTITY(1,1),
    board_id        VARCHAR(20)     NOT NULL,
    category_name   NVARCHAR(50)    NOT NULL,
    sort_no         INT             NOT NULL DEFAULT 0,
    is_use          BIT             NOT NULL DEFAULT 1,
    CONSTRAINT pk_board_category PRIMARY KEY (category_id),
    CONSTRAINT fk_category_board FOREIGN KEY (board_id)
        REFERENCES dbo.tb_board_master (board_id) ON DELETE CASCADE
);
GO
CREATE INDEX ix_category_board ON dbo.tb_board_category (board_id, sort_no);
GO


/* ============================================================================
   6. tb_board_article  -  게시글 (모든 게시판 공용)
   ----------------------------------------------------------------------------
   답변형 정렬 : ORDER BY is_notice DESC, group_no DESC, group_order ASC
   ============================================================================ */
CREATE TABLE dbo.tb_board_article
(
    article_id      BIGINT          NOT NULL IDENTITY(1,1),
    board_id        VARCHAR(20)     NOT NULL,
    category_id     INT             NULL,

    group_no        BIGINT          NOT NULL DEFAULT 0,     -- 원글의 article_id
    group_order     INT             NOT NULL DEFAULT 0,     -- 그룹 내 정렬순서
    group_depth     INT             NOT NULL DEFAULT 0,     -- 답변 들여쓰기 단계
    parent_id       BIGINT          NULL,                   -- 바로 위 글

    title           NVARCHAR(200)   NOT NULL,
    content         NVARCHAR(MAX)   NULL,
    content_type    VARCHAR(10)     NOT NULL DEFAULT 'html',-- html / text

    writer_id       INT             NULL,                   -- 회원글이면 member_id
    writer_name     NVARCHAR(50)    NOT NULL,
    writer_pw       CHAR(64)        NULL,                   -- 비회원 글 수정/삭제용 해시
    writer_email    VARCHAR(100)    NULL,
    writer_ip       VARCHAR(45)     NULL,

    thumb_file      VARCHAR(300)    NULL,                   -- 갤러리/블로그 대표 이미지
    tags            NVARCHAR(300)   NULL,                   -- 콤마 구분
    link_url        VARCHAR(300)    NULL,

    hit_count       INT             NOT NULL DEFAULT 0,
    comment_count   INT             NOT NULL DEFAULT 0,
    file_count      TINYINT         NOT NULL DEFAULT 0,
    like_count      INT             NOT NULL DEFAULT 0,

    is_notice       BIT             NOT NULL DEFAULT 0,
    is_secret       BIT             NOT NULL DEFAULT 0,
    is_del          BIT             NOT NULL DEFAULT 0,     -- 논리삭제

    reg_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    upd_dt          DATETIME2(0)    NULL,

    CONSTRAINT pk_board_article    PRIMARY KEY (article_id),
    CONSTRAINT fk_article_board    FOREIGN KEY (board_id)    REFERENCES dbo.tb_board_master (board_id),
    CONSTRAINT fk_article_category FOREIGN KEY (category_id) REFERENCES dbo.tb_board_category (category_id),
    CONSTRAINT fk_article_member   FOREIGN KEY (writer_id)   REFERENCES dbo.tb_member (member_id)
);
GO
-- 목록 조회용 커버링 인덱스 (가장 많이 타는 쿼리)
CREATE INDEX ix_article_list   ON dbo.tb_board_article (board_id, is_del, is_notice DESC, group_no DESC, group_order ASC);
CREATE INDEX ix_article_regdt  ON dbo.tb_board_article (board_id, reg_dt DESC);
CREATE INDEX ix_article_writer ON dbo.tb_board_article (writer_id);
CREATE INDEX ix_article_cate   ON dbo.tb_board_article (board_id, category_id);
GO


/* ============================================================================
   7. tb_board_comment  -  댓글 (1단계 대댓글 지원)
   ============================================================================ */
CREATE TABLE dbo.tb_board_comment
(
    comment_id      BIGINT          NOT NULL IDENTITY(1,1),
    article_id      BIGINT          NOT NULL,
    board_id        VARCHAR(20)     NOT NULL,
    parent_id       BIGINT          NULL,                   -- 대댓글 대상 comment_id
    comment_depth   TINYINT         NOT NULL DEFAULT 0,

    content         NVARCHAR(1000)  NOT NULL,
    writer_id       INT             NULL,
    writer_name     NVARCHAR(50)    NOT NULL,
    writer_pw       CHAR(64)        NULL,
    writer_ip       VARCHAR(45)     NULL,

    is_secret       BIT             NOT NULL DEFAULT 0,
    is_del          BIT             NOT NULL DEFAULT 0,
    reg_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    upd_dt          DATETIME2(0)    NULL,

    CONSTRAINT pk_board_comment  PRIMARY KEY (comment_id),
    CONSTRAINT fk_comment_article FOREIGN KEY (article_id)
        REFERENCES dbo.tb_board_article (article_id) ON DELETE CASCADE
);
GO
CREATE INDEX ix_comment_article ON dbo.tb_board_comment (article_id, is_del, comment_id ASC);
GO


/* ============================================================================
   8. tb_board_file  -  첨부파일
   ----------------------------------------------------------------------------
   물리 파일명(save_name)은 GUID 로 저장하여 원본명 노출/덮어쓰기 방지.
   다운로드는 반드시 /board/download.asp?fid= 경유 (직접 접근 차단).
   ============================================================================ */
CREATE TABLE dbo.tb_board_file
(
    file_id         BIGINT          NOT NULL IDENTITY(1,1),
    article_id      BIGINT          NOT NULL,
    board_id        VARCHAR(20)     NOT NULL,
    org_name        NVARCHAR(255)   NOT NULL,               -- 사용자에게 보이는 원본 파일명
    save_name       VARCHAR(60)     NOT NULL,               -- 실제 저장 파일명 (GUID.ext)
    save_path       VARCHAR(200)    NOT NULL,               -- /upload/board/202608
    file_size       INT             NOT NULL DEFAULT 0,     -- byte
    file_ext        VARCHAR(10)     NULL,
    is_image        BIT             NOT NULL DEFAULT 0,
    sort_no         TINYINT         NOT NULL DEFAULT 0,
    down_count      INT             NOT NULL DEFAULT 0,
    reg_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_board_file   PRIMARY KEY (file_id),
    CONSTRAINT fk_file_article FOREIGN KEY (article_id)
        REFERENCES dbo.tb_board_article (article_id) ON DELETE CASCADE
);
GO
CREATE INDEX ix_file_article ON dbo.tb_board_file (article_id, sort_no);
GO


/* ============================================================================
   9. tb_portfolio  -  포트폴리오 / 프로젝트
   ============================================================================ */
CREATE TABLE dbo.tb_portfolio
(
    portfolio_id    INT             NOT NULL IDENTITY(1,1),
    title           NVARCHAR(200)   NOT NULL,
    subtitle        NVARCHAR(200)   NULL,
    summary         NVARCHAR(500)   NULL,                   -- 목록 노출 요약
    content         NVARCHAR(MAX)   NULL,                   -- 상세 케이스 스터디(HTML)
    category        NVARCHAR(50)    NULL,                   -- Web / Mobile / Solution / Etc
    client_name     NVARCHAR(100)   NULL,
    job_role        NVARCHAR(200)   NULL,                   -- 담당 역할 ("role"은 PG 예약어)
    team_size       NVARCHAR(50)    NULL,
    period_start    DATE            NULL,
    period_end      DATE            NULL,
    is_ongoing      BIT             NOT NULL DEFAULT 0,
    site_url        VARCHAR(300)    NULL,
    repo_url        VARCHAR(300)    NULL,
    thumb_file      VARCHAR(300)    NULL,
    is_main         BIT             NOT NULL DEFAULT 0,     -- 메인 화면 노출
    sort_no         INT             NOT NULL DEFAULT 0,
    hit_count       INT             NOT NULL DEFAULT 0,
    is_use          BIT             NOT NULL DEFAULT 1,
    reg_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    upd_dt          DATETIME2(0)    NULL,
    CONSTRAINT pk_portfolio PRIMARY KEY (portfolio_id)
);
GO
CREATE INDEX ix_portfolio_sort ON dbo.tb_portfolio (is_use, sort_no, portfolio_id DESC);
GO


/* ============================================================================
   10. tb_skill  -  기술 스택
   ============================================================================ */
CREATE TABLE dbo.tb_skill
(
    skill_id        INT             NOT NULL IDENTITY(1,1),
    skill_group     NVARCHAR(50)    NOT NULL,               -- Language / Framework / Database / DevOps / Tool
    skill_name      NVARCHAR(50)    NOT NULL,
    level_pct       TINYINT         NOT NULL DEFAULT 50,    -- 0~100 (막대그래프)
    experience_yr   DECIMAL(3,1)    NULL,
    skill_desc      NVARCHAR(300)   NULL,
    color_hex       VARCHAR(7)      NULL,                   -- #4F46E5
    sort_no         INT             NOT NULL DEFAULT 0,
    is_use          BIT             NOT NULL DEFAULT 1,
    CONSTRAINT pk_skill PRIMARY KEY (skill_id),
    CONSTRAINT ck_skill_pct CHECK (level_pct BETWEEN 0 AND 100)
);
GO
CREATE INDEX ix_skill_sort ON dbo.tb_skill (skill_group, sort_no);
GO


/* ============================================================================
   11. tb_portfolio_skill  -  포트폴리오 ↔ 기술스택 (N:M)
   ============================================================================ */
CREATE TABLE dbo.tb_portfolio_skill
(
    portfolio_id    INT             NOT NULL,
    skill_id        INT             NOT NULL,
    sort_no         TINYINT         NOT NULL DEFAULT 0,
    CONSTRAINT pk_portfolio_skill PRIMARY KEY (portfolio_id, skill_id),
    CONSTRAINT fk_ps_portfolio FOREIGN KEY (portfolio_id)
        REFERENCES dbo.tb_portfolio (portfolio_id) ON DELETE CASCADE,
    CONSTRAINT fk_ps_skill     FOREIGN KEY (skill_id)
        REFERENCES dbo.tb_skill (skill_id) ON DELETE CASCADE
);
GO


/* ============================================================================
   12. tb_career  -  경력 / 학력 / 수상 / 자격증  (About 페이지 타임라인)
   ============================================================================ */
CREATE TABLE dbo.tb_career
(
    career_id       INT             NOT NULL IDENTITY(1,1),
    career_type     VARCHAR(20)     NOT NULL,               -- work / edu / award / cert / activity
    title           NVARCHAR(200)   NOT NULL,               -- 회사명 / 학교명 / 수상명
    position        NVARCHAR(100)   NULL,                   -- 직위 / 전공
    org_url         VARCHAR(300)    NULL,
    description     NVARCHAR(2000)  NULL,                   -- 주요 업무 (줄바꿈 구분)
    date_start      DATE            NULL,
    date_end        DATE            NULL,
    is_current      BIT             NOT NULL DEFAULT 0,     -- 재직중
    sort_no         INT             NOT NULL DEFAULT 0,
    is_use          BIT             NOT NULL DEFAULT 1,
    CONSTRAINT pk_career PRIMARY KEY (career_id),
    CONSTRAINT ck_career_type CHECK (career_type IN ('work','edu','award','cert','activity'))
);
GO
CREATE INDEX ix_career_type ON dbo.tb_career (career_type, date_start DESC);
GO


/* ============================================================================
   13. tb_contact  -  문의하기
   ============================================================================ */
CREATE TABLE dbo.tb_contact
(
    contact_id      INT             NOT NULL IDENTITY(1,1),
    contact_type    NVARCHAR(30)    NULL,                   -- 프로젝트문의 / 채용 / 기타
    writer_name     NVARCHAR(50)    NOT NULL,
    company         NVARCHAR(100)   NULL,
    email           VARCHAR(100)    NOT NULL,
    mobile          VARCHAR(20)     NULL,
    subject         NVARCHAR(200)   NOT NULL,
    content         NVARCHAR(MAX)   NOT NULL,
    is_agree        BIT             NOT NULL DEFAULT 0,     -- 개인정보 수집 동의
    is_read         BIT             NOT NULL DEFAULT 0,
    is_reply        BIT             NOT NULL DEFAULT 0,
    reply_content   NVARCHAR(MAX)   NULL,
    reply_dt        DATETIME2(0)    NULL,
    writer_ip       VARCHAR(45)     NULL,
    reg_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_contact PRIMARY KEY (contact_id)
);
GO
CREATE INDEX ix_contact_regdt ON dbo.tb_contact (is_read, reg_dt DESC);
GO


/* ============================================================================
   14. tb_login_log  -  로그인 이력 (보안 감사)
   ============================================================================ */
CREATE TABLE dbo.tb_login_log
(
    log_id          BIGINT          NOT NULL IDENTITY(1,1),
    login_id        VARCHAR(30)     NULL,
    member_id       INT             NULL,
    is_success      BIT             NOT NULL DEFAULT 0,
    fail_reason     NVARCHAR(100)   NULL,
    ip              VARCHAR(45)     NULL,
    user_agent      VARCHAR(400)    NULL,
    reg_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_login_log PRIMARY KEY (log_id)
);
GO
CREATE INDEX ix_loginlog_dt ON dbo.tb_login_log (reg_dt DESC);
GO


/* ============================================================================
   15. tb_visit_log  -  방문 로그 (raw)
   ============================================================================ */
CREATE TABLE dbo.tb_visit_log
(
    log_id          BIGINT          NOT NULL IDENTITY(1,1),
    visit_date      DATE            NOT NULL,
    ip              VARCHAR(45)     NULL,
    member_id       INT             NULL,
    page_url        VARCHAR(300)    NULL,
    referer         VARCHAR(500)    NULL,
    user_agent      VARCHAR(400)    NULL,
    device_type     VARCHAR(10)     NULL,                   -- pc / mobile / tablet
    reg_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_visit_log PRIMARY KEY (log_id)
);
GO
CREATE INDEX ix_visitlog_date ON dbo.tb_visit_log (visit_date, ip);
GO


/* ============================================================================
   16. tb_visit_stat  -  일별 집계 (대시보드용, 03_proc.sql 이 채움)
   ============================================================================ */
CREATE TABLE dbo.tb_visit_stat
(
    visit_date      DATE            NOT NULL,
    total_cnt       INT             NOT NULL DEFAULT 0,     -- 페이지뷰
    unique_cnt      INT             NOT NULL DEFAULT 0,     -- 순 방문자(IP 기준)
    pc_cnt          INT             NOT NULL DEFAULT 0,
    mobile_cnt      INT             NOT NULL DEFAULT 0,
    upd_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_visit_stat PRIMARY KEY (visit_date)
);
GO


/* ============================================================================
   17. tb_member_social  -  소셜 로그인 연동 (구글 / 네이버 / 카카오)
   ----------------------------------------------------------------------------
   한 회원이 여러 제공자를 붙일 수 있다 (1:N).
   provider + provider_uid 가 유일 키다. 제공자가 주는 식별자를 그대로 신뢰하되
   이메일은 바뀔 수 있으므로 식별자로 쓰지 않는다.
   ============================================================================ */
CREATE TABLE dbo.tb_member_social
(
    social_id       INT             NOT NULL IDENTITY(1,1),
    member_id       INT             NOT NULL,
    provider        VARCHAR(20)     NOT NULL,               -- google / naver / kakao / mock
    provider_uid    VARCHAR(100)    NOT NULL,               -- 제공자 고유 식별자
    provider_email  VARCHAR(100)    NULL,
    provider_name   NVARCHAR(50)    NULL,
    reg_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login_dt   DATETIME2(0)    NULL,

    CONSTRAINT pk_member_social PRIMARY KEY (social_id),
    CONSTRAINT uq_member_social UNIQUE (provider, provider_uid),
    CONSTRAINT fk_member_social_member FOREIGN KEY (member_id)
        REFERENCES dbo.tb_member (member_id) ON DELETE CASCADE
);
GO
CREATE INDEX ix_member_social_member ON dbo.tb_member_social (member_id);
GO


/* ============================================================================
   18. tb_donation  -  개발자 지원금 (후원)
   ----------------------------------------------------------------------------
   is_test = 1 이면 테스트 결제다. 운영 결제와 반드시 구분해서 보관한다.
   order_id 는 우리가 만드는 주문번호이고 pg_tid 는 PG 가 주는 거래키다.
   ============================================================================ */
CREATE TABLE dbo.tb_donation
(
    donation_id     INT             NOT NULL IDENTITY(1,1),
    order_id        VARCHAR(64)     NOT NULL,               -- 우리 주문번호
    member_id       INT             NULL,                   -- 비회원 후원 허용
    donor_name      NVARCHAR(30)    NOT NULL,
    message         NVARCHAR(200)   NULL,
    amount          INT             NOT NULL,
    pg_provider     VARCHAR(20)     NOT NULL,               -- mock / toss / inicis / nicepay
    pay_method      NVARCHAR(30)    NULL,
    pay_status      VARCHAR(20)     NOT NULL DEFAULT 'ready', -- ready / paid / failed / canceled
    pg_tid          VARCHAR(100)    NULL,                   -- PG 거래키
    fail_reason     NVARCHAR(200)   NULL,
    is_test         BIT             NOT NULL DEFAULT 1,
    is_public       BIT             NOT NULL DEFAULT 1,     -- 후원자 목록 노출
    paid_dt         DATETIME2(0)    NULL,
    reg_ip          VARCHAR(45)     NULL,
    reg_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_donation PRIMARY KEY (donation_id),
    CONSTRAINT uq_donation_order UNIQUE (order_id)
);
GO
CREATE INDEX ix_donation_status ON dbo.tb_donation (pay_status, donation_id DESC);
GO


/* ============================================================================
   19. tb_payment_log  -  PG 통신 원문 보관
   ----------------------------------------------------------------------------
   결제 분쟁·디버깅에 원문이 반드시 필요하다. 요청과 응답을 그대로 남긴다.
   ※ 카드번호 같은 민감정보는 우리 서버를 지나가지 않는다(PG 창에서 직접 입력).
   ============================================================================ */
CREATE TABLE dbo.tb_payment_log
(
    log_id          BIGINT          NOT NULL IDENTITY(1,1),
    order_id        VARCHAR(64)     NULL,
    pg_provider     VARCHAR(20)     NULL,
    step            VARCHAR(30)     NOT NULL,               -- request / approve / result / error
    http_status     INT             NULL,
    req_body        NVARCHAR(MAX)   NULL,
    res_body        NVARCHAR(MAX)   NULL,
    reg_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_payment_log PRIMARY KEY (log_id)
);
GO
CREATE INDEX ix_payment_log_order ON dbo.tb_payment_log (order_id, log_id);
GO


/* ============================================================================
   20. tb_phone_auth  -  휴대폰 인증번호
   ----------------------------------------------------------------------------
   실제 SMS 인증과 구조가 같다. 인증번호를 서버가 만들어 DB 에 넣고,
   사용자가 입력한 값과 대조한다. 만료시각·시도횟수를 함께 두는 이유는
   무한 대입과 무한 재발송을 막기 위한 것이다.
   auth_mode = mock 이면 시연용이며 실제 문자를 보내지 않는다.
   ============================================================================ */
CREATE TABLE dbo.tb_phone_auth
(
    auth_id         INT             NOT NULL IDENTITY(1,1),
    mobile          VARCHAR(20)     NOT NULL,               -- 숫자만
    auth_code       VARCHAR(10)     NOT NULL,               -- 인증번호
    auth_mode       VARCHAR(10)     NOT NULL,               -- mock / firebase / sms
    expire_dt       DATETIME2(0)    NOT NULL,
    try_count       TINYINT         NOT NULL DEFAULT 0,
    verified_dt     DATETIME2(0)    NULL,
    reg_ip          VARCHAR(45)     NULL,
    reg_dt          DATETIME2(0)    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_phone_auth PRIMARY KEY (auth_id)
);
GO
CREATE INDEX ix_phone_auth_mobile ON dbo.tb_phone_auth (mobile, auth_id DESC);
GO


PRINT '=== jkwcom 스키마 생성 완료 (20 tables) ===';
GO
