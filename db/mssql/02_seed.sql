/* ============================================================================
   jkw.com 개인 홈페이지 - 초기 데이터 (MS SQL Server)
   ----------------------------------------------------------------------------
   실행 : sqlcmd -S localhost -E -i 02_seed.sql
   ※ 01_schema.sql 실행 후에 실행할 것
   ----------------------------------------------------------------------------
   기본 관리자 계정 :  admin / admin1234!
   ★ 최초 로그인 후 반드시 비밀번호를 변경하세요.
   ============================================================================ */

SET NOCOUNT ON;
GO
USE jkwcom;
GO

/* 재실행 가능하도록 데이터 초기화 (개발 중에만 사용) */
DELETE FROM dbo.tb_visit_stat;
DELETE FROM dbo.tb_visit_log;
DELETE FROM dbo.tb_login_log;
DELETE FROM dbo.tb_contact;
DELETE FROM dbo.tb_portfolio_skill;
DELETE FROM dbo.tb_career;
DELETE FROM dbo.tb_skill;
DELETE FROM dbo.tb_portfolio;
DELETE FROM dbo.tb_board_file;
DELETE FROM dbo.tb_board_comment;
DELETE FROM dbo.tb_board_article;
DELETE FROM dbo.tb_board_category;
DELETE FROM dbo.tb_board_master;
DELETE FROM dbo.tb_menu;
DELETE FROM dbo.tb_member;
DELETE FROM dbo.tb_config;
GO

/* ----------------------------------------------------------------------------
   IDENTITY 초기화 - 첫 행의 id 가 반드시 1 이 되게 한다.

   DBCC CHECKIDENT 의 RESEED 는 테이블 상태에 따라 의미가 다르다.
     · 한 번도 INSERT 되지 않은 테이블  → 다음 행의 id = 지정값
     · INSERT 이력이 있는 테이블        → 다음 행의 id = 지정값 + 증가값(1)
   01_schema.sql 이 테이블을 새로 만든 직후라면 앞쪽 경우다. 여기에 RESEED 0 을
   주면 첫 글의 id 가 0 이 되고, id <= 0 을 잘못된 요청으로 보는 코드
   (code/board/View.Code.asp 등)에서 그 글을 영원히 열 수 없게 된다.
   그래서 last_value(INSERT 이력) 로 구분해 지정값을 달리 준다.
   sys.identity_columns 를 훑으므로 테이블이 늘어나도 손댈 필요가 없다.
   ---------------------------------------------------------------------------- */
DECLARE @reseed NVARCHAR(MAX) = N'';

SELECT @reseed = @reseed
     + N'DBCC CHECKIDENT (''' + SCHEMA_NAME(t.schema_id) + N'.' + t.name + N''', RESEED, '
     + CASE WHEN ic.last_value IS NULL THEN N'1' ELSE N'0' END
     + N') WITH NO_INFOMSGS;' + CHAR(13) + CHAR(10)
FROM sys.identity_columns ic
JOIN sys.tables t ON t.object_id = ic.object_id
WHERE t.is_ms_shipped = 0;

EXEC sp_executesql @reseed;
GO


/* ============================================================================
   1. 사이트 설정
   ============================================================================ */
INSERT INTO dbo.tb_config (config_key, config_value, config_group, config_desc) VALUES
 ('site_title',      N'JKW.com',                                       'site',   N'사이트 제목'),
 ('site_subtitle',   N'김진국 · Backend Developer',                     'site',   N'사이트 부제'),
 ('site_desc',       N'백엔드 개발자 김진국의 개인 홈페이지입니다.',        'seo',    N'메타 description'),
 ('site_keywords',   N'개발자,포트폴리오,백엔드,ASP,SpringBoot,Python,PHP','seo',   N'메타 keywords'),
 ('site_url',        'http://localhost',                               'site',   N'사이트 기본 URL'),
 ('owner_name',      N'김진국',                                        'site',   N'운영자 이름'),
 ('owner_email',     'kimjinkuk7@nablecomm.com',                       'site',   N'대표 이메일'),
 ('owner_github',    'https://github.com/',                            'site',   N'GitHub 주소'),
 ('hero_headline',   N'문제를 구조로 푸는 백엔드 개발자',                  'site',   N'메인 히어로 한 줄'),
 ('hero_sub',        N'같은 서비스를 ASP · Spring Boot · Python · PHP 네 갈래로 구현하며 언어의 결을 비교합니다.', 'site', N'메인 히어로 설명'),
 ('copyright',       N'© 2026 JKW.com. All rights reserved.',           'site',   N'하단 저작권'),
 ('upload_root',     '/upload',                                        'upload', N'업로드 루트 경로'),
 ('asset_ver',       '20260820',                                       'site',   N'CSS/JS 캐시 무효화 키 (수정 후 값을 올린다)'),
 ('mail_use',        '0',                                              'mail',   N'문의 메일발송 사용(0/1)'),
 ('mail_smtp',       'smtp.gmail.com',                                 'mail',   N'SMTP 서버'),
 ('mail_port',       '587',                                            'mail',   N'SMTP 포트'),
 ('mail_user',       '',                                               'mail',   N'SMTP 계정'),
 ('mail_pass',       '',                                               'mail',   N'SMTP 비밀번호');
GO


/* ============================================================================
   2. 관리자 계정
   ----------------------------------------------------------------------------
   user_pw = LOWER( HEX( SHA2_256( user_salt || 평문비밀번호 ) ) )
   ※ salt 와 비밀번호 모두 ASCII 이므로
     PostgreSQL  : encode(digest(salt||pw,'sha256'),'hex')
     Java        : MessageDigest.getInstance("SHA-256")
     Python      : hashlib.sha256((salt+pw).encode()).hexdigest()
     PHP         : hash('sha256', $salt.$pw)
     → 모두 동일한 값이 나온다 (스택 간 회원 데이터 이식 가능)
   ============================================================================ */
DECLARE @salt CHAR(32)     = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
DECLARE @pw   VARCHAR(100) = 'admin1234!';

INSERT INTO dbo.tb_member
 (login_id, user_pw, user_salt, user_name, nickname, email, member_level, intro, is_use, reg_ip)
VALUES
 ('admin',
  LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', @salt + @pw), 2)),
  @salt,
  N'김진국', N'관리자', 'kimjinkuk7@nablecomm.com', 9,
  N'사이트 운영자 계정입니다.', 1, '127.0.0.1');

/* 테스트용 일반회원 (test / test1234!) */
DECLARE @salt2 CHAR(32)     = '0f1e2d3c4b5a69788796a5b4c3d2e1f0';
DECLARE @pw2   VARCHAR(100) = 'test1234!';

INSERT INTO dbo.tb_member
 (login_id, user_pw, user_salt, user_name, nickname, email, member_level, is_use, reg_ip)
VALUES
 ('test',
  LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', @salt2 + @pw2), 2)),
  @salt2,
  N'홍길동', N'길동', 'test@example.com', 3, 1, '127.0.0.1');
GO


/* ============================================================================
   3. 메뉴 (GNB 2 depth)
   ============================================================================ */
/* ----------------------------------------------------------------------------
   menu_url 은 view 폴더를 기준으로 한 경로를 넣는다.
   ASP 의 U() 헬퍼가 앞에 VIEW_ROOT("/view")를 붙여 최종 URL 을 만든다.
   ---------------------------------------------------------------------------- */

/* --- 1 depth --- */
INSERT INTO dbo.tb_menu (parent_id, menu_code, menu_name, menu_url, menu_depth, sort_no, auth_level) VALUES
 (NULL, 'home',      N'HOME',       '/main/Default.asp',            1, 10, 0),
 (NULL, 'about',     N'ABOUT',      '/about/Default.asp',           1, 20, 0),
 (NULL, 'portfolio', N'PORTFOLIO',  '/portfolio/Default.asp',       1, 30, 0),
 (NULL, 'blog',      N'BLOG',       '/board/List.asp?bid=blog',     1, 40, 0),
 (NULL, 'community', N'COMMUNITY',  NULL,                           1, 50, 0),
 (NULL, 'guestbook', N'GUESTBOOK',  '/board/List.asp?bid=guest',    1, 60, 0),
 (NULL, 'donate',    N'커피값',      '/donate/Default.asp',          1, 65, 0),
 (NULL, 'contact',   N'CONTACT',    '/contact/Default.asp',         1, 70, 0);
GO

/* --- 2 depth : ABOUT --- */
DECLARE @about INT = (SELECT menu_id FROM dbo.tb_menu WHERE menu_code = 'about');
INSERT INTO dbo.tb_menu (parent_id, menu_code, menu_name, menu_url, menu_depth, sort_no, auth_level) VALUES
 (@about, 'about_intro',  N'소개',        '/about/Default.asp', 2, 10, 0),
 (@about, 'about_career', N'경력 · 학력',  '/about/Career.asp',  2, 20, 0),
 (@about, 'about_skill',  N'기술 스택',    '/about/Skill.asp',   2, 30, 0),
 (@about, 'about_resume', N'이력서',      '/about/Resume.asp',  2, 40, 0);

/* --- 2 depth : COMMUNITY --- */
DECLARE @comm INT = (SELECT menu_id FROM dbo.tb_menu WHERE menu_code = 'community');
INSERT INTO dbo.tb_menu (parent_id, menu_code, menu_name, menu_url, menu_depth, sort_no, auth_level) VALUES
 (@comm, 'comm_notice',  N'공지사항',    '/board/List.asp?bid=notice',  2, 10, 0),
 (@comm, 'comm_free',    N'자유게시판',   '/board/List.asp?bid=free',    2, 20, 0),
 (@comm, 'comm_data',    N'자료실',      '/board/List.asp?bid=data',    2, 30, 0),
 (@comm, 'comm_gallery', N'갤러리',      '/board/List.asp?bid=gallery', 2, 40, 0);
GO


/* ============================================================================
   4. ★ 게시판 정의  -  행 1개 = 메뉴 1개
   ----------------------------------------------------------------------------
   auth : 0=누구나  3=일반회원  5=운영자  9=최고관리자
   ============================================================================ */
INSERT INTO dbo.tb_board_master
 (board_id, board_name, board_desc, skin_type, list_count, page_block, gallery_col,
  use_comment, use_file, use_category, use_secret, use_reply, use_editor, use_notice,
  file_max_count, file_max_size, file_ext_allow,
  auth_list, auth_read, auth_write, auth_comment, auth_admin, sort_no)
VALUES
 ('notice',  N'공지사항',   N'사이트 소식과 업데이트를 알려드립니다.',        'list',    15, 10, 3,
  1, 1, 0, 0, 0, 1, 1,
  3, 10240, 'jpg,jpeg,gif,png,webp,pdf,zip,hwp,docx,xlsx,pptx,txt',
  0, 0, 9, 3, 9, 10),

 ('free',    N'자유게시판', N'자유롭게 이야기를 나누는 공간입니다.',          'list',    15, 10, 3,
  1, 1, 1, 1, 1, 1, 1,
  2,  5120, 'jpg,jpeg,gif,png,webp,pdf,zip,txt',
  0, 0, 3, 3, 5, 20),

 ('data',    N'자료실',     N'개발 자료와 문서를 공유합니다.',               'list',    15, 10, 3,
  1, 1, 1, 0, 0, 1, 1,
  5, 51200, 'jpg,jpeg,gif,png,webp,pdf,zip,7z,hwp,docx,xlsx,pptx,txt,sql,md',
  0, 0, 5, 3, 9, 30),

 ('gallery', N'갤러리',     N'사진과 이미지를 모아둔 공간입니다.',            'gallery', 12, 10, 4,
  1, 1, 1, 0, 0, 1, 0,
  10, 20480, 'jpg,jpeg,gif,png,webp',
  0, 0, 3, 3, 5, 40),

 ('blog',    N'BLOG',      N'개발하며 배운 것들을 기록합니다.',              'blog',    10, 10, 3,
  1, 1, 1, 0, 0, 1, 0,
  5, 20480, 'jpg,jpeg,gif,png,webp,pdf,zip,txt,md',
  0, 0, 9, 3, 9, 50),

 ('guest',   N'방명록',     N'다녀가신 흔적을 남겨주세요.',                  'guest',   10, 10, 3,
  0, 0, 0, 1, 0, 0, 0,
  0, 0, '',
  0, 0, 0, 0, 5, 60);
GO


/* ============================================================================
   5. 게시판 분류
   ============================================================================ */
INSERT INTO dbo.tb_board_category (board_id, category_name, sort_no) VALUES
 ('free',    N'잡담',       10),
 ('free',    N'질문',       20),
 ('free',    N'정보공유',   30),
 ('data',    N'개발문서',   10),
 ('data',    N'소스코드',   20),
 ('data',    N'참고자료',   30),
 ('gallery', N'프로젝트',   10),
 ('gallery', N'일상',       20),
 ('blog',    N'Backend',    10),
 ('blog',    N'Database',   20),
 ('blog',    N'DevOps',     30),
 ('blog',    N'회고',       40);
GO


/* ============================================================================
   6. 기술 스택
   ============================================================================ */
INSERT INTO dbo.tb_skill (skill_group, skill_name, level_pct, experience_yr, color_hex, sort_no) VALUES
 (N'Language',  'Java',           85, 6.0, '#E76F00', 10),
 (N'Language',  'C#',             70, 3.0, '#68217A', 20),
 (N'Language',  'VBScript / ASP', 75, 4.0, '#4B8BBE', 30),
 (N'Language',  'Python',         80, 4.0, '#3776AB', 40),
 (N'Language',  'PHP',            70, 3.0, '#777BB4', 50),
 (N'Language',  'JavaScript',     80, 6.0, '#F7DF1E', 60),
 (N'Language',  'SQL',            90, 7.0, '#CC2927', 70),

 (N'Framework', 'Spring Boot',    85, 5.0, '#6DB33F', 10),
 (N'Framework', 'ASP.NET',        60, 2.0, '#512BD4', 20),
 (N'Framework', 'FastAPI',        70, 2.0, '#009688', 30),
 (N'Framework', 'Django',         65, 2.0, '#092E20', 40),
 (N'Framework', 'Laravel',        60, 2.0, '#FF2D20', 50),
 (N'Framework', 'jQuery',         85, 6.0, '#0769AD', 60),

 (N'Database',  'MS SQL Server',  90, 7.0, '#CC2927', 10),
 (N'Database',  'PostgreSQL',     80, 4.0, '#4169E1', 20),
 (N'Database',  'MySQL',          80, 5.0, '#4479A1', 30),
 (N'Database',  'Oracle',         65, 3.0, '#F80000', 40),
 (N'Database',  'Redis',          60, 2.0, '#DC382D', 50),

 (N'DevOps',    'IIS',            80, 5.0, '#0078D6', 10),
 (N'DevOps',    'Apache / Nginx', 70, 4.0, '#009639', 20),
 (N'DevOps',    'Docker',         70, 3.0, '#2496ED', 30),
 (N'DevOps',    'Git',            85, 6.0, '#F05032', 40),
 (N'DevOps',    'Linux',          70, 4.0, '#FCC624', 50);
GO


/* ============================================================================
   7. 경력 / 학력 / 자격
   ----------------------------------------------------------------------------
   ※ 샘플 데이터입니다. 관리자 > 경력관리 에서 실제 내용으로 교체하세요.
   ============================================================================ */
INSERT INTO dbo.tb_career (career_type, title, position, description, date_start, date_end, is_current, sort_no) VALUES
 ('work', N'(주)회사명 A', N'백엔드 개발팀 / 과장',
  N'사내 통합 관제 시스템 백엔드 설계 및 개발' + CHAR(10) +
  N'MS SQL 대용량 쿼리 튜닝 및 배치 파이프라인 구축' + CHAR(10) +
  N'레거시 Classic ASP 시스템의 Spring Boot 전환 주도',
  '2021-03-01', NULL, 1, 10),

 ('work', N'(주)회사명 B', N'웹 개발팀 / 대리',
  N'고객사 웹 서비스 구축 및 유지보수' + CHAR(10) +
  N'PHP / Python 기반 관리자 시스템 개발',
  '2018-01-01', '2021-02-28', 0, 20),

 ('edu',  N'○○대학교', N'컴퓨터공학과 학사',
  N'전공: 데이터베이스, 소프트웨어공학',
  '2011-03-01', '2017-02-28', 0, 10),

 ('cert', N'정보처리기사', N'한국산업인력공단', NULL, '2017-05-01', NULL, 0, 10),
 ('cert', N'SQLD (SQL 개발자)', N'한국데이터산업진흥원', NULL, '2019-04-01', NULL, 0, 20),

 ('award', N'사내 우수 프로젝트상', N'회사명 A',
  N'관제 시스템 성능 개선 프로젝트 (응답속도 60% 단축)',
  '2023-12-01', NULL, 0, 10);
GO


/* ============================================================================
   8. 포트폴리오 (샘플)
   ============================================================================ */
INSERT INTO dbo.tb_portfolio
 (title, subtitle, summary, content, category, client_name, job_role, team_size,
  period_start, period_end, is_ongoing, site_url, repo_url, is_main, sort_no)
VALUES
 (N'개인 홈페이지 4-Stack 프로젝트',
  N'동일 서비스를 4개 언어로 구현하고 비교하기',
  N'같은 요구사항·같은 DB 스키마·같은 CSS 로 Classic ASP / Spring Boot / Python / PHP 네 벌을 구현하여 언어와 프레임워크의 차이를 정량 비교한 프로젝트입니다.',
  N'<h3>배경</h3><p>레거시와 모던 스택을 오가며 일하다 보니, 같은 문제를 각 언어가 어떻게 다르게 푸는지 정리해두고 싶었습니다.</p><h3>설계 원칙</h3><ul><li>DB 스키마와 정적 리소스(CSS/JS)는 4개 스택이 공유</li><li>게시판은 엔진 1벌 + 정의 테이블로 6개 메뉴를 커버</li><li>비밀번호 해시를 SHA2-256(salt||pw) 로 통일하여 회원 데이터 이식 가능</li></ul><h3>결과</h3><p>Classic ASP → Spring Boot 순으로 구현하며 라우팅·ORM·템플릿·인증 네 축의 차이를 문서화했습니다.</p>',
  N'Web', N'개인 프로젝트', N'기획 · 설계 · 개발 전체', N'1인',
  '2026-08-01', NULL, 1, 'http://localhost', '', 1, 10),

 (N'통합 관제 시스템 고도화',
  N'Classic ASP 레거시의 단계적 현대화',
  N'10년 이상 운영된 Classic ASP 관제 시스템을 무중단으로 Spring Boot 로 전환한 프로젝트입니다.',
  N'<h3>과제</h3><p>운영 중단 없이 레거시를 걷어내야 했습니다.</p><h3>접근</h3><ul><li>스트랭글러 패턴으로 화면 단위 점진 전환</li><li>세션 저장소를 Redis 로 분리해 두 시스템이 로그인 공유</li><li>MS SQL 인덱스 재설계로 목록 조회 응답 60% 단축</li></ul>',
  N'Solution', N'(주)회사명 A', N'백엔드 리드', N'4명',
  '2023-03-01', '2024-06-30', 0, '', '', 1, 20),

 (N'사내 문서관리 시스템',
  N'대용량 첨부파일 처리와 권한 모델',
  N'부서·직급 기반 다단계 권한 모델과 대용량 첨부 스트리밍 다운로드를 구현했습니다.',
  N'<h3>주요 기능</h3><ul><li>부서 트리 기반 상속 권한</li><li>청크 업로드 및 재개 다운로드</li><li>전문 검색(Full-Text Search) 적용</li></ul>',
  N'Web', N'(주)회사명 B', N'풀스택 개발', N'3명',
  '2020-05-01', '2020-12-31', 0, '', '', 1, 30);
GO


/* ============================================================================
   9. 포트폴리오 ↔ 기술스택 매핑
   ============================================================================ */
INSERT INTO dbo.tb_portfolio_skill (portfolio_id, skill_id, sort_no)
SELECT p.portfolio_id, s.skill_id, s.sort_no
FROM dbo.tb_portfolio p
CROSS JOIN dbo.tb_skill s
WHERE p.sort_no = 10
  AND s.skill_name IN ('VBScript / ASP','Java','Spring Boot','Python','PHP','MS SQL Server','PostgreSQL','IIS');

INSERT INTO dbo.tb_portfolio_skill (portfolio_id, skill_id, sort_no)
SELECT p.portfolio_id, s.skill_id, s.sort_no
FROM dbo.tb_portfolio p
CROSS JOIN dbo.tb_skill s
WHERE p.sort_no = 20
  AND s.skill_name IN ('Java','Spring Boot','VBScript / ASP','MS SQL Server','Redis','Docker');

INSERT INTO dbo.tb_portfolio_skill (portfolio_id, skill_id, sort_no)
SELECT p.portfolio_id, s.skill_id, s.sort_no
FROM dbo.tb_portfolio p
CROSS JOIN dbo.tb_skill s
WHERE p.sort_no = 30
  AND s.skill_name IN ('PHP','Laravel','MySQL','Apache / Nginx','jQuery');
GO


/* ============================================================================
   10. 샘플 게시글
   ============================================================================ */
DECLARE @adminId INT = (SELECT member_id FROM dbo.tb_member WHERE login_id = 'admin');
DECLARE @testId  INT = (SELECT member_id FROM dbo.tb_member WHERE login_id = 'test');

/* -- 공지사항 -- */
INSERT INTO dbo.tb_board_article
 (board_id, title, content, writer_id, writer_name, writer_ip, is_notice, reg_dt)
VALUES
 ('notice', N'홈페이지를 새로 열었습니다',
  N'<p>안녕하세요. 개인 홈페이지를 새로 오픈했습니다.</p><p>Classic ASP + MS SQL Server 로 1차 구현했고, 앞으로 Spring Boot · Python · PHP 버전을 차례로 추가할 예정입니다.</p>',
  @adminId, N'관리자', '127.0.0.1', 1, DATEADD(DAY, -7, CURRENT_TIMESTAMP)),

 ('notice', N'게시판 이용 안내',
  N'<p>자유게시판은 로그인 후 이용하실 수 있습니다.</p><p>방명록은 비회원도 자유롭게 작성 가능합니다.</p>',
  @adminId, N'관리자', '127.0.0.1', 0, DATEADD(DAY, -5, CURRENT_TIMESTAMP));

/* -- 블로그 -- */
DECLARE @cateBackend INT = (SELECT category_id FROM dbo.tb_board_category WHERE board_id='blog' AND category_name=N'Backend');
DECLARE @cateDb      INT = (SELECT category_id FROM dbo.tb_board_category WHERE board_id='blog' AND category_name=N'Database');

INSERT INTO dbo.tb_board_article
 (board_id, category_id, title, content, tags, writer_id, writer_name, writer_ip, reg_dt)
VALUES
 ('blog', @cateBackend, N'Classic ASP 에서 SQL Injection 을 확실히 막는 법',
  N'<p>문자열 연결로 쿼리를 만드는 순간 게임은 끝납니다. <code>ADODB.Command</code> 의 파라미터 바인딩만 쓰면 됩니다.</p><pre>Set cmd = Server.CreateObject("ADODB.Command")\ncmd.CommandText = "SELECT * FROM tb_member WHERE login_id = ?"</pre><p>핵심은 <b>예외를 두지 않는 것</b>입니다. 한 곳이라도 문자열 연결이 남으면 전부 무의미해집니다.</p>',
  N'ASP,보안,SQLInjection', @adminId, N'관리자', '127.0.0.1', DATEADD(DAY, -4, CURRENT_TIMESTAMP)),

 ('blog', @cateDb, N'MSSQL 과 PostgreSQL 을 오갈 때 미리 피해야 할 7가지',
  N'<p>소문자 snake_case, 예약어 회피, CURRENT_TIMESTAMP, COALESCE, CONCAT, OFFSET/FETCH, 그리고 비밀번호 해시 방식 통일.</p><p>이 일곱 가지만 처음부터 지키면 스키마 이식이 거의 기계적인 작업이 됩니다.</p>',
  N'MSSQL,PostgreSQL,이식성', @adminId, N'관리자', '127.0.0.1', DATEADD(DAY, -2, CURRENT_TIMESTAMP)),

 ('blog', @cateBackend, N'게시판 6개를 코드 1벌로 만드는 구조',
  N'<p>게시판을 메뉴마다 복사하지 마세요. 정의 테이블(<code>tb_board_master</code>) 한 개면 됩니다.</p><p>새 게시판이 필요하면 INSERT 한 줄. 코드 수정은 0줄입니다.</p>',
  N'설계,게시판,아키텍처', @adminId, N'관리자', '127.0.0.1', DATEADD(DAY, -1, CURRENT_TIMESTAMP));

/* -- 자유게시판 -- */
DECLARE @cateFree INT = (SELECT category_id FROM dbo.tb_board_category WHERE board_id='free' AND category_name=N'정보공유');
INSERT INTO dbo.tb_board_article
 (board_id, category_id, title, content, writer_id, writer_name, writer_ip, reg_dt)
VALUES
 ('free', @cateFree, N'반갑습니다',
  N'<p>사이트 잘 보고 갑니다. 4개 언어 비교 시리즈 기대할게요!</p>',
  @testId, N'길동', '127.0.0.1', DATEADD(DAY, -3, CURRENT_TIMESTAMP));

/* -- 방명록 (비회원) -- */
INSERT INTO dbo.tb_board_article
 (board_id, title, content, writer_id, writer_name,
  writer_pw, writer_ip, reg_dt)
VALUES
 ('guest', N'방명록', N'첫 방문입니다. 구성이 깔끔하네요 :)',
  NULL, N'지나가던개발자',
  LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', 'guestsalt00000000000000000000000' + '1234'), 2)),
  '127.0.0.1', DATEADD(DAY, -1, CURRENT_TIMESTAMP));

/* -- group_no 세팅 (원글은 자기 자신을 그룹으로) -- */
UPDATE dbo.tb_board_article SET group_no = article_id WHERE group_no = 0;
GO


/* ============================================================================
   11. 댓글 샘플
   ============================================================================ */
DECLARE @art BIGINT = (SELECT TOP 1 article_id FROM dbo.tb_board_article WHERE board_id='blog' ORDER BY article_id);
DECLARE @adm INT    = (SELECT member_id FROM dbo.tb_member WHERE login_id='admin');
DECLARE @tst INT    = (SELECT member_id FROM dbo.tb_member WHERE login_id='test');

INSERT INTO dbo.tb_board_comment (article_id, board_id, content, writer_id, writer_name, writer_ip)
VALUES (@art, 'blog', N'파라미터 바인딩 정말 중요하죠. 잘 봤습니다.', @tst, N'길동', '127.0.0.1');

DECLARE @cmt BIGINT = SCOPE_IDENTITY();
INSERT INTO dbo.tb_board_comment (article_id, board_id, parent_id, comment_depth, content, writer_id, writer_name, writer_ip)
VALUES (@art, 'blog', @cmt, 1, N'감사합니다! 다음 글에서 CSRF 도 다뤄볼게요.', @adm, N'관리자', '127.0.0.1');

UPDATE a
   SET a.comment_count = (SELECT COUNT(*) FROM dbo.tb_board_comment c WHERE c.article_id = a.article_id AND c.is_del = 0)
  FROM dbo.tb_board_article a;
GO


/* ============================================================================
   12. 확인
   ============================================================================ */
PRINT '=== 초기 데이터 입력 완료 ===';
SELECT 'tb_config' AS tbl, COUNT(*) AS cnt FROM dbo.tb_config
UNION ALL SELECT 'tb_member',        COUNT(*) FROM dbo.tb_member
UNION ALL SELECT 'tb_menu',          COUNT(*) FROM dbo.tb_menu
UNION ALL SELECT 'tb_board_master',  COUNT(*) FROM dbo.tb_board_master
UNION ALL SELECT 'tb_board_category',COUNT(*) FROM dbo.tb_board_category
UNION ALL SELECT 'tb_board_article', COUNT(*) FROM dbo.tb_board_article
UNION ALL SELECT 'tb_board_comment', COUNT(*) FROM dbo.tb_board_comment
UNION ALL SELECT 'tb_skill',         COUNT(*) FROM dbo.tb_skill
UNION ALL SELECT 'tb_career',        COUNT(*) FROM dbo.tb_career
UNION ALL SELECT 'tb_portfolio',     COUNT(*) FROM dbo.tb_portfolio;
GO

PRINT '';
PRINT '  관리자 : admin / admin1234!';
PRINT '  일반회원: test  / test1234!';
PRINT '  ※ 운영 전 반드시 비밀번호를 변경하세요.';
GO
