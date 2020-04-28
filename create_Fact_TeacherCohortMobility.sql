
DROP TABLE IF EXISTS Fact_TeacherCohortMobility;

-- next

CREATE TABLE Fact_TeacherCohortMobility (
	CohortYear                    smallint          NOT   NULL,
	CohortStaffID                 int          NOT   NULL,
	CertificateNumber             varchar(500) NULL,
	CohortCountyAndDistrictCode   varchar(500) NULL,
	CohortBuilding                varchar(500) NULL,
	EndStaffID                    int          NULL,
	EndYear                       smallint          NULL,
	EndCountyAndDistrictCode      varchar(500) NULL,
	EndBuilding                   varchar(500) NULL,
	StayedInSchool                tinyint          NOT   NULL,
	ChangedBuildingStayedDistrict tinyint          NOT   NULL,
	ChangedRoleStayedDistrict     tinyint          NOT   NULL,
	MovedOutDistrict              tinyint          NOT   NULL,
	Exited                        tinyint          NOT   NULL,
	MetaCreatedAt                 DATETIME
);

-- next

INSERT INTO Fact_TeacherCohortMobility
SELECT
        tc.CohortYear
        ,tc.CohortStaffID
		,tc.CertificateNumber
        ,tc.CohortCountyAndDistrictCode
		,tc.CohortBuilding
        ,a.EndStaffID
		,a.EndYear
        ,a.EndCountyAndDistrictCode
        ,a.EndBuilding
        ,StayedInSchool = CASE WHEN CohortBuilding = EndBuilding THEN 1 ELSE 0 END
        -- people who stayed in district (may or may not be same building) and stayed teachers
        --,StayedInDistrict = CASE WHEN CohortCountyAndDistrictCode = EndCountyAndDistrictCode AND a.EndTeacherFlag = 1 THEN 1 ELSE 0 END -- may be in the same building
        ,ChangedBuildingStayedDistrict = CASE WHEN CohortBuilding <> EndBuilding AND CohortCountyAndDistrictCode = EndCountyAndDistrictCode AND a.EndTeacherFlag = 1 THEN 1 ELSE 0 END -- definitely not in the same building 
        ,ChangedRoleStayedDistrict = CASE WHEN CohortBuilding <> EndBuilding AND CohortCountyAndDistrictCode = EndCountyAndDistrictCode AND a.EndTeacherFlag = 0 THEN 1 ELSE 0 END -- definitely not in the same building
        ,MovedOutDistrict = CASE WHEN CohortCountyAndDistrictCode <> EndCountyAndDistrictCode THEN 1 ELSE 0 END
        ,Exited 
        ,GETDATE() as MetaCreatedAt
FROM Fact_TeacherCohort tc
JOIN Fact_TeacherMobility a
	ON tc.CertificateNumber = a.CertificateNumber
WHERE
	-- take only the single year changes
	a.DiffYears = 1
	AND a.StartYear >= tc.CohortYear


-- validation: this should return 0 rows
-- select top 1000 * 
-- from Fact_TeacherCohortMobility
-- where
-- 	StayedInSchool = 0
-- 	and ChangedBuildingStayedDistrict = 0
-- 	and ChangedRoleStayedDistrict = 0
-- 	and MovedOutDistrict = 0
-- 	and Exited = 0 
