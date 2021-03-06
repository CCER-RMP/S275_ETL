
-- Fact_TeacherCohortMobility was designed to support analysis by CCER;
-- as such, the logic for the transition fields differ somewhat from
-- Fact_TeacherMobility, which was built to reproduce COE's work.
--
-- Note that Fact_TeacherCohortMobility contains every possible combination
-- of CohortYear + EndYEar, which is a superset of the rows found in
-- Fact_TeacherMobility.

{{
    config({
        "pre-hook": [
            "{{ drop_index(1) }}"
        ]
        ,"post-hook": [
            "{{ create_index(1, ['CohortYear', 'EndYear', 'CertificateNumber'], unique=True) }}"
        ]
    })
}}

SELECT
    CohortYear
    ,CohortStaffID
    ,CertificateNumber
    ,CohortCountyAndDistrictCode
    ,CohortBuilding
    ,EndStaffID
    ,EndYear
    ,EndCountyAndDistrictCode
    ,EndBuilding
    ,StayedInSchool
    ,ChangedBuildingStayedDistrict
    ,ChangedRoleStayedDistrict
    ,MovedOutDistrict
    ,Exited
    ,{{ getdate_fn() }} as MetaCreatedAt
FROM {{ ref('Stg_TeacherCohortMobility_Base') }}

UNION ALL

-- ensure full representation of every CohortYear + EndYear combo for each teacher:
-- creating rows for missing EndYears (people who no longer appear in S275 and are thus considered exited)
SELECT
        tc.CohortYear
        ,tc.CohortStaffID
        ,tc.CertificateNumber
        ,tc.CohortCountyAndDistrictCode
        ,tc.CohortBuilding
        ,NULL as EndStaffID
        ,y.AcademicYear as EndYear
        ,NULL AS EndCountyAndDistrictCode
        ,NULL AS EndBuilding
        ,0 AS StayedInSchool
        ,0 AS ChangedBuildingStayedDistrict
        ,0 AS ChangedRoleStayedDistrict
        ,0 AS MovedOutDistrict
        ,1 AS Exited
        ,{{ getdate_fn() }} as MetaCreatedAt
FROM {{ ref('Fact_TeacherCohort') }} tc
CROSS JOIN
(
    SELECT DISTINCT
        AcademicYear
    FROM {{ ref('Dim_Staff') }}
) AS y
WHERE
    y.AcademicYear > tc.CohortYear
    AND NOT EXISTS (
        SELECT 1
        FROM {{ ref('Stg_TeacherCohortMobility_Base') }} exists_
        WHERE
            exists_.CohortYear = tc.CohortYear
            AND exists_.EndYear = y.AcademicYear
            AND exists_.CertificateNumber = tc.CertificateNumber
    )
