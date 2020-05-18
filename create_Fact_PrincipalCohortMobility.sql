
DROP TABLE IF EXISTS Fact_PrincipalCohortMobility;

-- next

CREATE TABLE Fact_PrincipalCohortMobility (
	CohortYear                    smallint          NOT   NULL,
	CohortStaffID                 int          NOT   NULL,
	CertificateNumber             varchar(500) NOT NULL,
	CohortCountyAndDistrictCode   varchar(500) NULL,
	CohortBuilding                varchar(500) NULL,
	CohortPrincipalType           varchar(500) NULL,
	EndStaffID                    int          NULL,
	EndYear                       smallint          NOT NULL,
	EndHighestFTECountyAndDistrictCode  varchar(500) NULL,
	EndHighestFTEBuilding         varchar(500) NULL,
	EndPrincipalType              varchar(500) NULL,
	StayedInSchool                tinyint          NOT   NULL,
	ChangedBuildingStayedDistrict tinyint          NOT   NULL,
	ChangedRoleStayedDistrict     tinyint          NOT   NULL,
	MovedOutDistrict              tinyint          NOT   NULL,
	Exited                        tinyint          NOT   NULL,
	MetaCreatedAt                 DATETIME,
	PRIMARY KEY (CohortYear, EndYear, CertificateNumber)
);

-- next

INSERT INTO Fact_PrincipalCohortMobility
SELECT
        pc.CohortYear
        ,pc.CohortStaffID
		,pc.CertificateNumber
        ,pc.CohortCountyAndDistrictCode
		,pc.CohortBuilding
		,pc.CohortPrincipalType
        ,a.EndStaffID
		,a.EndYear
        ,a.EndHighestFTECountyAndDistrictCode
        ,a.EndHighestFTEBuilding
        ,a.EndPrincipalType
        ,CASE WHEN CohortBuilding = EndHighestFTEBuilding THEN 1 ELSE 0 END AS StayedInSchool
        ,CASE WHEN CohortBuilding <> EndHighestFTEBuilding AND CohortCountyAndDistrictCode = EndHighestFTECountyAndDistrictCode AND pc.CohortPrincipalType = a.EndPrincipalType THEN 1 ELSE 0 END AS ChangedBuildingStayedDistrict
        ,CASE WHEN CohortBuilding <> EndHighestFTEBuilding AND CohortCountyAndDistrictCode = EndHighestFTECountyAndDistrictCode AND pc.CohortPrincipalType <> COALESCE(a.EndPrincipalType, '') THEN 1 ELSE 0 END AS ChangedRoleStayedDistrict
        ,CASE WHEN CohortCountyAndDistrictCode <> EndHighestFTECountyAndDistrictCode THEN 1 ELSE 0 END AS MovedOutDistrict
        ,Exited
        ,GETDATE() as MetaCreatedAt
FROM Fact_PrincipalCohort pc
JOIN Fact_PrincipalMobility a
	ON pc.CertificateNumber = a.CertificateNumber
WHERE
	-- take only the single year changes
	a.DiffYears = 1
	AND a.StartYear >= pc.CohortYear

-- next

-- ensure full representation of every CohortYear + EndYear combo for each principal:
-- creating rows for missing EndYears (people who no longer appear in S275 and are thus considered exited)

INSERT INTO Fact_PrincipalCohortMobility
SELECT
        pc.CohortYear
        ,pc.CohortStaffID
		,pc.CertificateNumber
        ,pc.CohortCountyAndDistrictCode
		,pc.CohortBuilding
		,pc.CohortPrincipalType
        ,NULL as EndStaffID
		,y.AcademicYear as EndYear
        ,NULL AS EndHighestFTECountyAndDistrictCode
        ,NULL AS EndHighestFTEBuilding
        ,NULL AS EndPrincipalType
        ,0 AS StayedInSchool
        ,0 AS ChangedBuildingStayedDistrict
        ,0 AS ChangedRoleStayedDistrict
        ,0 AS MovedOutDistrict
        ,1 AS Exited
        ,GETDATE() as MetaCreatedAt
FROM Fact_PrincipalCohort pc
CROSS JOIN
(
	SELECT DISTINCT
		AcademicYear
	FROM Dim_Staff
) AS y
WHERE
	y.AcademicYear > pc.CohortYear
	AND NOT EXISTS (
		SELECT 1
		FROM Fact_PrincipalCohortMobility exists_
		WHERE
			exists_.CohortYear = pc.CohortYear
			AND exists_.EndYear = y.AcademicYear
			AND exists_.CertificateNumber = pc.CertificateNumber
	);

-- validation: this should return 0 rows
-- select top 1000 * 
-- from Fact_TeacherCohortMobility
-- where
-- 	StayedInSchool = 0
-- 	and ChangedBuildingStayedDistrict = 0
-- 	and ChangedRoleStayedDistrict = 0
-- 	and MovedOutDistrict = 0
-- 	and Exited = 0 