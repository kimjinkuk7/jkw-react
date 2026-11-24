/* ============================================================================
   jkw.com - 저장 프로시저 / 뷰 (MS SQL Server)
   ----------------------------------------------------------------------------
   방침 : 비즈니스 로직은 애플리케이션 계층에 둔다.
          여기에는 (1) 집계 배치 (2) 조회 편의 뷰 만 정의한다.
          → PostgreSQL 이식 시 재작성 대상을 최소화하기 위함.
   실행 : sqlcmd -S localhost -E -i 03_proc.sql
   ============================================================================ */

SET NOCOUNT ON;
GO
USE jkwcom;
GO

IF OBJECT_ID('dbo.usp_visit_stat_aggregate', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_visit_stat_aggregate;
IF OBJECT_ID('dbo.usp_visit_log_purge',      'P') IS NOT NULL DROP PROCEDURE dbo.usp_visit_log_purge;
IF OBJECT_ID('dbo.vw_article_list',          'V') IS NOT NULL DROP VIEW dbo.vw_article_list;
IF OBJECT_ID('dbo.vw_dashboard_summary',     'V') IS NOT NULL DROP VIEW dbo.vw_dashboard_summary;
GO


/* ============================================================================
   VIEW : vw_article_list
   ----------------------------------------------------------------------------
   게시판 목록에서 매번 조인하는 항목(게시판명/분류명/작성자레벨)을 뷰로 고정.
   ASP 쪽 쿼리를 단순하게 유지하기 위한 용도.
   ============================================================================ */
CREATE VIEW dbo.vw_article_list
AS
SELECT
    a.article_id,
    a.board_id,
    bm.board_name,
    bm.skin_type,
    a.category_id,
    COALESCE(bc.category_name, N'') AS category_name,
    a.group_no,
    a.group_order,
    a.group_depth,
    a.title,
    a.writer_id,
    a.writer_name,
    COALESCE(m.nickname, a.writer_name) AS display_name,
    COALESCE(m.member_level, 0)         AS writer_level,
    a.thumb_file,
    a.tags,
    a.hit_count,
    a.comment_count,
    a.file_count,
    a.like_count,
    a.is_notice,
    a.is_secret,
    a.is_del,
    a.reg_dt,
    a.upd_dt
FROM dbo.tb_board_article a
     INNER JOIN dbo.tb_board_master   bm ON bm.board_id    = a.board_id
     LEFT  JOIN dbo.tb_board_category bc ON bc.category_id = a.category_id
     LEFT  JOIN dbo.tb_member         m  ON m.member_id    = a.writer_id;
GO


/* ============================================================================
   VIEW : vw_dashboard_summary
   ----------------------------------------------------------------------------
   관리자 대시보드 상단 카드 4개용 단일 행.
   ============================================================================ */
CREATE VIEW dbo.vw_dashboard_summary
AS
SELECT
    (SELECT COUNT(*) FROM dbo.tb_member         WHERE is_del = 0)                    AS member_total,
    (SELECT COUNT(*) FROM dbo.tb_member         WHERE is_del = 0
        AND CAST(reg_dt AS DATE) = CAST(CURRENT_TIMESTAMP AS DATE))                  AS member_today,
    (SELECT COUNT(*) FROM dbo.tb_board_article  WHERE is_del = 0)                    AS article_total,
    (SELECT COUNT(*) FROM dbo.tb_board_article  WHERE is_del = 0
        AND CAST(reg_dt AS DATE) = CAST(CURRENT_TIMESTAMP AS DATE))                  AS article_today,
    (SELECT COUNT(*) FROM dbo.tb_board_comment  WHERE is_del = 0)                    AS comment_total,
    (SELECT COUNT(*) FROM dbo.tb_contact        WHERE is_read = 0)                   AS contact_unread,
    (SELECT COALESCE(SUM(total_cnt), 0) FROM dbo.tb_visit_stat)                      AS visit_total,
    (SELECT COALESCE(total_cnt, 0) FROM dbo.tb_visit_stat
        WHERE visit_date = CAST(CURRENT_TIMESTAMP AS DATE))                          AS visit_today;
GO


/* ============================================================================
   PROC : usp_visit_stat_aggregate
   ----------------------------------------------------------------------------
   tb_visit_log 를 일별로 집계하여 tb_visit_stat 에 MERGE.
   @target_date NULL 이면 오늘 기준.
   호출 : EXEC dbo.usp_visit_stat_aggregate;            -- 오늘
          EXEC dbo.usp_visit_stat_aggregate '2026-08-19';
   ============================================================================ */
CREATE PROCEDURE dbo.usp_visit_stat_aggregate
    @target_date DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @target_date IS NULL
        SET @target_date = CAST(CURRENT_TIMESTAMP AS DATE);

    ;WITH agg AS (
        SELECT
            visit_date,
            COUNT(*)                                                    AS total_cnt,
            COUNT(DISTINCT ip)                                          AS unique_cnt,
            SUM(CASE WHEN device_type = 'mobile' THEN 1 ELSE 0 END)     AS mobile_cnt,
            SUM(CASE WHEN device_type <> 'mobile'
                      OR device_type IS NULL     THEN 1 ELSE 0 END)     AS pc_cnt
        FROM dbo.tb_visit_log
        WHERE visit_date = @target_date
        GROUP BY visit_date
    )
    MERGE dbo.tb_visit_stat AS t
    USING agg AS s
       ON t.visit_date = s.visit_date
    WHEN MATCHED THEN
        UPDATE SET t.total_cnt  = s.total_cnt,
                   t.unique_cnt = s.unique_cnt,
                   t.pc_cnt     = s.pc_cnt,
                   t.mobile_cnt = s.mobile_cnt,
                   t.upd_dt     = CURRENT_TIMESTAMP
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (visit_date, total_cnt, unique_cnt, pc_cnt, mobile_cnt)
        VALUES (s.visit_date, s.total_cnt, s.unique_cnt, s.pc_cnt, s.mobile_cnt);
END
GO


/* ============================================================================
   PROC : usp_visit_log_purge
   ----------------------------------------------------------------------------
   집계가 끝난 오래된 raw 로그 삭제 (기본 90일 이전).
   SQL Server 에이전트로 야간 1회 실행 권장.
   ============================================================================ */
CREATE PROCEDURE dbo.usp_visit_log_purge
    @keep_days INT = 90
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @cut DATE = DATEADD(DAY, -@keep_days, CAST(CURRENT_TIMESTAMP AS DATE));

    /* 삭제 전에 미집계분이 남아있지 않도록 한 번 더 집계 */
    DECLARE @d DATE;
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT visit_date FROM dbo.tb_visit_log WHERE visit_date < @cut;
    OPEN cur;
    FETCH NEXT FROM cur INTO @d;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.usp_visit_stat_aggregate @d;
        FETCH NEXT FROM cur INTO @d;
    END
    CLOSE cur; DEALLOCATE cur;

    DELETE FROM dbo.tb_visit_log  WHERE visit_date < @cut;
    DELETE FROM dbo.tb_login_log  WHERE reg_dt     < DATEADD(DAY, -@keep_days, CURRENT_TIMESTAMP);
END
GO


PRINT '=== 뷰 2개 / 프로시저 2개 생성 완료 ===';
GO
