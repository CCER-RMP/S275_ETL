
DROP TABLE IF EXISTS Dim_School;

-- next

-- Created by running this in RMP database:
-- there's 53 rows with duplicate schoolcodes b/c of bad data quality;
-- we arbitrarily order by districtcode to de-dupe these
-- WITH T AS (
--     SELECT
--         *
--         ,ROW_NUMBER() OVER (PARTITION BY SchoolCode, AcademicYear
--             ORDER BY DistrictCode) AS Ranked
--     FROM Dim.School
-- )
-- SELECT
--     AcademicYear
--     ,DistrictCode
--     ,DistrictName
--     ,SchoolCode
--     ,SchoolName
--     ,Lat
--     ,Long
--     ,dRoadMapRegionFlag
-- FROM T
-- WHERE Ranked = 1;

CREATE TABLE Dim_School (
    AcademicYear int NOT NULL,
    DistrictCode varchar(8) NULL,
    DistrictName varchar(250) NULL,
    SchoolCode varchar(8) NOT NULL,
    SchoolName varchar(250) NULL,
    Lat real NULL,
    Long real NULL,
    RMRFlag int
);

-- next

CREATE INDEX idx_Dim_School ON Dim_School (
    AcademicYear,
    DistrictCode,
    DistrictName,
    SchoolCode,
    SchoolName,
    RMRFlag
);

-- next

CREATE INDEX idx_Dim_School2 ON Dim_School (
    AcademicYear,
    SchoolCode,
    SchoolName,
    DistrictCode,
    DistrictName,
    RMRFlag
);

