-- we need this table for per-building rolled up fields, can't simply extend Fact_Assignment

DROP TABLE IF EXISTS Fact_SchoolTeacher;

-- next

CREATE TABLE Fact_SchoolTeacher (
    SchoolTeacherID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    StaffID INT NOT NULL,
    AcademicYear INT NOT NULL,
    Building varchar(500) NULL,
    AssignmentPercent NUMERIC(14,4) NULL,
    AssignmentFTEDesignation NUMERIC(14,4) NULL,
    AssignmentSalaryTotal INT NULL,
    PrimaryFlag INT NULL
);

-- next

INSERT INTO Fact_SchoolTeacher (
    StaffID,
    AcademicYear,
    Building,
    AssignmentPercent,
    AssignmentFTEDesignation,
    AssignmentSalaryTotal,
    PrimaryFlag
)
select
    a.StaffID
    ,a.AcademicYear
    ,Building
    ,COALESCE(SUM(AssignmentPercent), 0) AS AssignmentPercent
    ,SUM(AssignmentFTEDesignation) AS AssignmentFTEDesignation
    ,SUM(AssignmentSalaryTotal) AS AssignmentSalaryTotal
    ,0 AS PrimaryFlag
from Fact_Assignment a
JOIN Dim_Staff s ON a.StaffID = s.StaffID
WHERE IsTeachingAssignment = 1
GROUP BY
    a.StaffID
    ,a.AcademicYear
    ,Building
;

-- next

DELETE FROM Fact_SchoolTeacher
WHERE
    EXISTS (
        SELECT 1 from Dim_Staff
        WHERE StaffID = Fact_SchoolTeacher.StaffID
        AND (CertificateNumber IS NULL OR CertificateNumber = '')
    )
    OR AssignmentFTEDesignation IS NULL
    OR AssignmentFTEDesignation <= 0;

-- next

WITH Ranked AS (
    SELECT
        SchoolTeacherID
        ,row_number() OVER (
            PARTITION BY
                st.AcademicYear,
                CertificateNumber
            ORDER BY
                AssignmentFTEDesignation DESC,
                -- tiebreaking below this line
                AssignmentPercent DESC,
                AssignmentSalaryTotal DESC
        ) AS RN
    FROM Fact_SchoolTeacher st
    JOIN Dim_Staff s ON st.StaffID = s.StaffID
)
UPDATE Fact_SchoolTeacher
SET PrimaryFlag = 1
WHERE EXISTS (
    SELECT 1
    FROM Ranked
    WHERE Ranked.SchoolTeacherID = Fact_SchoolTeacher.SchoolTeacherID
    AND RN = 1
);

-- next

CREATE INDEX idx_Fact_SchoolTeacher ON Fact_SchoolTeacher (
    StaffID, AcademicYear
);

-- next

CREATE INDEX idx_Fact_SchoolTeacher2 ON Fact_SchoolTeacher (
    AcademicYear, StaffID
);
