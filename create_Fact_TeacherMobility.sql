
-- Fact_TeacherMobility was designed to reproduce COE's numbers,
-- so it follows their logic very closely. It should probably be kept that way
-- for reference. See Fact_TeacherCohortMobility for a table that's more tailored
-- to analysis by CCER.

-- This logic selects a single teacher/building per year

DROP TABLE IF EXISTS BaseSchoolTeachers;

-- next

CREATE TABLE BaseSchoolTeachers (
    StaffID int not null,
    AcademicYear smallint NOT NULL,
    CertificateNumber varchar(500) NULL,
    CountyAndDistrictCode varchar(500) NULL,
    Building varchar(500) NULL
);

-- next

INSERT INTO BaseSchoolTeachers (
    StaffID,
    AcademicYear,
    CertificateNumber,
    CountyAndDistrictCode,
    Building
)
SELECT
    s.StaffID
    ,t.AcademicYear
    ,CertificateNumber
    ,s.CountyAndDistrictCode
    ,Building
FROM Fact_SchoolTeacher t
JOIN Dim_Staff s
    ON t.StaffID = s.StaffID
WHERE PrimaryFlag = 1;

-- next

-- this doesn't work b/c some staff don't have cert numbers

-- ensure we only have one teacher/district per year
-- CREATE UNIQUE INDEX idx_BaseSchoolTeachers_unique ON BaseSchoolTeachers (
--     AcademicYear,
--     CertificateNumber,
-- );

-- next

CREATE INDEX idx_BaseSchoolTeachers ON BaseSchoolTeachers (
    AcademicYear
    ,CertificateNumber
    ,CountyAndDistrictCode
    ,Building
);

-- next

-- this is table used to determine EndYear fields: we need this to account
-- for teachers who stopped being teachers but are still in the system

DROP TABLE IF EXISTS StaffByBuilding;

-- next

CREATE TABLE StaffByBuilding (
    StaffID int not null,
    AcademicYear smallint NOT NULL,
    CertificateNumber varchar(500) NULL,
    CountyAndDistrictCode varchar(500) NULL,
    Building varchar(500) NULL,
    TeacherFlag INT NULL,
    RN INT NULL
);

-- next

-- FIXME: this rolls up to a building, and hence, more than row for a person/year row,
-- which results multiple rows in the transitions table for a person/year.

-- query assignments here, b/c we want to know if teachers became non-teachers
INSERT INTO StaffByBuilding (
    StaffID,
    AcademicYear,
    CertificateNumber,
    CountyAndDistrictCode,
    Building,
    TeacherFlag,
    RN
)
SELECT
    t.StaffID
    ,t.AcademicYear
    ,CertificateNumber
    ,s.CountyAndDistrictCode
    ,Building
    ,MAX(IsTeachingAssignment) AS TeacherFlag
    ,ROW_NUMBER() OVER (PARTITION BY
        t.AcademicYear,
        CertificateNumber
    ORDER BY
        SUM(AssignmentFTEDesignation) DESC,
        -- tiebreaking below this line
        SUM(AssignmentPercent) DESC,
        SUM(AssignmentSalaryTotal) DESC
    ) as RN
FROM Fact_assignment t
JOIN Dim_Staff s
    ON t.StaffID = s.StaffID
GROUP BY
    t.StaffID
    ,t.AcademicYear
    ,CertificateNumber
    ,s.CountyAndDistrictCode
    ,Building;

-- next

DELETE FROM StaffByBuilding
WHERE RN <> 1;

-- next

CREATE INDEX idx_StaffByBuilding ON StaffByBuilding (
    CertificateNumber
    ,AcademicYear
);

-- next

DROP TABLE IF EXISTS Fact_TeacherMobility;

-- next

CREATE TABLE Fact_TeacherMobility (
    TeacherMobilityID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    StartStaffID int not null,
    EndStaffID int null,
    StartYear smallint NOT NULL,
    EndYear smallint NULL,
    DiffYears smallint NULL,
    CertificateNumber varchar(500) NULL,
    StartCountyAndDistrictCode varchar(500) NULL,
    StartBuilding varchar(500) NULL,
    StartLocale varchar(50) NULL,
    EndCountyAndDistrictCode varchar(500) NULL,
    EndBuilding varchar(500) NULL,
    EndLocale varchar(50) NULL,
    EndTeacherFlag tinyint NULL,
    Distance real NULL,
    RoleChanged tinyint NULL,
    RoleChangedToPrincipal tinyint NULL,
    RoleChangedToAsstPrincipal tinyint NULL,
    Stayer tinyint NOT NULL,
    MovedInBuildingChange tinyint NOT NULL,
    MovedInRoleChange tinyint NOT NULL,
    MovedIn tinyint NOT NULL,
    MovedOut tinyint NOT NULL,
    MovedOutOfRMR tinyint NOT NULL,
    Exited tinyint NOT NULL,
    MetaCreatedAt DATETIME
);

-- next

WITH
YearBrackets AS (
    SELECT DISTINCT
        AcademicYear AS StartYear,
        AcademicYear + 1 AS EndYear
    FROM BaseSchoolTeachers y1
    WHERE EXISTS (
        SELECT 1 FROM BaseSchoolTeachers WHERE AcademicYear = y1.AcademicYear + 1
    )
    UNION ALL
    SELECT DISTINCT
        AcademicYear AS StartYear,
        AcademicYear + 4 AS EndYear
    FROM BaseSchoolTeachers y2
    WHERE EXISTS (
        SELECT 1 FROM BaseSchoolTeachers WHERE AcademicYear = y2.AcademicYear + 4
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
        -- end fields
        t2.CountyAndDistrictCode AS EndCountyAndDistrictCode,
        t2.Building AS EndBuilding,
        t2.TeacherFlag AS EndTeacherFlag
    FROM BaseSchoolTeachers t1
    JOIN YearBrackets y
        ON t1.AcademicYear = y.StartYear
    LEFT JOIN StaffByBuilding t2
        ON t1.CertificateNumber = t2.CertificateNumber
        AND y.EndYear = t2.AcademicYear
)
,TransitionsWithMovedInBase AS (
    SELECT
        *
        ,CASE WHEN
            EndCountyAndDistrictCode IS NOT NULL
            AND EndBuilding IS NOT NULL
            AND StartCountyAndDistrictCode = EndCountyAndDistrictCode
        THEN 1 ELSE 0 END AS StayedInDistrict
    FROM TransitionsBase
)
,Transitions AS (
    SELECT
        t.*
        ,s1.NCESLocale AS StartLocale
        ,s2.NCESLocale AS EndLocale
        ,CASE WHEN EndTeacherFlag = 0 THEN 1 ELSE 0 END AS RoleChanged
        -- MovedInBuildingChange and MovedInRoleChange are components of MovedIn
        ,CASE WHEN
            StayedInDistrict = 1
            -- there are a handful of 'ELE' building codes, so coalesce to string, not int
            AND COALESCE(StartBuilding, 'NONE') <> COALESCE(EndBuilding, 'NONE')
        THEN 1 ELSE 0 END AS MovedInBuildingChange
        ,CASE WHEN
            StayedInDistrict = 1
            AND EndTeacherFlag = 0
        THEN 1 ELSE 0 END AS MovedInRoleChange
    FROM TransitionsWithMovedInBase t
    LEFT JOIN Dim_School s1
        ON t.StartBuilding = s1.SchoolCode
        AND t.StartYear = s1.AcademicYear
    LEFT JOIN Dim_School s2
        ON t.EndBuilding = s2.SchoolCode
        AND t.EndYear = s2.AcademicYear
)
INSERT INTO Fact_TeacherMobility (
    StartStaffID,
    EndStaffID,
    StartYear,
    EndYear,
    DiffYears,
    CertificateNumber,
    StartCountyAndDistrictCode,
    StartBuilding,
    StartLocale,
    EndCountyAndDistrictCode,
    EndBuilding,
    EndLocale,
    EndTeacherFlag,
    RoleChanged,
    Stayer,
    MovedInBuildingChange,
    MovedInRoleChange,
    MovedIn,
    MovedOut,
    MovedOutOfRMR,
    Exited,
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
    ,StartLocale
    ,EndCountyAndDistrictCode
    ,EndBuilding
    ,EndLocale
    ,EndTeacherFlag
    ,RoleChanged
    ,CASE WHEN
        EndCountyAndDistrictCode IS NOT NULL
        AND StartCountyAndDistrictCode = EndCountyAndDistrictCode
        AND StartBuilding = EndBuilding
        AND EndTeacherFlag = 1
    THEN 1 ELSE 0 END AS Stayer
    ,MovedInBuildingChange
    ,MovedInRoleChange
    ,CASE WHEN
        MovedInBuildingChange = 1 OR MovedInRoleChange = 1
    THEN 1 ELSE 0 END AS MovedIn
    ,CASE WHEN
        EndCountyAndDistrictCode IS NOT NULL
        AND EndBuilding IS NOT NULL
        AND COALESCE(StartCountyAndDistrictCode, -1) <> COALESCE(EndCountyAndDistrictCode, -1)
    THEN 1 ELSE 0 END AS MovedOut
    ,0 AS MovedOutOfRMR
    ,CASE WHEN
        EndBuilding IS NULL
    THEN 1 ELSE 0 END AS Exited
    ,GETDATE() as MetaCreatedAt
FROM Transitions;

-- next

UPDATE Fact_TeacherMobility
SET MovedOutOfRMR = CASE
    WHEN MovedOut = 1
        AND EXISTS (
            SELECT 1
            FROM Dim_School
            WHERE
                Fact_TeacherMobility.StartYear = AcademicYear
                AND Fact_TeacherMobility.StartBuilding = SchoolCode
            AND RMRFlag = 1
            )
        AND NOT EXISTS (
            SELECT 1
            FROM Dim_School
            WHERE
                Fact_TeacherMobility.EndYear = AcademicYear
                AND Fact_TeacherMobility.EndBuilding = SchoolCode
            AND RMRFlag = 1
            )
    THEN 1
    ELSE 0
    END;

-- next

DROP TABLE IF EXISTS PrincipalsLookup;

-- next

CREATE TABLE PrincipalsLookup (
    PrincipalType varchar(50),
    StaffID int,
    PRIMARY KEY (PrincipalType, StaffID)
);

-- next

INSERT INTO PrincipalsLookup
SELECT DISTINCT
    PrincipalType
    ,StaffID
FROM Fact_SchoolPrincipal;

-- next

UPDATE Fact_TeacherMobility
SET
    RoleChangedToPrincipal = CASE
        WHEN EXISTS (
            SELECT 1
            FROM PrincipalsLookup p
            WHERE
                p.PrincipalType = 'Principal'
                AND p.StaffID = Fact_TeacherMobility.EndStaffID
        )
        THEN 1
        ELSE 0
    END
    ,RoleChangedToAsstPrincipal = CASE
        WHEN EXISTS (
            SELECT 1
            FROM PrincipalsLookup p
            WHERE
                p.PrincipalType = 'AssistantPrincipal'
                AND p.StaffID = Fact_TeacherMobility.EndStaffID
        )
        THEN 1
        ELSE 0
    END
;

-- next

CREATE INDEX idx_Fact_TeacherMobility ON Fact_TeacherMobility(StartStaffID, EndStaffID);

-- next

CREATE INDEX idx_Fact_TeacherMobility2 ON Fact_TeacherMobility(StartYear, StartCountyAndDistrictCode, StartBuilding);

-- next

-- cleanup
DROP TABLE BaseSchoolTeachers;

-- next

DROP TABLE PrincipalsLookup;
