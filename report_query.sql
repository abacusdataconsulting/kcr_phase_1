/****** query for studies where the query number is 1 ******/
/****** tbl_prefix should be replaced with the corresponding table prefix wherever it occurs ******/

DROP FUNCTION IF EXISTS removeWhitespace;
DELIMITER |

CREATE FUNCTION REMOVEWHITESPACE(str CHAR(250))
    RETURNS CHAR(250)
    DETERMINISTIC
    BEGIN
        DECLARE str_whitespace_removed CHAR(250);
        SET str_whitespace_removed=TRIM(REPLACE(REPLACE(REPLACE(str,'\t',''),'\n',''),'\r',''));
        RETURN str_whitespace_removed;
    END |

DELIMITER ;

DROP FUNCTION IF EXISTS countWeekdays;
CREATE FUNCTION countWeekdays(date1 DATE, date2 DATE)
	RETURNS INT
    DETERMINISTIC
    RETURN ABS(DATEDIFF(date2, date1)) + 1
     - ABS(DATEDIFF(ADDDATE(date2, INTERVAL 1 - DAYOFWEEK(date2) DAY),
                    ADDDATE(date1, INTERVAL 1 - DAYOFWEEK(date1) DAY))) / 7 * 2
     - (DAYOFWEEK(IF(date1 < date2, date1, date2)) = 1)
     - (DAYOFWEEK(IF(date1 > date2, date1, date2)) = 7);


/********************Pull relevant columns from tables*********************/


DROP TEMPORARY TABLES IF EXISTS 

	tabl_prefixplan
    ,tabl_prefixmv
    ,tabl_prefixsite
    ,tabl_prefixsites
    ,tabl_prefixstudy
    ,tabl_prefixlink /*used to join plan table with site table*/
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixplan AS

    SELECT 
		docid
		,countryid
		,planspid
		,planmvtyp
		,planmvid
		,planmvdat
		,planmvdurat
		,planmvendat
		,planmvstat
		,record_status
	FROM 
		repdata_tabl_prefixplan
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixmv AS
	
    SELECT  
		docid
		,sitecounter
		,countryid
		,visitid
		,approvalid
		,mvseq
		,dayid
		,username
		,user_full_name
		,mvperf
		,mvrepname
		,mvdat
		,approvalstage
		,approvaldat
		,approvalname
		,appdurat
		,mvmultiday
		,mvdate2
		,record_status
	FROM 
		repdata_tabl_prefixmv
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixsite AS
	
    SELECT
		docid
		,siteid 
		,sitemonfirst
		,sitemonlast
		,countryid
		,record_status
        ,sitemonseq
	FROM 
		repdata_tabl_prefixsite
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixsites AS
	
    SELECT
		label
		,sitecode
	FROM 
		repdata_tabl_prefixsites
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixstudy AS
	
    SELECT 
		studyid
		,docid
	FROM 
		repdata_tabl_prefixstudy
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixlink AS
    
    SELECT
		docid
		,countryid
		,planspid
		,tblname
		,fldname
		,sitecounter_t
		,countryid_t
		,siteid_t
		,sitemonseq_t
		,tblname_t
	FROM 
		repdata_tabl_prefixlink
;


/****************************Apply filters*****************************/


DROP TEMPORARY TABLES IF EXISTS

	tabl_prefixplan_2
    ,tabl_prefixmv_2
    ,tabl_prefixsite_2
    ,tabl_prefixlink_2
;


CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixplan_2 AS
	
    SELECT 
		docid
		,countryid
		,planspid
		,planmvtyp
		,planmvid
		,planmvdat
		,planmvdurat
		,planmvendat
		,planmvstat
        ,CASE WHEN planmvdat IS NULL THEN 1 ELSE NULL END AS data_issue_missing_plan_start_date
        ,CASE WHEN planmvendat IS NULL THEN 1 ELSE NULL END AS data_issue_missing_plan_end_date
        ,CASE WHEN planmvdurat IS NULL THEN 1 ELSE NULL END AS data_issue_missing_plan_durat
        ,CASE WHEN planmvdurat != DATEDIFF(planmvendat,planmvdat)+1 THEN 1 ELSE NULL END AS data_issue_incorrect_plan_durat
        ,CASE WHEN planmvtyp IS NULL THEN 1 ELSE NULL END AS data_issue_planned_visit_type
        ,CASE WHEN planmvdat > planmvendat THEN 1 ELSE NULL END AS data_issue_plan_start_after_end
        ,CASE WHEN DAYOFWEEK(planmvdat) IN (1,7) THEN 1 ELSE NULL END AS data_issue_plan_state_date_is_weekend
        ,CASE WHEN DAYOFWEEK(planmvendat) IN (1,7) THEN 1 ELSE NULL END AS data_issue_plan_end_date_is_weekend
	FROM 
		tabl_prefixplan
	WHERE record_status = 'complete'
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixmv_2 AS
	
    SELECT  
		docid
		,sitecounter
		,countryid
		,visitid
		,approvalid
		,mvseq
		,dayid
		,username
		,user_full_name
		,mvperf
		,mvrepname
		,mvdat
		,approvalstage
		,approvaldat
		,approvalname
		,appdurat
		,mvmultiday
		,mvdate2
	FROM 
		tabl_prefixmv
	WHERE record_status = 'complete'
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixsite_2 AS
	
    SELECT
		docid
		,siteid 
		,sitemonfirst
		,sitemonlast
		,sitemonact
		,sitemondeact
		,countryid
        ,sitemonseq
	FROM 
		repdata_tabl_prefixsite
	WHERE record_status = 'complete'
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixlink_2 AS

	SELECT 
		docid
		,countryid
		,planspid
		,sitecounter_t
		,countryid_t
		,siteid_t
		,sitemonseq_t
	FROM 
		tabl_prefixlink
	WHERE 
		tblname = 'PLAN'
			AND 
		tblname_t = 'SITE'
			AND 
		fldname = 'link_mvplanning';
        
        
        
/****************************Use link table to join plan table with site table to get monitor name*****************************/        
        
      
DROP TEMPORARY TABLES IF EXISTS

	tabl_prefixplan_monitor
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixplan_monitor AS

	SELECT  
		plan.docid
		,plan.countryid
		,plan.planspid
		,plan.planmvtyp
		,plan.planmvid
		,plan.planmvdat
		,plan.planmvdurat
		,plan.planmvendat
		,plan.planmvstat
        ,plan.data_issue_missing_plan_start_date
        ,plan.data_issue_missing_plan_end_date
        ,plan.data_issue_missing_plan_durat
        ,plan.data_issue_incorrect_plan_durat
        ,plan.data_issue_planned_visit_type
        ,plan.data_issue_plan_start_after_end
        ,plan.data_issue_plan_state_date_is_weekend
        ,plan.data_issue_plan_end_date_is_weekend
        ,CONCAT(
				REMOVEWHITESPACE(site.sitemonfirst)
				,' '
				,REMOVEWHITESPACE(site.sitemonlast)
            ) AS site_monitor
	FROM 
		tabl_prefixplan_2 AS plan
			LEFT JOIN
				tabl_prefixlink_2 AS link
					ON 
						plan.docid = link.docid
					AND 
						plan.planspid = link.planspid
					AND 
						plan.countryid = link.countryid
			LEFT JOIN 
				tabl_prefixsite_2 AS site
					ON 
						link.siteid_t = site.siteid
                    AND 
						link.countryid_t = site.countryid
					AND 
						link.sitemonseq_t = site.sitemonseq
;


        
/****************************Aggregate monitor names, in case more than one monitor is assigned to a planned visit*****************************/   


DROP TEMPORARY TABLES IF EXISTS

	tabl_prefixplan_monitor_agg
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixplan_monitor_agg AS

	SELECT  
		docid
		,countryid
		,planspid
		,planmvtyp
		,planmvid
		,planmvdat
		,planmvdurat
		,planmvendat
		,planmvstat
        ,GROUP_CONCAT(site_monitor) AS site_monitors
        ,data_issue_missing_plan_start_date
        ,data_issue_missing_plan_end_date
        ,data_issue_missing_plan_durat
        ,data_issue_incorrect_plan_durat
        ,data_issue_planned_visit_type
        ,data_issue_plan_start_after_end
        ,data_issue_plan_state_date_is_weekend
        ,data_issue_plan_end_date_is_weekend
        ,CASE WHEN GROUP_CONCAT(site_monitor) IS NULL THEN 1 ELSE NULL END AS data_issue_missing_monitor_name
	FROM 
		tabl_prefixplan_monitor
	GROUP BY
		docid
		,countryid
		,planspid
		,planmvtyp
		,planmvid
		,planmvdat
		,planmvdurat
		,planmvendat
		,planmvstat
        ,data_issue_missing_plan_start_date
        ,data_issue_missing_plan_end_date
        ,data_issue_missing_plan_durat
        ,data_issue_incorrect_plan_durat
        ,data_issue_planned_visit_type
        ,data_issue_plan_start_after_end
        ,data_issue_plan_state_date_is_weekend
        ,data_issue_plan_end_date_is_weekend

;


/******************Get date of next approval by joining mv table to itself on next largest approvalid****************/

DROP TEMPORARY TABLES IF EXISTS 

	tabl_prefixmv_2_copied
    ,tabl_prefixmv_next_approvalid
    ,tabl_prefixmv_3
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixmv_2_copied AS

	SELECT * FROM tabl_prefixmv_2
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixmv_next_approvalid AS
    
    SELECT 
		l.docid
		,l.sitecounter
		,l.countryid
		,l.visitid
		,l.approvalid
		,l.mvseq
		,l.dayid
		,l.username
		,l.user_full_name
		,l.mvperf
		,l.mvrepname
		,l.mvdat
		,l.approvalstage
		,l.approvaldat
		,l.approvalname
		,l.appdurat
		,l.mvmultiday
		,l.mvdate2
        ,MIN(r.approvalid) AS next_approval_id
	FROM tabl_prefixmv_2 AS l
			LEFT JOIN tabl_prefixmv_2_copied AS r
				ON l.docid = r.docid 
					AND l.sitecounter = r.sitecounter
                    AND l.countryid = r.countryid
                    AND l.visitid = r.visitid
                    AND ( l.mvseq = r.mvseq
							OR (l.mvseq IS NULL AND r.mvseq IS NULL))
					AND  l.approvalid < r.approvalid
	GROUP BY 
		l.docid
		,l.sitecounter
		,l.countryid
		,l.visitid
		,l.approvalid
		,l.mvseq
		,l.dayid
		,l.username
		,l.user_full_name
		,l.mvperf
		,l.mvrepname
		,l.mvdat
		,l.approvalstage
		,l.approvaldat
		,l.approvalname
		,l.appdurat
		,l.mvmultiday
		,l.mvdate2
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixmv_3 AS
    
    SELECT 
		l.docid
		,l.sitecounter
		,l.countryid
		,l.visitid
		,l.approvalid
		,l.mvseq
		,l.dayid
		,l.username
		,l.user_full_name
		,l.mvperf
		,l.mvrepname
		,l.mvdat
		,l.approvalstage
		,l.approvaldat
		,l.approvalname
		,l.appdurat
		,l.mvmultiday
		,l.mvdate2
        ,r.approvaldat AS next_date
        ,CASE WHEN r.approvalstage = 2 THEN 1 ELSE 0 END AS next_stage_reject
	FROM 
		tabl_prefixmv_next_approvalid AS l
			LEFT JOIN tabl_prefixmv_2_copied AS r
				ON l.docid = r.docid 
					AND l.sitecounter = r.sitecounter
                    AND l.countryid = r.countryid
                    AND l.visitid = r.visitid
                    AND ( l.mvseq = r.mvseq
							OR (l.mvseq IS NULL AND r.mvseq IS NULL))
                    AND l.next_approval_id = r.approvalid /*find the subsequent approval stage*/
;                    

/****************************Aggregate mv table*****************************/


DROP TEMPORARY TABLES IF EXISTS

	tabl_prefixmv_agg_1
    ,tabl_prefixmv_agg_2
    ,tabl_prefixmv_agg_3
    ,tabl_prefixmv_submit_reject
    ,tabl_prefixsubmit
    ,tabl_prefixsubmit_2
    ,tabl_prefixreject
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixmv_agg_1 AS

	SELECT 
		docid
		,sitecounter
		,countryid
		,visitid
		,mvseq
		,dayid
		,username
		,user_full_name
		,GROUP_CONCAT(DISTINCT REMOVEWHITESPACE(mvperf)) AS mvperf
		,GROUP_CONCAT(DISTINCT REMOVEWHITESPACE(mvrepname)) AS mvrepname
		,MAX(mvdat) AS mvdat
		,CASE WHEN approvalstage = 1 THEN 'S'
			WHEN approvalstage = 2 THEN 'R'
			WHEN approvalstage = 3 THEN 'A'
			ELSE approvalstage END AS stage
		,CASE WHEN approvalid = 1 THEN approvalname END AS first_submitter_name
		,CASE WHEN approvalstage = 2 THEN 1 END AS rejection_counter
		,CASE WHEN approvalstage = 1 THEN 1 END AS submission_counter
        ,CASE WHEN approvalstage = 1 THEN approvalid END AS submission_approvalid
        ,CASE WHEN approvalstage = 2 THEN approvalid END AS rejection_approvalid
		,CASE WHEN approvalstage = 3 THEN approvaldat END AS approval_date
        ,CASE WHEN approvalstage = 3 THEN approvalid END AS approval_approvalid
		,approvaldat
		,approvalname
		,CASE WHEN approvalstage = 1 THEN approvalname END AS all_submitter_name
		,CASE WHEN approvalstage IN (2,3) THEN approvalname END AS reviewername
		,appdurat
		,mvmultiday
		,MAX(mvdate2) AS mvendat
        ,next_date
        ,next_stage_reject
        ,CASE WHEN approvalstage = 1 THEN CONCAT(approvaldat,',',next_date) END AS submission_next
        ,CASE WHEN approvalstage = 2 THEN CONCAT(approvaldat,',',next_date) END AS reject_submit
        ,CASE WHEN approvalstage = 1 
			AND approvaldat >= next_date
            THEN 1
            WHEN approvalstage = 1 
            AND approvaldat < next_date
            THEN DATEDIFF(next_date,approvaldat) + 1 END AS submission_duration
		,CASE WHEN approvalstage = 2
			AND approvaldat >= next_date
            THEN 1
            WHEN approvalstage = 2
            AND approvaldat < next_date
            THEN DATEDIFF(next_date,approvaldat) + 1 END AS rejection_duration
		,CASE WHEN approvalstage = 1 
				AND approvalname IS NULL 
                AND approvalid != 1 
                THEN 1 ELSE NULL END 
                AS data_issue_missing_stage_submittor_name
		,CASE WHEN approvalstage = 1 
				AND approvalname IS NULL
                THEN 1 ELSE NULL END
                AS data_issue_missing_any_submittor_name
		,CASE WHEN approvalstage = 2
			AND approvalname IS NULL
            THEN 1 ELSE NULL END 
            AS data_issue_missing_stage_reviewer_name
		,CASE WHEN approvalid = 1 
			AND approvaldat IS NULL
            THEN 1 ELSE NULL END
            AS data_issue_missing_first_submission_date
		,CASE WHEN approvalstage = 3 
			AND approvaldat IS NULL
            THEN 1 ELSE NULL END
            AS data_issue_missing_approval_date
		,CASE WHEN approvalstage = 1
			AND next_date IS NULL
            THEN 1 ELSE NULL END
            AS data_issue_missing_date_in_sub_next_pair
		,CASE WHEN approvalstage = 2
			AND next_date IS NULL
            THEN 1 ELSE NULL END
            AS data_issue_missing_date_in_rej_sub_pair
		,CASE WHEN approvalstage = 1 
			AND next_date < approvaldat
            THEN 1 ELSE NULL END
            AS data_issue_wrong_order_of_dates_in_sub_next_pair
		,CASE WHEN approvalstage = 2
			AND next_date < approvaldat
            THEN 1 ELSE NULL END
            AS data_issue_wrong_order_of_dates_in_rej_sub_pair
	FROM
		tabl_prefixmv_3
	GROUP BY 
		docid
		,sitecounter
		,countryid
		,visitid
		,approvalid
		,mvseq
		,dayid
		,username
		,user_full_name
		,approvalstage
		,approvaldat
		,approvalname
		,appdurat
		,mvmultiday
        ,next_date
        ,next_stage_reject
	ORDER BY 
		docid
		,sitecounter
		,countryid
		,mvseq
		,visitid
		,approvalid
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixmv_agg_2 AS

	SELECT 
		docid
		,sitecounter
		,countryid
		,visitid
		,mvseq
		,SUM(mvperf) AS mvperf
		,GROUP_CONCAT(DISTINCT REMOVEWHITESPACE(mvrepname)) AS mvrepname
		,MAX(mvdat) AS mvdat
		,GROUP_CONCAT(stage) AS stage
		,GROUP_CONCAT(DISTINCT REMOVEWHITESPACE(first_submitter_name)) AS submitter_name
		,GROUP_CONCAT(DISTINCT REMOVEWHITESPACE(all_submitter_name)) AS stagesubmittorname
		,COUNT(rejection_counter) AS rejection_round
		,COUNT(submission_counter) AS submission_round
        ,MIN(submission_approvalid) AS first_submission_approvalid
        ,MAX(submission_approvalid) AS latest_submission_approvalid
        ,MAX(rejection_approvalid) AS latest_rejection_approvalid
		,MAX(approval_date) AS approval_date
		,GROUP_CONCAT(DISTINCT REMOVEWHITESPACE(approvalname)) AS approvalname
		,GROUP_CONCAT(DISTINCT REMOVEWHITESPACE(reviewername)) AS reviewername
		,MAX(CASE WHEN mvendat IS NULL THEN mvdat ELSE mvendat END) AS mvendat
		,SUM(submission_duration) 
				- 
			SUM(CASE WHEN rejection_duration = 1 
				THEN 1 ELSE 0 END
                ) 
			AS total_submit_len
        ,SUM(rejection_duration)
				-
			SUM(CASE WHEN submission_duration = 1
				AND next_stage_reject = 1
                AND submission_approvalid != 1
            THEN 1 ELSE 0 END
            )
			AS total_cra_time
        ,GROUP_CONCAT(submission_next SEPARATOR ';') AS submission_next
        ,GROUP_CONCAT(reject_submit SEPARATOR ';') AS reject_submit
		,COUNT(data_issue_missing_stage_submittor_name) 
			AS data_issue_missing_stage_submittor_name
		,COUNT(data_issue_missing_any_submittor_name) 
			AS data_issue_missing_any_submittor_name
		,COUNT(data_issue_missing_stage_reviewer_name) 
			AS data_issue_missing_stage_reviewer_name
		,COUNT(data_issue_missing_first_submission_date) 
			AS data_issue_missing_first_submission_date
		,COUNT(data_issue_missing_approval_date) 
			AS data_issue_missing_approval_date
		,COUNT(data_issue_missing_date_in_sub_next_pair) 
			AS data_issue_missing_date_in_sub_next_pair
		,COUNT(data_issue_missing_date_in_rej_sub_pair) 
			AS data_issue_missing_date_in_rej_sub_pair
		,COUNT(data_issue_wrong_order_of_dates_in_sub_next_pair) 
			AS data_issue_wrong_order_of_dates_in_sub_next_pair
		,COUNT(data_issue_wrong_order_of_dates_in_rej_sub_pair) 
			AS data_issue_wrong_order_of_dates_in_rej_sub_pair
	FROM 
		tabl_prefixmv_agg_1
	GROUP BY 
		docid
		,sitecounter
		,countryid
		,visitid
		,mvseq
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixsubmit AS
    
    SELECT 
		docid
		,sitecounter
		,countryid
		,visitid
		,mvseq
		,stage
		,approvaldat
        ,submission_approvalid AS approvalid
		,submission_duration
	FROM 
		tabl_prefixmv_agg_1
	WHERE
		stage = 'S'
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixsubmit_2 AS
    
    SELECT * FROM tabl_prefixsubmit
;




CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixreject AS
    
    SELECT 
		docid
		,sitecounter
		,countryid
		,visitid
		,mvseq
		,stage
		,approvaldat
        ,rejection_approvalid AS approvalid
		,rejection_duration
	FROM 
		tabl_prefixmv_agg_1
	WHERE
		stage = 'R'
;


CREATE TEMPORARY TABLE IF NOT EXISTS 

tabl_prefixmv_submit_reject AS

	SELECT 
		mv.docid
		,mv.sitecounter
		,mv.countryid
		,mv.visitid
		,mv.mvseq
		,mv.mvperf
		,mv.mvrepname
		,mv.mvdat
		,mv.stage
		,mv.submitter_name
		,mv.stagesubmittorname
		,mv.rejection_round
		,mv.submission_round
        ,mv.first_submission_approvalid
        ,first_submit.approvaldat AS first_submission
        ,mv.latest_submission_approvalid
        ,last_submit.approvaldat AS latest_submission
        ,mv.latest_rejection_approvalid
        ,last_reject.approvaldat AS latest_rejection
		,mv.approval_date
		,mv.approvalname
		,mv.reviewername
		,mv.mvendat
		,mv.total_submit_len
        ,mv.total_cra_time
        ,mv.submission_next
        ,mv.reject_submit
		,mv.data_issue_missing_stage_submittor_name
		,mv.data_issue_missing_any_submittor_name
		,mv.data_issue_missing_stage_reviewer_name
		,mv.data_issue_missing_first_submission_date
		,mv.data_issue_missing_approval_date
		,mv.data_issue_missing_date_in_sub_next_pair
		,mv.data_issue_missing_date_in_rej_sub_pair
		,mv.data_issue_wrong_order_of_dates_in_sub_next_pair
		,mv.data_issue_wrong_order_of_dates_in_rej_sub_pair
        ,last_submit.submission_duration AS last_submit_len
        ,last_reject.rejection_duration AS last_reject_len
	FROM tabl_prefixmv_agg_2 AS mv
		LEFT JOIN tabl_prefixsubmit AS first_submit
			ON mv.docid = first_submit.docid
						AND mv.countryid = first_submit.countryid
						AND mv.visitid = first_submit.visitid
						AND (mv.mvseq = first_submit.mvseq
								OR 
								(mv.mvseq IS NULL AND first_submit.mvseq IS NULL)
								)
						AND mv.first_submission_approvalid = first_submit.approvalid
			LEFT JOIN tabl_prefixsubmit_2 AS last_submit
				ON mv.docid = last_submit.docid
						AND mv.countryid = last_submit.countryid
						AND mv.visitid = last_submit.visitid
						AND (mv.mvseq = last_submit.mvseq
								OR 
								(mv.mvseq IS NULL AND last_submit.mvseq IS NULL)
								)
						AND mv.latest_submission_approvalid = last_submit.approvalid
				LEFT JOIN tabl_prefixreject AS last_reject
					ON mv.docid = last_reject.docid
						AND mv.countryid = last_reject.countryid
						AND mv.visitid = last_reject.visitid
						AND (mv.mvseq = last_reject.mvseq
								OR 
								(mv.mvseq IS NULL AND last_reject.mvseq IS NULL)
								)
						AND mv.latest_rejection_approvalid = last_reject.approvalid
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixmv_agg_3 AS
    
	SELECT 
		docid
		,countryid
		,visitid
		,mvdat
		,mvrepname
		,mvseq
		,mvendat
		,submitter_name
		,stagesubmittorname
		,submission_round
		,first_submission
        ,latest_submission
        ,latest_rejection
		,rejection_round
		,CASE WHEN RIGHT(stage,1) = 'S' THEN 'Submitted'
			WHEN RIGHT(stage,1) = 'A' THEN 'Approved'
			WHEN RIGHT(stage,1) = 'R' THEN 'Rejected'
			ELSE NULL END
			AS current_stage
		,approval_date
		,reviewername
		,stage
        ,total_submit_len
        ,total_cra_time
        ,submission_next
        ,reject_submit
        ,last_submit_len
        ,last_reject_len
        ,CASE WHEN mvrepname IS NULL 
			THEN 1 ELSE NULL END 
            AS data_issue_missing_first_submittor_name
        ,data_issue_missing_stage_submittor_name
		,data_issue_missing_any_submittor_name
		,data_issue_missing_stage_reviewer_name
		,data_issue_missing_first_submission_date
		,data_issue_missing_approval_date
		,data_issue_missing_date_in_sub_next_pair
		,data_issue_missing_date_in_rej_sub_pair
		,data_issue_wrong_order_of_dates_in_sub_next_pair
		,data_issue_wrong_order_of_dates_in_rej_sub_pair
        ,CASE WHEN mvdat IS NULL 
			THEN 1 ELSE NULL END 
            AS data_issue_missing_mv_start_date
        ,CASE WHEN mvendat IS NULL 
			THEN 1 ELSE NULL END 
            AS data_issue_missing_mv_end_date
        ,CASE WHEN submission_round = 0 
			THEN 1 ELSE NULL END 
            AS data_issue_missing_1_submission_stage
        ,CASE WHEN submission_round > 0 
			AND latest_submission IS NULL 
            THEN 1 ELSE NULL END 
            AS data_issue_missing_latest_submission_date
		,CASE WHEN rejection_round > 0
			AND latest_rejection IS NULL
            THEN 1 ELSE NULL END 
			AS data_issue_missing_latest_rejection_date
		,CASE WHEN mvdat > mvendat 
			THEN 1 ELSE NULL END
            AS data_issue_mv_start_date_after_mv_end_date
		,CASE WHEN mvendat > approval_date
			THEN 1 ELSE NULL END
			AS data_issue_mv_end_date_after_approval
		,CASE WHEN mvendat > first_submission
			THEN 1 ELSE NULL END
			AS data_issue_mv_end_date_after_first_submission
		,CASE WHEN latest_submission > approval_date 
			THEN 1 ELSE NULL END
            AS data_issue_last_submission_date_after_next
		,CASE WHEN latest_rejection > approval_date
			THEN 1 ELSE NULL END 
            AS data_issue_last_rejection_date_after_next
		,CASE WHEN first_submission > latest_rejection
			THEN 1 ELSE NULL END
            AS data_issue_first_submission_after_latest_rejection
		,CASE WHEN DAYOFWEEK(mvdat) IN (1,7) 
			THEN 1 ELSE NULL END 
			AS data_issue_mv_state_date_is_weekend
        ,CASE WHEN DAYOFWEEK(mvendat) IN (1,7) 
			THEN 1 ELSE NULL END 
            AS data_issue_mv_end_date_is_weekend
		,CASE WHEN stage IS NOT NULL
			AND (stage NOT LIKE 'S%'
				OR stage LIKE '%S,S%'
                OR stage LIKE '%R,A%'
                OR stage LIKE '%R,R%'
                OR stage LIKE '%A,A%'
                OR stage LIKE '%A,R%'
                OR stage LIKE '%A,S%'
                ) THEN 1 
                ELSE NULL END 
                AS data_issue_wrong_stage_order
	FROM 
		tabl_prefixmv_submit_reject
;


/****************************Union mv and plan tables*****************************/


DROP TEMPORARY TABLES IF EXISTS
	tabl_prefixmv_plan_left
    ,tabl_prefixmv_plan_right
    ,tabl_prefixmv_plan_union
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixmv_plan_left AS
    
	SELECT 
		plan.docid
		,plan.countryid
		,plan.planspid
		,plan.planmvtyp
		,plan.planmvid
		,plan.planmvdat
		,plan.planmvdurat
		,plan.planmvendat
		,CASE WHEN plan.planmvstat = 2 AND mv.docid IS NULL THEN 9
			ELSE plan.planmvstat END AS planmvstat
        ,plan.site_monitors
        ,plan.data_issue_missing_plan_start_date
        ,plan.data_issue_missing_plan_end_date
        ,plan.data_issue_missing_plan_durat
        ,plan.data_issue_incorrect_plan_durat
        ,plan.data_issue_planned_visit_type
        ,plan.data_issue_plan_start_after_end
        ,plan.data_issue_plan_state_date_is_weekend
        ,plan.data_issue_plan_end_date_is_weekend
        ,plan.data_issue_missing_monitor_name
		,mv.visitid
		,mv.mvdat
		,mv.mvendat
		,mv.mvrepname
		,mv.mvseq
		,mv.submitter_name
		,mv.stagesubmittorname
		,mv.first_submission
		,mv.submission_round
		,mv.latest_submission
		,mv.reviewername
		,mv.rejection_round
		,mv.latest_rejection
		,mv.current_stage
		,mv.approval_date
		,mv.stage
        ,mv.total_submit_len
        ,mv.total_cra_time
        ,mv.submission_next
        ,mv.reject_submit
        ,mv.data_issue_missing_first_submittor_name
        ,mv.data_issue_missing_stage_submittor_name
		,mv.data_issue_missing_any_submittor_name
		,mv.data_issue_missing_stage_reviewer_name
		,mv.data_issue_missing_first_submission_date
		,mv.data_issue_missing_approval_date
		,mv.data_issue_missing_date_in_sub_next_pair
		,mv.data_issue_missing_date_in_rej_sub_pair
		,mv.data_issue_wrong_order_of_dates_in_sub_next_pair
		,mv.data_issue_wrong_order_of_dates_in_rej_sub_pair
        ,mv.data_issue_missing_mv_start_date
        ,mv.data_issue_missing_mv_end_date
        ,mv.data_issue_missing_1_submission_stage
        ,mv.data_issue_missing_latest_submission_date
		,mv.data_issue_missing_latest_rejection_date
		,mv.data_issue_mv_start_date_after_mv_end_date
		,mv.data_issue_mv_end_date_after_approval
		,mv.data_issue_mv_end_date_after_first_submission
        ,mv.data_issue_last_submission_date_after_next
		,mv.data_issue_last_rejection_date_after_next
		,mv.data_issue_first_submission_after_latest_rejection
		,mv.data_issue_mv_state_date_is_weekend
        ,mv.data_issue_mv_end_date_is_weekend
		,mv.data_issue_wrong_stage_order
        ,mv.last_submit_len
        ,mv.last_reject_len
	FROM 
		tabl_prefixplan_monitor_agg AS plan 
	LEFT JOIN 
		tabl_prefixmv_agg_3 AS mv
			ON 
				plan.docid = mv.docid
			AND 
				plan.countryid = mv.countryid
			AND 
				plan.planmvdat = mv.mvdat
;


CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixmv_plan_right AS

	SELECT 
		mv.docid
		,mv.countryid
		,plan.planspid
		,mv.visitid AS planmvtyp
		,plan.planmvid
		,plan.planmvdat
		,plan.planmvdurat
		,plan.planmvendat
		,plan.planmvstat
        ,plan.site_monitors
        ,plan.data_issue_missing_plan_start_date
        ,plan.data_issue_missing_plan_end_date
        ,plan.data_issue_missing_plan_durat
        ,plan.data_issue_incorrect_plan_durat
        ,plan.data_issue_planned_visit_type
        ,plan.data_issue_plan_start_after_end
        ,plan.data_issue_plan_state_date_is_weekend
        ,plan.data_issue_plan_end_date_is_weekend
        ,plan.data_issue_missing_monitor_name
		,mv.visitid
		,mv.mvdat
		,mv.mvendat
		,mv.mvrepname
		,mv.mvseq
		,mv.submitter_name
		,mv.stagesubmittorname
		,mv.first_submission
		,mv.submission_round
		,mv.latest_submission
		,mv.reviewername
		,mv.rejection_round
		,mv.latest_rejection
		,mv.current_stage
		,mv.approval_date
		,mv.stage
        ,mv.total_submit_len
        ,mv.total_cra_time
        ,mv.submission_next
        ,mv.reject_submit
        ,mv.data_issue_missing_first_submittor_name
        ,mv.data_issue_missing_stage_submittor_name
		,mv.data_issue_missing_any_submittor_name
		,mv.data_issue_missing_stage_reviewer_name
		,mv.data_issue_missing_first_submission_date
		,mv.data_issue_missing_approval_date
		,mv.data_issue_missing_date_in_sub_next_pair
		,mv.data_issue_missing_date_in_rej_sub_pair
		,mv.data_issue_wrong_order_of_dates_in_sub_next_pair
		,mv.data_issue_wrong_order_of_dates_in_rej_sub_pair
        ,mv.data_issue_missing_mv_start_date
        ,mv.data_issue_missing_mv_end_date
        ,mv.data_issue_missing_1_submission_stage
        ,mv.data_issue_missing_latest_submission_date
		,mv.data_issue_missing_latest_rejection_date
		,mv.data_issue_mv_start_date_after_mv_end_date
		,mv.data_issue_mv_end_date_after_approval
		,mv.data_issue_mv_end_date_after_first_submission
        ,mv.data_issue_last_submission_date_after_next
		,mv.data_issue_last_rejection_date_after_next
		,mv.data_issue_first_submission_after_latest_rejection
		,mv.data_issue_mv_state_date_is_weekend
        ,mv.data_issue_mv_end_date_is_weekend
		,mv.data_issue_wrong_stage_order
        ,mv.last_submit_len
        ,mv.last_reject_len
	FROM 
		tabl_prefixplan_monitor_agg AS plan 
	RIGHT JOIN 
		tabl_prefixmv_agg_3 AS mv
			ON 
				plan.docid = mv.docid
			AND 
				plan.countryid = mv.countryid
			AND 
				plan.planmvdat = mv.mvdat
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixmv_plan_union AS

	SELECT * FROM tabl_prefixmv_plan_left

	UNION
	
    SELECT * FROM tabl_prefixmv_plan_right
;




/****************************Join site, sites, and study tables*****************************/


DROP TEMPORARY TABLES IF EXISTS

	tabl_prefixsite_sites_study
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixsite_sites_study AS
	
	SELECT DISTINCT
		site.docid
		,site.siteid 
		,CONCAT(site.sitemonfirst,' ',site.sitemonlast) AS monitor_name
		,site.sitemonact
		,site.sitemondeact
		,sites.label AS country
		,study.studyid AS ProtocolNumber
	FROM 
		tabl_prefixsite_2 AS site
	INNER JOIN 
		tabl_prefixsites AS sites
			ON 
				LEFT(site.countryid,3) = LEFT(sites.sitecode,3)
		INNER JOIN 
			tabl_prefixstudy AS study
				ON 
					study.docid = site.docid
	WHERE site.siteid IS NOT NULL
;


/****************************Join site_sites_study table with union of plan and mv table*****************************/


DROP TEMPORARY TABLES IF EXISTS

	tabl_prefixmv_plan_union_sites
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	tabl_prefixmv_plan_union_sites AS

	SELECT DISTINCT
		NULL AS id
		,s.protocolnumber
		,CASE WHEN s.protocolnumber = '3D' THEN '3D'
			WHEN s.protocolnumber = 'ADIASE' THEN 'Ipsen (Adiase) - 185'
			WHEN s.protocolnumber = 'ALLEGRO' THEN 'MS LAQ 301 Extension'
			WHEN s.protocolnumber = 'ALTERNATIVE' THEN 'Novartis (ALTERNATIVE) - 380-29'
			WHEN s.protocolnumber = 'ALTTO' THEN 'Novartis (ALTTO) - 380-27'
			WHEN s.protocolnumber = 'BPS' THEN 'Grunenthal (BPS) - 214'
			WHEN s.protocolnumber = 'BRAVO_EXT' THEN 'MS-LAQ-302E'
			WHEN s.protocolnumber = 'CD2' THEN 'CD2'
			WHEN s.protocolnumber = 'CP-4-006' THEN 'OPKO (CP-4-006) - 205'
			WHEN s.protocolnumber = 'MEK115306' THEN 'Novartis (MEK115306) - 380-36'
			WHEN s.protocolnumber = 'MEK116513' THEN 'Novartis (MEK116513) - 380-31'
			WHEN s.protocolnumber = 'NeoALTTO' THEN 'Novartis (Neo ALTTO) - 380-28'
			WHEN s.protocolnumber = 'NewLink Genetics (NEL) - 168' THEN 'NewLink Genetics (NEL) - 168'
			WHEN s.protocolnumber = 'OLEX2' THEN 'LAQ5063 OL 2'
			WHEN s.protocolnumber = 'PBC' THEN 'Novartis (PBC) - 212'
			WHEN s.protocolnumber = 'PPSP Grunenthal' THEN 'Grunenthal (PPSP) - 171'
			WHEN s.protocolnumber = 'PROLONG' THEN 'Novartis (PROLONG) - 380-30'
			WHEN s.protocolnumber = 'SOLID' THEN 'MacroGenics (SOLID) - 216'
			WHEN s.protocolnumber = 'TAMO' THEN 'Grunenthal (TAMO) - 188'
			ELSE NULL END AS gp_pn
		,'Yes' AS plans_supported
		,s.country
		,REMOVEWHITESPACE(s.siteid)
        ,u.site_monitors
		,CASE WHEN u.planmvtyp = 1 THEN 'Site Initiation Visit Report'
			WHEN u.planmvtyp = 2 THEN 'Monitoring Visit Report'
			WHEN u.planmvtyp = 3 THEN 'Close out Visit Report'
			WHEN u.planmvtyp = 4 THEN 'Pre-Study Visit Report'
			ELSE u.planmvtyp END AS planmvtyp
		,CASE WHEN u.planmvstat = 1 THEN 'Planned'
			WHEN u.planmvstat = 2 THEN 'Completed'
			WHEN u.planmvstat = 3 THEN 'Canceled'
            WHEN u.planmvstat = 9 THEN 'Completed-missing MV'
            WHEN u.planmvstat IS NULL THEN 'Missing plan'
			ELSE u.planmvstat END AS planmvstat
		,u.planmvdat
		,u.planmvendat
		,u.planmvdurat
		,u.mvseq
		,u.mvdat
		,u.mvendat
		,CASE WHEN u.mvdat IS NOT NULL 
			AND u.mvendat IS NOT NULL 
            AND u.mvendat <= u.mvdat
            THEN 1
            WHEN u.mvdat IS NOT NULL 
			AND u.mvendat IS NOT NULL 
            AND u.mvendat > u.mvdat
            THEN countWeekdays(u.mvendat, u.mvdat)
			ELSE NULL END AS calc_mv_len
		,u.mvrepname
		,u.stagesubmittorname
		,u.first_submission
		,CASE WHEN u.first_submission IS NOT NULL
			AND u.mvendat IS NOT NULL 
			AND u.mvendat >= u.first_submission 
            THEN 1
            WHEN u.first_submission IS NOT NULL
			AND u.mvendat IS NOT NULL 
            AND u.mvendat < u.first_submission 
            THEN DATEDIFF(u.first_submission, u.mvendat)
            ELSE NULL END AS calc_mv_2_submit
		,CASE WHEN u.first_submission IS NOT NULL
			AND u.latest_rejection IS NOT NULL
            AND u.latest_rejection <= u.first_submission
            THEN 1
            WHEN u.first_submission IS NOT NULL
			AND u.latest_rejection IS NOT NULL
            AND u.latest_rejection > u.first_submission
            THEN DATEDIFF(u.latest_rejection, u.first_submission)+1
            ELSE NULL END AS calc_submit_2_reject
		,CASE WHEN u.submission_round IS NULL THEN 0 ELSE u.submission_round END AS submission_round
		,u.latest_submission
		,u.last_submit_len
		,u.reviewername
		,CASE WHEN u.rejection_round IS NULL THEN 0 ELSE u.rejection_round END AS rejection_round
		,u.latest_rejection
		,u.last_reject_len
		,CASE WHEN u.planmvstat IN (1,3) THEN NULL ELSE u.current_stage END AS current_stage
		,u.approval_date
		,CASE WHEN u.mvendat IS NOT NULL
			AND u.approval_date IS NOT NULL
            AND u.mvendat >= u.approval_date 
            THEN 1
            WHEN u.mvendat IS NOT NULL
			AND u.approval_date IS NOT NULL
            AND u.mvendat < u.approval_date 
            THEN DATEDIFF(u.approval_date, u.mvendat)
            ELSE NULL END AS calc_mv_2_approve
		,CASE WHEN u.first_submission IS NOT NULL
			AND u.approval_date IS NOT NULL
            AND u.first_submission >= u.approval_date 
            THEN 1
            WHEN u.first_submission IS NOT NULL
			AND u.approval_date IS NOT NULL
            AND u.first_submission < u.approval_date 
            THEN DATEDIFF(u.approval_date, u.first_submission)+1
            ELSE NULL END AS calc_submit_2_approve
		,u.total_submit_len
		,u.total_cra_time
		,CASE WHEN u.stage IS NULL THEN 'NA' ELSE u.stage END as stage
        ,CONCAT_WS(','
			,CASE WHEN data_issue_missing_plan_start_date IS NOT NULL AND data_issue_missing_plan_start_date != 0 THEN 'Missing planned start date' ELSE NULL END
			,CASE WHEN data_issue_missing_plan_end_date IS NOT NULL AND data_issue_missing_plan_end_date != 0 THEN 'Missing planned end date' ELSE NULL END
			,CASE WHEN data_issue_missing_plan_durat IS NOT NULL AND data_issue_missing_plan_durat != 0 THEN 'Missing planned duration' ELSE NULL END
			,CASE WHEN data_issue_incorrect_plan_durat IS NOT NULL AND data_issue_incorrect_plan_durat != 0 THEN 'Incorrect planned duration' ELSE NULL END
			,CASE WHEN data_issue_planned_visit_type IS NOT NULL AND data_issue_planned_visit_type != 0 THEN 'Missing type of a visit' ELSE NULL END
			,CASE WHEN data_issue_plan_start_after_end IS NOT NULL AND data_issue_plan_start_after_end != 0 THEN 'Planned start date > Planned end date' ELSE NULL END
			,CASE WHEN data_issue_plan_state_date_is_weekend IS NOT NULL AND data_issue_plan_state_date_is_weekend != 0 THEN 'Planned start at weekend' ELSE NULL END
			,CASE WHEN data_issue_plan_end_date_is_weekend IS NOT NULL AND data_issue_plan_end_date_is_weekend != 0 THEN 'Planned end at weekend' ELSE NULL END
			,CASE WHEN data_issue_missing_monitor_name IS NOT NULL AND data_issue_missing_monitor_name != 0 THEN 'Missing monitor name' ELSE NULL END
			,CASE WHEN data_issue_missing_first_submittor_name IS NOT NULL AND data_issue_missing_first_submittor_name != 0 THEN 'Missing the main submittor name' ELSE NULL END
			,CASE WHEN data_issue_missing_stage_submittor_name IS NOT NULL AND data_issue_missing_stage_submittor_name != 0 THEN 'Missing stage submittor names' ELSE NULL END
			,CASE WHEN data_issue_missing_any_submittor_name IS NOT NULL AND data_issue_missing_any_submittor_name != 0 THEN 'Missing any possible submittor name' ELSE NULL END
			,CASE WHEN data_issue_missing_stage_reviewer_name IS NOT NULL AND data_issue_missing_stage_reviewer_name != 0 THEN 'Missing stage reviewer names' ELSE NULL END
			,CASE WHEN data_issue_missing_approval_date IS NOT NULL AND data_issue_missing_approval_date != 0 THEN 'Missing approval date' ELSE NULL END
			,CASE WHEN data_issue_missing_date_in_sub_next_pair IS NOT NULL AND data_issue_missing_date_in_sub_next_pair != 0 THEN 'Missing date(s) in pair(s) of stages; Subm-Next' ELSE NULL END
			,CASE WHEN data_issue_missing_date_in_rej_sub_pair IS NOT NULL AND data_issue_missing_date_in_rej_sub_pair != 0 THEN 'Missing date(s) in pair(s) of stages; Rej-Subm' ELSE NULL END
			,CASE WHEN data_issue_wrong_order_of_dates_in_sub_next_pair IS NOT NULL AND data_issue_wrong_order_of_dates_in_sub_next_pair != 0 THEN 'Wrong order of dates in pair(s) of stages; Subm-Next' ELSE NULL END
			,CASE WHEN data_issue_wrong_order_of_dates_in_rej_sub_pair IS NOT NULL AND data_issue_wrong_order_of_dates_in_rej_sub_pair != 0 THEN 'Wrong order of dates in pair(s) of stages; Rej-Subm' ELSE NULL END
			,CASE WHEN data_issue_missing_mv_start_date IS NOT NULL AND data_issue_missing_mv_start_date != 0 THEN 'Missing MV start date' ELSE NULL END
			,CASE WHEN data_issue_missing_mv_end_date IS NOT NULL AND data_issue_missing_mv_end_date != 0 THEN 'Missing MV end date' ELSE NULL END
			,CASE WHEN data_issue_missing_1_submission_stage IS NOT NULL AND data_issue_missing_1_submission_stage != 0 THEN 'Missing at least 1 submission stage' ELSE NULL END
			,CASE WHEN data_issue_missing_first_submission_date IS NOT NULL AND data_issue_missing_first_submission_date != 0 THEN 'Missing 1st submission date' ELSE NULL END
			,CASE WHEN data_issue_missing_latest_submission_date IS NOT NULL AND data_issue_missing_latest_submission_date != 0 THEN 'Missing 1st submission date' ELSE NULL END
			,CASE WHEN data_issue_missing_latest_rejection_date IS NOT NULL AND data_issue_missing_latest_rejection_date != 0 THEN 'Missing latest rejection date' ELSE NULL END
			,CASE WHEN data_issue_mv_start_date_after_mv_end_date IS NOT NULL AND data_issue_mv_start_date_after_mv_end_date != 0 THEN 'Start MV date > End MV date' ELSE NULL END
			,CASE WHEN data_issue_mv_end_date_after_approval IS NOT NULL AND data_issue_mv_end_date_after_approval != 0 THEN 'MV end date > Last approval date' ELSE NULL END
			,CASE WHEN data_issue_mv_end_date_after_first_submission IS NOT NULL AND data_issue_mv_end_date_after_first_submission != 0 THEN 'MV end date > 1st submission date' ELSE NULL END
			,CASE WHEN data_issue_last_submission_date_after_next IS NOT NULL AND data_issue_last_submission_date_after_next != 0 THEN 'Last submission date > next stage date' ELSE NULL END
			,CASE WHEN data_issue_last_rejection_date_after_next IS NOT NULL AND data_issue_last_rejection_date_after_next != 0 THEN 'Last rejection date > next stage date' ELSE NULL END
			,CASE WHEN data_issue_first_submission_after_latest_rejection IS NOT NULL AND data_issue_first_submission_after_latest_rejection != 0 THEN 'Last rejection date > next stage date' ELSE NULL END
			,CASE WHEN data_issue_mv_state_date_is_weekend IS NOT NULL AND data_issue_mv_state_date_is_weekend != 0 THEN 'Actual start at weekend' ELSE NULL END
			,CASE WHEN data_issue_mv_end_date_is_weekend IS NOT NULL AND data_issue_mv_end_date_is_weekend != 0 THEN 'Actual end at weekend' ELSE NULL END
			,CASE WHEN data_issue_wrong_stage_order IS NOT NULL AND data_issue_wrong_stage_order != 0 THEN 'Wrong stage order' ELSE NULL END
		) AS data_issues
		,TRIM(CONCAT_WS(','
			,CASE WHEN u.last_submit_len > 7
				THEN 'Exceeded: Time spent in the latest SUBM' ELSE NULL END
			,CASE WHEN (
				CASE WHEN u.first_submission IS NOT NULL
					AND u.mvendat IS NOT NULL 
					AND u.mvendat >= u.first_submission 
					THEN 1
					WHEN u.first_submission IS NOT NULL
					AND u.mvendat IS NOT NULL 
					AND u.mvendat < u.first_submission 
					THEN DATEDIFF(u.first_submission, u.mvendat)
					ELSE NULL END
				) > 7
            THEN 'Exceeded: Time MV end + 1 → 1st SUBM' ELSE NULL END
            ,CASE WHEN u.last_reject_len > 7
				THEN 'Exceeded: Time spent in the latest REJ' ELSE NULL END
			 ,CASE WHEN (
				CASE WHEN u.mvendat IS NOT NULL
					AND u.approval_date IS NOT NULL
					AND u.mvendat >= u.approval_date 
					THEN 1
					WHEN u.mvendat IS NOT NULL
					AND u.approval_date IS NOT NULL
					AND u.mvendat < u.approval_date 
					THEN DATEDIFF(u.approval_date, u.mvendat)
					ELSE NULL END
				) > 14
			  THEN 'Exceeded: Time MV end + 1 → APPR ' ELSE NULL END
			,CASE WHEN (
					CASE WHEN u.first_submission IS NOT NULL
					AND u.approval_date IS NOT NULL
					AND u.first_submission >= u.approval_date 
					THEN 1
					WHEN u.first_submission IS NOT NULL
					AND u.approval_date IS NOT NULL
					AND u.first_submission < u.approval_date 
					THEN DATEDIFF(u.approval_date, u.first_submission)+1
					ELSE NULL END 
				) > 7 
                THEN 'Exceeded: Time 1st SUBM → APPR' ELSE NULL END
			,CASE WHEN (
					CASE WHEN u.first_submission IS NOT NULL
					AND u.latest_rejection IS NOT NULL
					AND u.latest_rejection <= u.first_submission
					THEN 1
					WHEN u.first_submission IS NOT NULL
					AND u.latest_rejection IS NOT NULL
					AND u.latest_rejection > u.first_submission
					THEN DATEDIFF(u.latest_rejection, u.first_submission)+1
					ELSE NULL END 
				) > 14 
                THEN 'Exceeded: Time 1st SUBM → latest REJ' ELSE NULL END
			,CASE WHEN u.total_submit_len > 14
				THEN 'Exceeded: Time spent in all SUBM' ELSE NULL END
			,CASE WHEN 
				(u.planmvstat = 2 OR u.planmvstat IS NULL)
				AND 
				(u.submission_round = 0 OR u.submission_round IS NULL)
				AND
				DATEDIFF(CURRENT_DATE(),u.mvendat) > 7
			THEN 'Exceeded: Time after MV without a report' ELSE NULL END
            ,CASE WHEN u.total_cra_time > 14
				THEN 'Exceeded: Time spent by CRAs after the 1st SUBM' ELSE NULL END
			,CASE WHEN u.planmvstat = 1 
					AND CURRENT_DATE() > u.planmvendat
				THEN 'Overdue plan' ELSE NULL END
        )) AS process_issues
        ,u.submission_next
        ,u.reject_submit
        ,CONCAT(YEAR(planmvendat),'.',MONTH(planmvendat)) AS period_planned_visit
        ,CONCAT(YEAR(mvendat),'.',MONTH(mvendat)) AS period_performed_visit
        ,CASE WHEN u.planmvstat = 1 THEN 1 ELSE NULL END AS planned_visit
        ,CASE WHEN u.planmvstat = 2
			OR u.planmvstat IS NULL 
            THEN 1 ELSE NULL END AS performed_visit
        ,CASE WHEN (
			CASE WHEN u.first_submission IS NOT NULL
						AND u.mvendat IS NOT NULL 
						AND u.mvendat >= u.first_submission 
					THEN 1
					WHEN u.first_submission IS NOT NULL
						AND u.mvendat IS NOT NULL 
						AND u.mvendat < u.first_submission 
					THEN DATEDIFF(u.first_submission, u.mvendat)
					ELSE NULL END
				) <=7 THEN 1
			WHEN (
				CASE WHEN u.first_submission IS NOT NULL
						AND u.mvendat IS NOT NULL 
						AND u.mvendat >= u.first_submission 
					THEN 1
					WHEN u.first_submission IS NOT NULL
						AND u.mvendat IS NOT NULL 
						AND u.mvendat < u.first_submission 
					THEN DATEDIFF(u.first_submission, u.mvendat)
					ELSE NULL END
				) > 7 THEN 0
            ELSE NULL END AS first_submission_on_time /*if calc_mv_2_submit is <= 7 then 1, if calc_mv_2_submit > 7 then 0*/
        ,CASE WHEN (
			CASE WHEN u.mvendat IS NOT NULL
						AND u.approval_date IS NOT NULL
						AND u.mvendat >= u.approval_date 
					THEN 1
					WHEN u.mvendat IS NOT NULL
						AND u.approval_date IS NOT NULL
						AND u.mvendat < u.approval_date 
					THEN DATEDIFF(u.approval_date, u.mvendat)
					ELSE NULL END
				) <= 14 THEN 1
			WHEN (
				CASE WHEN u.mvendat IS NOT NULL
						AND u.approval_date IS NOT NULL
						AND u.mvendat >= u.approval_date 
					THEN 1
					WHEN u.mvendat IS NOT NULL
						AND u.approval_date IS NOT NULL
						AND u.mvendat < u.approval_date 
					THEN DATEDIFF(u.approval_date, u.mvendat)
					ELSE NULL END
				) > 14 THEN 0
        ELSE NULL END AS finalization_on_time /*if calc_mv_2_approve is <= 14 then 1, if calc_mv_2_approve > 14 then 0*/
	FROM 
		tabl_prefixmv_plan_union AS u
	LEFT JOIN 
		tabl_prefixsite_sites_study AS s
		 	ON 
		 		s.docid = u.docid

;
/****************************data and process issues*****************************/


SELECT * FROM tabl_prefixmv_plan_union_sites;
