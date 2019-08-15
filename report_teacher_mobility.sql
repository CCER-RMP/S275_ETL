
----------------------------------
-- Teacher demographics for 1996 vs 2018
----------------------------------

With Counts as (
	SELECT
		st.AcademicYear,
		SUM(CASE WHEN Sex = 'M' THEN 1 ELSE 0 END) AS Male,
		SUM(CASE WHEN Sex = 'F' THEN 1 ELSE 0 END) AS Female,
		SUM(CASE WHEN HighestDegree = 'B' THEN 1 ELSE 0 END) AS EdBachelors,
		SUM(CASE WHEN HighestDegree = 'M' THEN 1 ELSE 0 END) AS EdMasters,
		SUM(CASE WHEN RaceEthOSPI = 'American Indian/Alaskan Native' THEN 1 ELSE 0 END) AS RaceAmInd,
		SUM(
			CASE WHEN RaceEthOSPI = 'Asian' THEN 1 ELSE 0 END +
			CASE WHEN RaceEthOSPI = 'Native Hawaiian/Other Pacific Islander' THEN 1 ELSE 0 END
		) AS RaceAsianPacIsl,
		SUM(CASE WHEN RaceEthOSPI = 'Black/African American' THEN 1 ELSE 0 END) AS RaceBlack,
		SUM(CASE WHEN RaceEthOSPI = 'Hispanic/Latino of any race(s)' THEN 1 ELSE 0 END) AS RaceHispanic,
		SUM(CASE WHEN RaceEthOSPI = 'Two or More Races' THEN 1 ELSE 0 END) AS RaceTwoOrMore,
		SUM(CASE WHEN RaceEthOSPI = 'White' THEN 1 ELSE 0 END) AS RaceWhite,
		SUM(CASE WHEN CertYearsOfExperience <= 4.5 THEN 1 ELSE 0 END) AS Exp0to4,
		SUM(CASE WHEN CertYearsOfExperience > 4.5 AND CertYearsOfExperience <= 14.5 THEN 1 ELSE 0 END) AS Exp5to14,
		SUM(CASE WHEN CertYearsOfExperience > 14.5 AND CertYearsOfExperience <= 24.5 THEN 1 ELSE 0 END) AS Exp15to24,
		SUM(CASE WHEN CertYearsOfExperience > 24.5 THEN 1 ELSE 0 END) AS ExpOver25,
		count(*) as TotalTeachers
	FROM Fact_SchoolTeacher st
	JOIN Dim_Staff s
		ON st.StaffID = s.StaffID
	WHERE PrimaryFlag = 1
	GROUP BY
		st.AcademicYear
)
select
	AcademicYear,
	TotalTeachers,
	CAST(Male AS REAL) / CAST(TotalTeachers AS REAL) AS PctMale,
	CAST(Female AS REAL) / CAST(TotalTeachers AS REAL) AS PctFemale,
	CAST(EdBachelors AS REAL) / CAST(TotalTeachers AS REAL) AS PctEdBachelors,
	CAST(EdMasters AS REAL) / CAST(TotalTeachers AS REAL) AS PctEdMasters,
	CAST(RaceAmInd AS REAL) / CAST(TotalTeachers AS REAL) AS PctRaceAmInd,
	CAST(RaceAsianPacIsl AS REAL) / CAST(TotalTeachers AS REAL) AS PctRaceAsianPacIsl,
	CAST(RaceBlack AS REAL) / CAST(TotalTeachers AS REAL) AS PctRaceBlack,
	CAST(RaceHispanic AS REAL) / CAST(TotalTeachers AS REAL) AS PctRaceHispanic,
	CAST(RaceTwoOrMore AS REAL) / CAST(TotalTeachers AS REAL) AS PctRaceTwoOrMore,
	CAST(RaceWhite AS REAL) / CAST(TotalTeachers AS REAL) AS PctRaceWhite,
	CAST(Exp0to4 AS REAL) / CAST(TotalTeachers AS REAL) AS PctExp0to4,
	CAST(Exp5to14 AS REAL) / CAST(TotalTeachers AS REAL) AS PctExp5to14,
	CAST(Exp15to24 AS REAL) / CAST(TotalTeachers AS REAL) AS PctExp15to24,
	CAST(ExpOver25 AS REAL) / CAST(TotalTeachers AS REAL) AS PctExpOver25
FROM Counts
WHERE AcademicYear = 1996 OR AcademicYear = 2018
order by AcademicYear;


----------------------------------
-- Statewide counts of novice teachers
----------------------------------

With Counts as (
	SELECT
		StartYear AS AcademicYear,
		count(*) as TotalTeachers,
		SUM(IsNoviceTeacherFlag) AS TotalNoviceTeachers
	FROM Fact_TeacherMobility m
	JOIN Dim_Staff s
		ON m.StartStaffID = s.StaffID
	where DiffYears = 1
	GROUP BY
		StartYear,
		EndYear
)
select
	*,
	(CAST(TotalNoviceTeachers AS REAL) / CAST(TotalTeachers AS REAL)) AS Pct
from Counts
order by AcademicYear;


----------------------------------
-- 5-year Statewide retention and mobility
----------------------------------

With Counts as (
	SELECT
		StartYear,
		EndYear,
		SUM(Stayer) AS Stayer,
		SUM(MovedIn) AS MovedIn,
		SUM(MovedOut) AS MovedOut,
		SUM(Exited) AS Exited,
		count(*) as TotalTeachers
	FROM Fact_TeacherMobility
	where DiffYears = 4
	GROUP BY
		StartYear,
		EndYear
)
select
	*,
	cast(Stayer AS real) / cast(TotalTeachers as real) as StayerPct,
	cast(MovedIn AS real) / cast(TotalTeachers as real) as MovedInPct,
	cast(MovedOut AS real) / cast(TotalTeachers as real) as MovedOutPct,
	cast(Exited AS real) / cast(TotalTeachers as real) as ExitedPct
from Counts
WHERE StartYear IN (1999, 2011, 2012, 2013, 2014, 2015)
order by StartYear;


----------------------------------
-- Comparing statewide retention/mobility of all teachers vs novice teachers for 2015-2019
----------------------------------

WITH Counts as (
	SELECT
		StartYear,
		EndYear,
		SUM(Stayer) AS Stayer,
		SUM(MovedIn) AS MovedIn,
		SUM(MovedOut) AS MovedOut,
		SUM(Exited) AS Exited,
		count(*) as TotalTeachers
	FROM Fact_TeacherMobility m
	where DiffYears = 4
	GROUP BY
		StartYear,
		EndYear
)
,CountsNovice as (
	SELECT
		StartYear,
		EndYear,
		SUM(Stayer) AS Stayer,
		SUM(MovedIn) AS MovedIn,
		SUM(MovedOut) AS MovedOut,
		SUM(Exited) AS Exited,
		count(*) as TotalTeachers
	FROM Fact_TeacherMobility m
	JOIN Dim_Staff s
		ON m.StartStaffID = s.StaffID
	where
		DiffYears = 4
		AND IsNoviceTeacherFlag = 1
	GROUP BY
		StartYear,
		EndYear
)
SELECT
	c.StartYear,
	c.EndYear,
	cast(c.Stayer AS real) / cast(c.TotalTeachers as real) as AllStayerPct,
	cast(c.MovedIn AS real) / cast(c.TotalTeachers as real) as AllMovedInPct,
	cast(c.MovedOut AS real) / cast(c.TotalTeachers as real) as AllMovedOutPct,
	cast(c.Exited AS real) / cast(c.TotalTeachers as real) as AllExitedPct,
	CAST(cn.Stayer AS real) / cast(cn.TotalTeachers as real) as NoviceStayerPct,
	cast(cn.MovedIn AS real) / cast(cn.TotalTeachers as real) as NoviceMovedInPct,
	cast(cn.MovedOut AS real) / cast(cn.TotalTeachers as real) as NoviceMovedOutPct,
	cast(cn.Exited AS real) / cast(cn.TotalTeachers as real) as NoviceExitedPct
FROM Counts c
LEFT JOIN CountsNovice cn
	ON c.StartYear = cn.StartYear
	AND c.EndYear = cn.EndYear
WHERE c.StartYear = 2015
order by c.StartYear;


----------------------------------
-- Retention and mobility for select districts 2012-2016
----------------------------------

With 
Codes AS (
	SELECT
		DistrictCode,
		max(DistrictName) as DistrictName
	FROM Dim_School
	GROUP BY DistrictCode
)
,Counts as (
	SELECT
		StartYear,
		EndYear,
		StartCountyAndDistrictCode,
		SUM(Stayer) AS Stayer,
		SUM(MovedIn) AS MovedIn,
		SUM(MovedOut) AS MovedOut,
		SUM(Exited) AS Exited,
		count(*) as TotalTeachers
	FROM Fact_TeacherMobility m
	where DiffYears = 4
	GROUP BY
		StartYear,
		EndYear,
		StartCountyAndDistrictCode
)
select
	StartYear,
	EndYear,
	StartCountyAndDistrictCode,
	Codes.DistrictName,
	cast(Stayer AS real) / cast(TotalTeachers as real) as StayerPct,
	cast(MovedIn AS real) / cast(TotalTeachers as real) as MovedInPct,
	cast(MovedOut AS real) / cast(TotalTeachers as real) as MovedOutPct,
	cast(Exited AS real) / cast(TotalTeachers as real) as ExitedPct
from Counts
LEFT JOIN Codes
	ON Counts.StartCountyAndDistrictCode = Codes.DistrictCode
WHERE
	StartYear = 2012
	AND EndYear = 2016
	AND (
		Codes.DistrictName LIKE 'Seattle%'
		OR Codes.DistrictName LIKE 'Spokane%'
		OR Codes.DistrictName LIKE 'Tacoma%'
		OR Codes.DistrictName LIKE 'Vancouver%'
		OR Codes.DistrictName LIKE 'Bellevue%'
		OR Codes.DistrictName LIKE 'Highline%'
		OR Codes.DistrictName LIKE 'Kennewick%'
		OR Codes.DistrictName LIKE 'Yakima%'
		OR Codes.DistrictName LIKE 'Bellingham%'
		OR Codes.DistrictName LIKE 'Central Kitsap%'
	)
order by StartYear, endyear, Codes.DistrictName;


----------------------------------
-- Retention and mobility for Auburn schools 2011-2015
----------------------------------

With Counts as (
	SELECT
		StartYear,
		EndYear,
		StartCountyAndDistrictCode,
		StartBuilding,
		SUM(Stayer) AS Stayer,
		SUM(MovedIn) AS MovedIn,
		SUM(MovedOut) AS MovedOut,
		SUM(Exited) AS Exited,
		count(*) as TotalTeachers
	FROM Fact_TeacherMobility m
	where DiffYears = 4
	GROUP BY
		StartYear,
		EndYear,
		StartCountyAndDistrictCode,
		StartBuilding
)
select
	Counts.StartYear,
	Counts.EndYear,
	Sch.DistrictName,
	Sch.SchoolName,
	Stayer,
	cast(Stayer AS real) / cast(TotalTeachers as real) as StayerPct,
	MovedIn,
	cast(MovedIn AS real) / cast(TotalTeachers as real) as MovedInPct,
	MovedOut,
	cast(MovedOut AS real) / cast(TotalTeachers as real) as MovedOutPct,
	Exited,
	cast(Exited AS real) / cast(TotalTeachers as real) as ExitedPct
from Counts
LEFT JOIN Dim_School Sch
	ON Counts.StartBuilding = Sch.SchoolCode
	AND Counts.StartYear = Sch.AcademicYear
WHERE
	StartYear = 2011
	AND EndYear = 2015
	AND Sch.DistrictName LIKE 'Auburn%'
order by StartYear, endyear, Sch.SchoolName;


----------------------------------
-- Yearly Retention and mobility rates
----------------------------------

With Counts as (
	SELECT
		StartYear,
		EndYear,
		SUM(Stayer) AS Stayer,
		SUM(MovedIn) AS MovedIn,
		SUM(MovedOut) AS MovedOut,
		SUM(Exited) AS Exited,
		count(*) as TotalTeachers
	FROM Fact_TeacherMobility m
	where DiffYears = 1
	GROUP BY
		StartYear,
		EndYear
)
select
	*,
	cast(Stayer AS real) / cast(TotalTeachers as real) as StayerPct,
	cast(MovedIn AS real) / cast(TotalTeachers as real) as MovedInPct,
	cast(MovedOut AS real) / cast(TotalTeachers as real) as MovedOutPct,
	cast(Exited AS real) / cast(TotalTeachers as real) as ExitedPct
from Counts
where StartYear IN (2006, 2014, 2015, 2016, 2017, 2018)
order by StartYear;