SELECT athlete.id AS athlete_id,
    --date/time
    gmt_local_time_difference.local_date,
    extract(epoch from gmt_local_time_difference.gmt_local_difference)/3600 AS gmt_offset,
    --gc_wellness daily summary
    aggr_garmin_connect_wellness.wellness_resting_heart_rate,
    --Activity Summary
    aggr_strava_activity_summary.type::text AS act_type,
    COALESCE(aggr_strava_activity_summary.act_daily_suffer_score,0) AS act_daily_suffer_score,
    ROUND(ema(coalesce(act_daily_suffer_score::numeric, 0), 0.1428) over (order by gmt_local_time_difference.local_date asc),2) as act_pmc_atl,
    ROUND(ema(coalesce(act_daily_suffer_score::numeric, 0), 0.0238) over (order by gmt_local_time_difference.local_date asc),2) as act_pmc_ctl,
    ROUND(ema(coalesce(act_daily_suffer_score::numeric, 0), 0.0238) over (order by gmt_local_time_difference.local_date asc),2) 
    - ROUND(ema(coalesce(act_daily_suffer_score::numeric, 0), 0.1428) over (order by gmt_local_time_difference.local_date asc),2) as act_pmc_tsb,
    aggr_strava_activity_summary.max_heartrate AS act_max_heartrate,
    aggr_strava_activity_summary.moving_time AS act_duration,
    aggr_strava_activity_summary.weighted_average_watts AS act_power,
    --Activity Streams
    max(strava_activity_streams.distance) AS act_distance,
    avg(strava_activity_streams.altitude) AS act_altitude,
    avg(strava_activity_streams.heartrate) AS act_heart_rate,
    avg(strava_activity_streams.velocity_smooth) AS act_velocity,
    -- https://educatedguesswork.org/posts/grade-vs-pace/
    -- Factor= 0.0021 * grade^ + 0.034 * grade +1
    avg((0.0021 * strava_activity_streams.grade_smooth^2) + (0.034 * strava_activity_streams.grade_smooth)+1) as act_correction_factor,
    avg(strava_activity_streams.velocity_smooth * ((0.0021 * strava_activity_streams.grade_smooth^2) + (0.034 * strava_activity_streams.grade_smooth)+1)) as act_gap,
    --nutrition
    aggr_mfp_nutrition.nutr_daily_calories,
    aggr_mfp_nutrition.nutr_daily_carbohydrates,
    aggr_mfp_nutrition.nutr_daily_protein,
    aggr_mfp_nutrition.nutr_daily_fat,
    aggr_mfp_nutrition.nutr_daily_fiber,
    aggr_mfp_nutrition.nutr_daily_sugar,
    --body composition
    nullfill(aggr_garmin_connect_body_composition.body_mass_index) OVER (ORDER BY gmt_local_time_difference.local_date ASC) AS body_mass_index,
    --oura_sleep
    ROUND(ema(coalesce(aggr_oura_sleep_daily_summary.oura_sleep_rmssd::numeric, 0), 0.1428) over (order by gmt_local_time_difference.local_date asc),2) as oura_sleep_rmssd_7d_ema,
    ROUND(ema(coalesce(aggr_oura_sleep_daily_summary.oura_sleep_rmssd::numeric, 0), 0.0238) over (order by gmt_local_time_difference.local_date asc),2) as oura_sleep_rmssd_42d_ema,
    aggr_oura_sleep_daily_summary.oura_sleep_rmssd AS oura_sleep_rmssd,
    aggr_oura_sleep_daily_summary.oura_sleep_rmssd_baseline AS oura_sleep_baseline
FROM athlete
--Date/Time
LEFT JOIN gmt_local_time_difference ON gmt_local_time_difference.athlete_id = athlete.id
LEFT JOIN timezones ON timezones.timestamp_local::date = gmt_local_time_difference.local_date
--gc_wellness daily summary
LEFT JOIN (SELECT 
           garmin_connect_wellness.calendar_date::date AS calendar_date_local,
           MAX(garmin_connect_wellness.wellness_resting_heart_rate) AS wellness_resting_heart_rate
           FROM garmin_connect_wellness
           GROUP BY (garmin_connect_wellness.calendar_date::date)) aggr_garmin_connect_wellness ON aggr_garmin_connect_wellness.calendar_date_local = gmt_local_time_difference.local_date
--Activity Summary
LEFT JOIN (SELECT 
           strava_activity_summary.id AS strava_activity_summary_id,
           strava_activity_summary.start_date_local::date AS start_date_local,
           strava_activity_summary.type,
           strava_activity_summary.max_heartrate,
           strava_activity_summary.moving_time,
           strava_activity_summary.weighted_average_watts AS weighted_average_watts,          
           sum(strava_activity_summary.suffer_score) AS act_daily_suffer_score
           FROM strava_activity_summary
           GROUP BY
           strava_activity_summary.id,
           strava_activity_summary.type,
           strava_activity_summary.max_heartrate,
           strava_activity_summary.moving_time,
           (strava_activity_summary.start_date_local::date)) aggr_strava_activity_summary ON aggr_strava_activity_summary.start_date_local = gmt_local_time_difference.local_date
--Activity Streams  
LEFT JOIN strava_activity_streams ON aggr_strava_activity_summary.strava_activity_summary_id = strava_activity_streams.activity_id
--Nutrition
LEFT JOIN (SELECT 
           mfp_nutrition.date,
           sum(mfp_nutrition.calories) AS nutr_daily_calories,
           sum(mfp_nutrition.carbohydrates) AS nutr_daily_carbohydrates,
           sum(mfp_nutrition.protein) AS nutr_daily_protein,
           sum(mfp_nutrition.fat) AS nutr_daily_fat,
           sum(mfp_nutrition.fiber) AS nutr_daily_fiber,
           sum(mfp_nutrition.sugar) AS nutr_daily_sugar
           FROM mfp_nutrition
           GROUP BY mfp_nutrition.date
          ) aggr_mfp_nutrition ON aggr_mfp_nutrition.date = gmt_local_time_difference.local_date 
--Body Composition
LEFT JOIN ( SELECT 
            garmin_connect_body_composition.timestamp::date AS timestamp,
            max(garmin_connect_body_composition.bmi) AS body_mass_index
            FROM garmin_connect_body_composition
            GROUP BY (garmin_connect_body_composition.timestamp::date)) aggr_garmin_connect_body_composition ON aggr_garmin_connect_body_composition.timestamp = gmt_local_time_difference.local_date
--Oura Sleep
LEFT JOIN ( WITH lin_regr AS 
              (SELECT 
                 regr_slope(rmssd,date_part('epoch', summary_date::date)) rmmsd_slope,
                 regr_intercept(rmssd,date_part('epoch', summary_date::date)) rmssd_intercept 
               FROM oura_sleep_daily_summary)                                  
            SELECT 
            oura_sleep_daily_summary.summary_date::date AS summary_date,
            lead(oura_sleep_daily_summary.rmssd) over (order by oura_sleep_daily_summary.summary_date desc) AS oura_sleep_rmssd,
            -- RMSSD baseline
            max(lin_regr.rmmsd_slope * date_part('epoch', summary_date::date) + lin_regr.rmssd_intercept) as oura_sleep_rmssd_baseline
            FROM oura_sleep_daily_summary,lin_regr
            GROUP BY 
            oura_sleep_daily_summary.summary_date,
            oura_sleep_daily_summary.rmssd,
            (oura_sleep_daily_summary.summary_date::date)) aggr_oura_sleep_daily_summary ON aggr_oura_sleep_daily_summary.summary_date = gmt_local_time_difference.local_date
--WHERE aggr_oura_sleep_daily_summary.oura_sleep_rmssd IS NOT null
GROUP BY athlete.id, 
         gmt_local_time_difference.local_date, 
         gmt_local_time_difference.gmt_local_difference,
         -- GC Wellness
         aggr_garmin_connect_wellness.wellness_resting_heart_rate, --the lowest 30 minute average in a 24 hour period 
         --Activity Summary
         aggr_strava_activity_summary.type,
         aggr_strava_activity_summary.act_daily_suffer_score,
         aggr_strava_activity_summary.max_heartrate,
         aggr_strava_activity_summary.moving_time,
         aggr_strava_activity_summary.weighted_average_watts,
         -- Nutrition
         aggr_mfp_nutrition.nutr_daily_calories,
         aggr_mfp_nutrition.nutr_daily_carbohydrates,
         aggr_mfp_nutrition.nutr_daily_protein,
         aggr_mfp_nutrition.nutr_daily_fat,
         aggr_mfp_nutrition.nutr_daily_fiber,
         aggr_mfp_nutrition.nutr_daily_sugar,
         -- Body Composition
         aggr_garmin_connect_body_composition.body_mass_index,
         -- Oura Sleep
         aggr_oura_sleep_daily_summary.oura_sleep_rmssd,
         aggr_oura_sleep_daily_summary.oura_sleep_rmssd_baseline
         
ORDER BY gmt_local_time_difference.local_date DESC;
