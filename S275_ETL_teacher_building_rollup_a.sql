WITH CTE_TAB
AS (
    SELECT 
	  convert(int,RIGHT(schoolyear,4)) as AcademicYear
      ,[area]
      ,[cou]
      ,[dis]
      ,[codist]
      ,[LastName]
      ,[FirstName]
      ,[MiddleName]
      ,[cert]
      --,[bdate] not in 2018 file
      --,[byr] not in 2018 file
      --,[bmo] not in 2018 file
      --,[bday] not in 2018 file
      ,[sex]
      ,[hispanic]
      ,[race]
      ,[hdeg]
      ,[hyear]
      ,[acred]
      ,[icred]
      ,[bcred]
      ,[vcred]
      ,[exp]
      ,[camix1]
      ,[ftehrs]
      ,[ftedays]
      ,[certfte]
      ,[clasfte]
      ,[certbase]
      ,[clasbase]
      ,[othersal]
      ,[tfinsal]
      ,[cins]
      ,[cman]
      ,[cbrtn]
      ,[clasflag]
      ,[certflag]
--      ,[ceridate]
      ,[act]
      ,[bldgn]
      ,sum([asspct]) pctass
      ,sum([assfte]) ftetotal
      ,sum([asssal]) saltotal
  FROM [SandBox].[dbo].[S275_2018] a
  WHERE [droot] in (31,32,33,34) and act='27' and area = 'L'
  GROUP BY 
	convert(int,RIGHT(schoolyear,4))
	,[area]
      ,[cou]
      ,[dis]
      ,[codist]
      ,[LastName]
      ,[FirstName]
      ,[MiddleName]
      ,[cert]
      --,[bdate] not in 2018 file
      --,[byr] not in 2018 file
      --,[bmo] not in 2018 file
      --,[bday] not in 2018 file
      ,[sex]
      ,[hispanic]
      ,[race]
      ,[hdeg]
      ,[hyear]
      ,[acred]
      ,[icred]
      ,[bcred]
      ,[vcred]
      ,[exp]
      ,[camix1]
      ,[ftehrs]
      ,[ftedays]
      ,[certfte]
      ,[clasfte]
      ,[certbase]
      ,[clasbase]
      ,[othersal]
      ,[tfinsal]
      ,[cins]
      ,[cman]
      ,[cbrtn]
      ,[clasflag]
      ,[certflag]
      --,[ceridate]
      ,[act]
      ,[bldgn]
)
  SELECT *
	INTO [SandBox].[dbo].[s275_2018_teacher_building_rollup]
	FROM CTE_TAB
	
	--,RANK() OVER (PARTITION BY cert ORDER BY ftetotal DESC) N 
    
	WHERE cert is not NULL and ftetotal > 0



--169274H