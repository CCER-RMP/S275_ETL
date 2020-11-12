
{{
    config({
        "pre-hook": [
            "DROP INDEX IF EXISTS idx_dim_school",
            "DROP INDEX IF EXISTS idx_dim_school2"
        ]
        ,"post-hook": [
            """
            CREATE UNIQUE INDEX idx_dim_school ON dim_school (
                AcademicYear,
                DistrictCode,
                DistrictName,
                SchoolCode,
                SchoolName,
                RMRFlag
            )
            """,
            """
            CREATE INDEX idx_dim_school2 ON dim_school (
                AcademicYear,
                SchoolCode,
                SchoolName,
                DistrictCode,
                DistrictName,
                RMRFlag
            )
            """
        ]
    })
}}

SELECT 
    b.AcademicYear,
    b.DistrictCode,
    b.DistrictName,
    b.SchoolCode,
    b.SchoolName,
    GradeLevelStart,
    GradeLevelEnd,
    GradeLevelSortOrderStart,
    GradeLevelSortOrderEnd,
    SchoolType,
    Lat,
    Long ,
    NCESLocaleCode,
    NCESLocale,
    RMRFlag,
    TotalEnrollmentOct,
    GraduationMet,
    GraduationTotal,
    GraduationPercent,
    FRPL,
    FRPLPercent,
    AmIndOrAlaskan,
    AmIndOrAlaskanPercent,
    Asian,
    AsianPercent,
    PacIsl,
    PacIslPercent,
    AsPacIsl,
    AsPacIslPercent,
    Black,
    BlackPercent,
    Hispanic,
    HispanicPercent,
    White,
    WhitePercent,
    TwoOrMoreRaces,
    TwoOrMoreRacesPercent,
    CASE WHEN TotalEnrollmentOct > 0 THEN
        CAST(
            {% call concat() %}
            COALESCE(AmIndOrAlaskan, 0)
            + COALESCE(Asian, 0)
            + COALESCE(PacIsl, 0)
            + COALESCE(Black, 0)
            + COALESCE(Hispanic, 0)
            + COALESCE(TwoOrMoreRaces, 0)
            {% endcall %}
        as INT)
    END AS StudentsOfColor,
    CASE WHEN TotalEnrollmentOct > 0 THEN
        CAST(
            {% call concat() %}
            COALESCE(AmIndOrAlaskan, 0)
            + COALESCE(Asian, 0)
            + COALESCE(PacIsl, 0)
            + COALESCE(Black, 0)
            + COALESCE(Hispanic, 0)
            + COALESCE(TwoOrMoreRaces, 0)
            {% endcall %}
        as REAL) / TotalEnrollmentOct
    END AS StudentsOfColorPercent,
    Male,
    MalePercent,
    Female,
    FemalePercent,
    GenderX,
    GenderXPercent,
    {{ getdate_fn() }} AS MetaCreatedAt
FROM {{ ref('dim_school_base') }} b
LEFT JOIN {{ ref('dim_school_fields') }} f
    ON b.AcademicYear = f.AcademicYear
    AND b.DistrictCode = f.DistrictCode
    AND b.SchoolCode = f.SchoolCode
