-- -- https://stackoverflow.com/questions/6663124/how-to-load-extensions-into-sqlite
-- curl --location --output extension-functions.c 'https://www.sqlite.org/contrib/download/extension-functions.c?get=25'
-- gcc -g -fPIC -dynamiclib extension-functions.c -o extension-functions.dylib
-- SELECT load_extension('extension-functions');

-- query begins here
SELECT
top3.raceID,
top3.year,
race_name,
sum_overlapped_by_p1,
sum_dnf,
stdev_pitstop_cnt,
min_overtake,
lat,
CASE WHEN wetraces.name IS NULL THEN 0 ELSE 1 END AS is_wet_race,
CASE WHEN funraces.name IS NULL THEN 0 ELSE 1 END AS is_fun_race,
SUM(is_hamilton_in_podium) AS is_hamilton_in_podium,
AVG(driver_age_at_race) AS avg_podium_driver_age,
SUM(is_non_big_3_team) AS sum_non_big_3_team_in_podium,
SUM(is_non_front_row_starter) AS sum_non_front_row_in_podium,
SUM(gap_to_winner) AS sum_podium_gap_ms
FROM (
SELECT 
races.raceID,
races.year,
races.name,
lat,
races.year || ' ' || races.name AS race_name,
positionOrder,
CASE WHEN qualifying.position > 3 THEN 1 ELSE 0 END AS is_non_front_row_starter,
CASE WHEN surname = 'Hamilton' THEN 1 ELSE 0 END AS is_hamilton_in_podium,
races.date - dob AS driver_age_at_race,
CASE WHEN constructors.name NOT IN ('Mercedes', 'Red Bull', 'Ferrari') THEN 1 ELSE 0 END AS is_non_big_3_team,
pod.milliseconds - FIRST_VALUE(pod.milliseconds) OVER (PARTITION BY pod.raceID ORDER BY positionOrder) AS gap_to_winner
FROM races
JOIN results pod
	ON races.raceID = pod.raceID
	AND positionOrder <= 3
JOIN drivers
	ON drivers.driverID = pod.driverID
JOIN constructors
	ON constructors.constructorID = pod.constructorID
JOIN circuits
	ON circuits.circuitID = races.circuitID
JOIN qualifying
	ON qualifying.raceID = races.raceID
	AND qualifying.driverID = pod.driverID
WHERE races.year BETWEEN 2014 AND 2019
) top3
JOIN (
SELECT 
races.raceID,
SUM(CASE WHEN mid.milliseconds ="\N" THEN 1 ELSE 0 END) AS sum_overlapped_by_p1,
SUM(CASE WHEN SUBSTR(statusId, 1, 1) != '1' THEN 1 ELSE 0 END) AS sum_dnf
FROM races
JOIN results mid
	ON races.raceID = mid.raceID
	AND positionOrder > 3
GROUP BY 1
) mfd
	ON top3.raceID = mfd.raceID
JOIN 
(
SELECT
raceID,
STDEV(cnt_pitstop) AS stdev_pitstop_cnt
FROM (SELECT raceID,ps.driverID, COUNT(stop) AS cnt_pitstop FROM pit_stops ps GROUP BY 1, 2)
GROUP BY 1
) pc
	ON pc.raceID = top3.raceID
JOIN
(
SELECT 
raceID, 
SUM(CASE WHEN pos_chg >= 0 THEN pos_chg ELSE 0 END) AS min_overtake 
FROM 
(SELECT r.raceID, r.driverID, r.positionOrder - q.position AS pos_chg FROM results r JOIN qualifying q ON r.raceID = q.raceID AND r.driverID = q.driverID)
GROUP BY 1
) ov
	ON ov.raceID = top3.raceID
LEFT JOIN funraces 
	ON top3.year = funraces.year
	AND top3.name = funraces.name
LEFT JOIN wetraces
	ON top3.year = wetraces.year
	AND top3.name = wetraces.name
GROUP BY 1,2,3,4,5,6,7,8,9
;





