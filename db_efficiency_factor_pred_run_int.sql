SELECT 
    --Activity Summary
    strava_activity_summary.strava_activity_id as activity_id,
    strava_activity_summary.type,
    strava_activity_summary.suffer_score,
    strava_activity_summary.max_heartrate,
    --Activity Streams
    --5 minutes (300s) intervals,
    to_timestamp(floor((extract('epoch' from strava_activity_streams.time_gmt::timestamp) / 300 )) * 300) AT TIME ZONE 'UTC' as time_interval,
    --duration=distnce/velocity
    (max(strava_activity_streams.distance)-min(strava_activity_streams.distance))/avg(strava_activity_streams.velocity_smooth) as duration,
    max(strava_activity_streams.distance)-min(strava_activity_streams.distance) as distance,
    avg(strava_activity_streams.altitude) as altitude,
    avg(strava_activity_streams.heartrate) as heartrate,
    avg(strava_activity_streams.grade_smooth) as grade,
    avg(strava_activity_streams.velocity_smooth) as velocity,
    avg(strava_activity_streams.temp) as temperature,
    -- https://educatedguesswork.org/posts/grade-vs-pace/
    -- Factor= 0.0021 * grade^ + 0.034 * grade +1
    avg(strava_activity_streams.velocity_smooth * ((0.0021 * strava_activity_streams.grade_smooth^2) + (0.034 * strava_activity_streams.grade_smooth)+1)) as grade_adj_pace
FROM strava_activity_summary
LEFT JOIN strava_activity_streams ON strava_activity_summary.id = strava_activity_streams.activity_id
WHERE strava_activity_summary.type LIKE '%Run%' AND strava_activity_streams.time_gmt IS NOT NULL AND strava_activity_streams.velocity_smooth <> 0
GROUP BY 
    time_interval,
    strava_activity_summary.id,
    strava_activity_summary.type
ORDER BY time_interval DESC
