
-- This logic selects a single principal (either 'main' principal or Asst Principal)/building per year

DROP TABLE IF EXISTS BaseSchoolPrincipals;

-- next

CREATE TABLE BaseSchoolPrincipals (
    StaffID int not null,
    AcademicYear smallint NOT NULL,
    CertificateNumber varchar(500) NULL,
    CountyAndDistrictCode varchar(500) NULL,
    Building varchar(500) NULL,
    PrincipalType varchar(50) NULL
);

-- next

INSERT INTO BaseSchoolPrincipals (
    StaffID,
    AcademicYear,
    CertificateNumber,
    CountyAndDistrictCode,
    Building,
    PrincipalType
)
SELECT
    sp.StaffID,
    sp.AcademicYear,
    CertificateNumber,
    sp.CountyAndDistrictCode,
    Building,
    PrincipalType
FROM Fact_SchoolPrincipal sp
JOIN Dim_Staff s
    ON sp.StaffID = s.StaffID
    WHERE PrimaryFlag = 1;

-- next

CREATE INDEX idx_BaseSchoolPrincipals ON BaseSchoolPrincipals (
    AcademicYear
    ,CountyAndDistrictCode
    ,Building
);

-- next

DROP TABLE IF EXISTS StaffByHighestFTE;

-- next

CREATE TABLE StaffByHighestFTE (
    StaffID int not null,
    AcademicYear smallint NOT NULL,
    CertificateNumber varchar(500) NULL,
    CountyAndDistrictCode varchar(500) NULL,
    Building varchar(500) NULL,
    DutyRoot varchar(2) NULL
);

-- next

-- do selection to create one row per cert/year
-- picking the highest assignment FTE, used to calculate the location of endyear
WITH T AS (
    SELECT
        t.StaffID
        ,t.AcademicYear
        ,CertificateNumber
        ,s.CountyAndDistrictCode
        ,Building
        ,ROW_NUMBER() OVER (PARTITION BY
            t.AcademicYear,
            CertificateNumber
        ORDER BY
            AssignmentFTEDesignation DESC,
            -- tiebreaking below this line
            AssignmentPercent DESC,
            AssignmentSalaryTotal DESC
        ) as RN
    FROM Fact_assignment t
    JOIN Dim_Staff s
        ON t.StaffID = s.StaffID
)
INSERT INTO StaffByHighestFTE (
    StaffID,
    AcademicYear,
    CertificateNumber,
    CountyAndDistrictCode,
    Building
)
SELECT
    StaffID
    ,AcademicYear
    ,CertificateNumber
    ,CountyAndDistrictCode
    ,Building
FROM T
WHERE RN = 1;

-- next

CREATE INDEX idx_StaffByHighestFTE ON StaffByHighestFTE (
    CertificateNumber
    ,AcademicYear
);

-- next

DROP TABLE IF EXISTS Fact_PrincipalMobility;

-- next

CREATE TABLE Fact_PrincipalMobility (
    StartStaffID int not null,
    EndStaffID int null,
    StartYear smallint NOT NULL,
    EndYear smallint NULL,
    DiffYears smallint NULL,
    CertificateNumber varchar(500) NULL,
    StartCountyAndDistrictCode varchar(500) NULL,
    StartBuilding varchar(500) NULL,
    StartPrincipalType varchar(50) NULL,
    EndStaffByHighestFTECountyAndDistrictCode varchar(500) NULL,
    EndStaffByHighestFTEBuilding varchar(500) NULL,
    EndPrincipalType varchar(50) NULL,
    Stayer tinyint NOT NULL,
    MovedIn tinyint NOT NULL,
    MovedOut tinyint NOT NULL,
    MovedOutOfRMR tinyint NOT NULL,
    Exited tinyint NOT NULL,
    SameAssignment tinyint NOT NULL,
    NoLongerAnyPrincipal tinyint NOT NULL,
    AsstToPrincipal tinyint NOT NULL,
    PrincipalToAsst tinyint NOT NULL,
    MetaCreatedAt DATETIME
);

-- next

WITH
YearBrackets AS (
    SELECT DISTINCT
        AcademicYear AS StartYear,
        AcademicYear + 1 AS EndYear
    FROM BaseSchoolPrincipals y1
    WHERE EXISTS (
        SELECT 1 FROM BaseSchoolPrincipals WHERE AcademicYear = y1.AcademicYear + 1
    )
    UNION ALL
    SELECT DISTINCT
        AcademicYear AS StartYear,
        AcademicYear + 4 AS EndYear
    FROM BaseSchoolPrincipals y2
    WHERE EXISTS (
        SELECT 1 FROM BaseSchoolPrincipals WHERE AcademicYear = y2.AcademicYear + 4
    )
)
,TransitionsBase AS (
    SELECT
        t1.StaffID AS StartStaffID,
        t2.StaffID AS EndStaffID,
        t1.AcademicYear AS StartYear,
        y.EndYear AS EndYear,
        y.EndYear - t1.AcademicYear AS DiffYears,
        t1.CertificateNumber,
        -- start fields
        t1.CountyAndDistrictCode AS StartCountyAndDistrictCode,
        t1.Building AS StartBuilding,
        t1.PrincipalType AS StartPrincipalType,
        -- end fields, using StaffByHighestFTE
        t2.CountyAndDistrictCode AS EndStaffByHighestFTECountyAndDistrictCode,
        t2.Building AS EndStaffByHighestFTEBuilding,
        t2.DutyRoot AS EndStaffByHighestFTEDutyRoot,
        -- end fields, using principals table
        t3.PrincipalType AS EndPrincipalType,
        -- avoid counting exiters by checking for join to a StaffByHighestFTE row to ensure they're still employed somehow;
        -- if join didn't match anything in BaseSchoolPrincipals, then person isn't a Principal or AP in endyear
        CASE WHEN t2.CertificateNumber IS NOT NULL AND t3.CertificateNumber IS NULL THEN 1 ELSE 0 END AS NoLongerAnyPrincipal
    FROM BaseSchoolPrincipals t1
    JOIN YearBrackets y
        ON t1.AcademicYear = y.StartYear
    -- join to a wide set of staff/yr/highest duty root
    LEFT JOIN StaffByHighestFTE t2
        ON t1.CertificateNumber = t2.CertificateNumber
        AND y.EndYear = t2.AcademicYear
    -- join to a set of principals
    LEFT JOIN BaseSchoolPrincipals t3
        ON t1.CertificateNumber = t3.CertificateNumber
        AND y.EndYear = t3.AcademicYear
)
,Transitions AS (
    SELECT
        *
        -- mobility for principals is based strictly on location
        ,CASE WHEN StartBuilding = EndStaffByHighestFTEBuilding THEN 1 ELSE 0 END as Stayer
        ,CASE WHEN
            StartBuilding <> EndStaffByHighestFTEBuilding AND StartCountyAndDistrictCode = EndStaffByHighestFTECountyAndDistrictCode
        THEN 1 ELSE 0 END as MovedIn
        ,CASE WHEN
            StartCountyAndDistrictCode <> EndStaffByHighestFTECountyAndDistrictCode
        THEN 1 ELSE 0 END as MovedOut
        ,CASE WHEN
            EndStaffByHighestFTEBuilding IS NULL
        THEN 1 ELSE 0 END AS Exited
        ,CASE WHEN StartPrincipalType = EndPrincipalType THEN 1 ELSE 0 END AS SameAssignment
        ,CASE
            WHEN StartPrincipalType = 'AssistantPrincipal' AND EndPrincipalType = 'Principal'
        THEN 1 ELSE 0 END AS AsstToPrincipal
        ,CASE
            WHEN StartPrincipalType = 'Principal' AND EndPrincipalType = 'AssistantPrincipal'
        THEN 1 ELSE 0 END AS PrincipalToAsst
    FROM TransitionsBase
)
INSERT INTO Fact_PrincipalMobility (
    StartStaffID,
    EndStaffID,
    StartYear,
    EndYear,
    DiffYears,
    CertificateNumber,
    StartCountyAndDistrictCode,
    StartBuilding,
    StartPrincipalType,
    EndStaffByHighestFTECountyAndDistrictCode,
    EndStaffByHighestFTEBuilding,
    EndPrincipalType,
    Stayer,
    MovedIn,
    MovedOut,
    MovedOutOfRMR,
    Exited,
    SameAssignment,
    NoLongerAnyPrincipal,
    AsstToPrincipal,
    PrincipalToAsst,
    MetaCreatedAt
)
SELECT
    StartStaffID
    ,EndStaffID
    ,StartYear
    ,EndYear
    ,DiffYears
    ,CertificateNumber
    ,StartCountyAndDistrictCode
    ,StartBuilding
    ,StartPrincipalType
    ,EndStaffByHighestFTECountyAndDistrictCode
    ,EndStaffByHighestFTEBuilding
    ,EndPrincipalType
    ,Stayer
    ,MovedIn
    ,MovedOut
    ,0 AS MovedOutOfRMR
    ,Exited
    ,SameAssignment
    ,NoLongerAnyPrincipal
    ,AsstToPrincipal
    ,PrincipalToAsst
    ,GETDATE() as MetaCreatedAt
FROM Transitions;

-- next

UPDATE Fact_PrincipalMobility
SET MovedOutOfRMR = CASE
    WHEN MovedOut = 1
        AND EXISTS (
            SELECT 1
            FROM Dim_School
            WHERE
                Fact_PrincipalMobility.StartYear = AcademicYear
                AND Fact_PrincipalMobility.StartBuilding = SchoolCode
            AND RMRFlag = 1
            )
        AND NOT EXISTS (
            SELECT 1
            FROM Dim_School
            WHERE
                Fact_PrincipalMobility.EndYear = AcademicYear
                AND Fact_PrincipalMobility.EndStaffByHighestFTEBuilding = SchoolCode
            AND RMRFlag = 1
            )
    THEN 1
    ELSE 0
    END;

-- next

CREATE INDEX idx_Fact_PrincipalMobility ON Fact_PrincipalMobility(StartStaffID, EndStaffID);

-- next

CREATE INDEX idx_Fact_PrincipalMobility2 ON Fact_PrincipalMobility(StartYear, StartCountyAndDistrictCode, StartBuilding);

-- next

-- cleanup
DROP TABLE BaseSchoolPrincipals;
