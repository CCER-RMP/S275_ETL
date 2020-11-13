
SELECT
    tm.TeacherMobilityID
    ,StartStaffID
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
    ,d.Distance
    ,RoleChanged
    ,RoleChangedToPrincipal
    ,RoleChangedToAsstPrincipal
    ,Stayer
    ,MovedInBuildingChange
    ,MovedInRoleChange
    ,MovedIn
    ,MovedOut
    ,MovedOutOfRMR
    ,Exited
    ,{{ getdate_fn() }} as MetaCreatedAt
FROM {{ ref('stg_teachermobility') }} tm
LEFT JOIN {{ source('sources', 'ext_teachermobility_distance') }} d
    ON tm.TeacherMobilityID = d.TeacherMobilityID
