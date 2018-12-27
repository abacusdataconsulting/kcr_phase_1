/********Query to identify relevant prefixes and define which query corresponds to each********/



/*****Collect relevant prefixes*****/

DROP TEMPORARY TABLES IF EXISTS 

	prefixes
;

CREATE TEMPORARY TABLE IF NOT EXISTS 
	
    prefixes AS 

	SELECT LEFT(TABLE_NAME,LENGTH(TABLE_NAME)-2) AS prefix
	FROM information_schema.tables
	WHERE TABLE_SCHEMA = 'kcrt14002_kcr-ctms'AND TABLE_NAME LIKE 
		'repdata%mv'
        
        UNION  
        
	SELECT LEFT(TABLE_NAME,LENGTH(TABLE_NAME)-4) AS prefix
	FROM information_schema.tables
	WHERE TABLE_SCHEMA = 'kcrt14002_kcr-ctms' AND TABLE_NAME LIKE 
		'repdata%plan'
        
		UNION
        
	SELECT LEFT(TABLE_NAME,LENGTH(TABLE_NAME)-5) AS prefix
	FROM information_schema.tables
	WHERE TABLE_SCHEMA = 'kcrt14002_kcr-ctms'AND TABLE_NAME LIKE 
		'repdata%sites'
        
        UNION
	
    SELECT LEFT(TABLE_NAME,LENGTH(TABLE_NAME)-4) AS prefix
	FROM information_schema.tables
	WHERE TABLE_SCHEMA = 'kcrt14002_kcr-ctms' AND TABLE_NAME LIKE 
		'repdata%site'
        
        UNION
        
	SELECT LEFT(TABLE_NAME,LENGTH(TABLE_NAME)-5) AS prefix
	FROM information_schema.tables
	WHERE TABLE_SCHEMA = 'kcrt14002_kcr-ctms' AND TABLE_NAME LIKE 
		'repdata%study'
;


/*****Check columns for each prefixes*****/


DROP TEMPORARY TABLES IF EXISTS

	mv_count
    ,plan_count
    ,site_count
    ,sites_count
    ,study_count
;
    
CREATE TEMPORARY TABLE IF NOT EXISTS 

	mv_count AS
		
	SELECT 
		p.prefix
		,COUNT(mv.COLUMN_NAME) AS mv_cols 
		,SUM(CASE WHEN mv.COLUMN_NAME = 'dayid' THEN 1 ELSE 0 END) AS mv_dayid
		,SUM(CASE WHEN mv.COLUMN_NAME = 'mvdate2' THEN 1 ELSE 0 END) AS mv_mvdate2
	FROM 
		prefixes AS p
			LEFT JOIN 
				information_schema.columns AS mv
					ON 
						CONCAT(p.prefix,'mv') = mv.TABLE_NAME
					AND mv.COLUMN_NAME 
						IN ('docid'
							,'sitecounter'
							,'countryid'
							,'visitid'
							,'approvalid'
							,'mvseq'
							,'dayid'
							,'username'
							,'user_full_name'
							,'mvperf'
							,'mvrepname'
							,'mvdat'
							,'approvalstage'
							,'approvaldat'
							,'approvalname'
							,'appdurat'
							,'mvmultiday'
							,'mvdate2'
							,'record_status'
							)
	GROUP BY p.prefix
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	plan_count AS
		
	SELECT 
		p.prefix
		,COUNT(plan.COLUMN_NAME) AS plan_cols 
		,SUM(CASE WHEN plan.COLUMN_NAME = 'planmvtyp' THEN 1 ELSE 0 END) AS plan_planmvtyp
	FROM 
		prefixes AS p
			LEFT JOIN 
				information_schema.columns AS plan
					ON 
						CONCAT(p.prefix,'plan') = plan.TABLE_NAME
					AND plan.COLUMN_NAME 
						IN ('docid'
						,'countryid'
						,'planspid'
						,'planmvtyp'
						,'planmvid'
						,'planmvdat'
						,'planmvdurat'
						,'planmvendat'
						,'planmvstat'
						,'record_status'
						)
	GROUP BY p.prefix
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	site_count AS
		
	SELECT 
		p.prefix
		,COUNT(site.COLUMN_NAME) AS site_cols 
	FROM 
		prefixes AS p
			LEFT JOIN 
				information_schema.columns AS site
					ON 
						CONCAT(p.prefix,'site') = site.TABLE_NAME
					AND site.COLUMN_NAME 
						IN ('docid'
							,'siteid' 
							,'sitemonfirst'
							,'sitemonlast'
							,'sitemonact'
							,'sitemondeact'
							,'countryid'
							,'record_status'
						)
	GROUP BY p.prefix
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	sites_count AS
		
	SELECT 
		p.prefix
		,COUNT(sites.COLUMN_NAME) AS sites_cols 
	FROM 
		prefixes AS p
			LEFT JOIN 
				information_schema.columns AS sites
					ON 
						CONCAT(p.prefix,'sites') = sites.TABLE_NAME
					AND sites.COLUMN_NAME 
						IN ('label'
							,'sitecode'
						)
	GROUP BY p.prefix
;

CREATE TEMPORARY TABLE IF NOT EXISTS 

	study_count AS
		
	SELECT 
		p.prefix
		,COUNT(study.COLUMN_NAME) AS study_cols 
	FROM 
		prefixes AS p
			LEFT JOIN 
				information_schema.columns AS study
					ON 
						CONCAT(p.prefix,'study') = study.TABLE_NAME
					AND study.COLUMN_NAME 
						IN ('studyid'
							,'docid'
						)
	GROUP BY p.prefix
;


/********Make one table with prefix and counts of relevant columns*********/

DROP TEMPORARY TABLES IF EXISTS 
	
    prefix_columns
;

CREATE TEMPORARY TABLE IF NOT EXISTS 
	
    prefix_columns AS 

	SELECT 
		p.prefix 
		,mv.mv_cols
		,mv.mv_dayid
		,mv.mv_mvdate2
		,plan.plan_cols
		,plan.plan_planmvtyp
		,site.site_cols
		,sites.sites_cols
		,study.study_cols
	FROM 
		prefixes AS p
			LEFT JOIN 
				mv_count AS mv
					ON 
						p.prefix = mv.prefix
			LEFT JOIN 
				plan_count AS plan
					ON 
						p.prefix = plan.prefix
			LEFT JOIN 
				site_count AS site
					ON 
						p.prefix = site.prefix
			LEFT JOIN 
				sites_count AS sites
					ON 
						p.prefix = sites.prefix
			LEFT JOIN 
				study_count AS study
					ON 
						p.prefix = study.prefix
;



/********Match prefixes with corresponding query based on table structure*********/

DROP TEMPORARY TABLE IF EXISTS 
	
    prefix_query
;

CREATE TEMPORARY TABLE IF NOT EXISTS 
	
    prefix_query AS

	SELECT 
		prefix
		,CASE 
			WHEN 
				mv_cols = 19 
				AND plan_cols = 10
				AND site_cols = 8
				AND sites_cols = 2
				AND study_cols = 2
			THEN 1
			WHEN 			
				mv_cols = 19 
				AND plan_cols = 9
				AND plan_planmvtyp = 0
				AND site_cols = 8
				AND sites_cols = 2
				AND study_cols = 2
			THEN 2
			WHEN 			
				mv_cols = 17
				AND mv_dayid = 0
				AND mv_mvdate2 = 0
				AND plan_cols = 10
				AND site_cols = 8
				AND sites_cols = 2
				AND study_cols = 2
			THEN 3
			WHEN 
				mv_cols = 17
				AND mv_dayid = 0
				AND mv_mvdate2 = 0
				AND plan_cols = 9
				AND plan_planmvtyp = 0
				AND site_cols = 8
				AND sites_cols = 2
				AND study_cols = 2
			THEN 4 
			ELSE 0 END 
		AS query_number
	FROM  prefix_columns;

SELECT * FROM prefix_query;
