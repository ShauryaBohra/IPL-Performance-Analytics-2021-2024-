use cricketdatabase;

select * from deliveries;
select * from matches;

-- Standardize Text Case -- 
UPDATE matches
SET team1 = UPPER(team1), team2 = UPPER(team2), winner = UPPER(winner),
 player_of_match = UPPER(player_of_match);

UPDATE deliveries
SET batting_team = UPPER(batting_team), bowling_team = UPPER(bowling_team), 
batter = UPPER(batter), bowler = UPPER(bowler);

-- Update Team Name Consistency -- 
UPDATE deliveries
SET batting_team = REPLACE(batting_team, 'ROYAL CHALLENGERS BENGALURU', 'ROYAL CHALLENGERS BANGALORE'),
    bowling_team = REPLACE(bowling_team, 'ROYAL CHALLENGERS BENGALURU', 'ROYAL CHALLENGERS BANGALORE')
WHERE batting_team LIKE '%ROYAL CHALLENGERS BENGALURU%' 
   OR bowling_team LIKE '%ROYAL CHALLENGERS BENGALURU%';

UPDATE matches
SET team1 = REPLACE(team1, 'ROYAL CHALLENGERS BENGALURU', 'ROYAL CHALLENGERS BANGALORE'),
    team2 = REPLACE(team2, 'ROYAL CHALLENGERS BENGALURU', 'ROYAL CHALLENGERS BANGALORE'),
    toss_winner = REPLACE(toss_winner, 'ROYAL CHALLENGERS BENGALURU', 'ROYAL CHALLENGERS BANGALORE'),
    winner = REPLACE(winner, 'ROYAL CHALLENGERS BENGALURU', 'ROYAL CHALLENGERS BANGALORE')
WHERE team1 LIKE '%ROYAL CHALLENGERS BENGALURU%' 
   OR team2 LIKE '%ROYAL CHALLENGERS BENGALURU%'
   OR toss_winner LIKE '%ROYAL CHALLENGERS BENGALURU%'
   OR winner LIKE '%ROYAL CHALLENGERS BENGALURU%';

ALTER TABLE deliveries CHANGE COLUMN `over` `over1` int;

ALTER TABLE matches
RENAME COLUMN result_margi0 TO result_margin,
RENAME COLUMN target_ru0s TO target_runs;

-- KPI -- 

-- Strike Rate of Top 10 Batsmen -- 
SELECT batter, SUM(batsman_runs) AS total_runs,
COUNT(*) AS balls_faced,ROUND((SUM(batsman_runs) / COUNT(*)) * 100, 2) AS strike_rate
FROM deliveries
GROUP BY batter
HAVING COUNT(*) > 20
ORDER BY strike_rate DESC
LIMIT 10;

--  Economy Rate of Top Bowlers -- 
WITH bowler_stats AS (
    SELECT 
        bowler, 
        COUNT(*) / 6 AS overs_bowled, 
        SUM(total_runs) AS runs_conceded
    FROM deliveries
    GROUP BY bowler
)
SELECT bowler,ROUND(runs_conceded / overs_bowled, 2) AS economy_rate
FROM bowler_stats
ORDER BY economy_rate ASC
LIMIT 10;

-- Match-Winning Impact of Toss Decision -- 
SELECT toss_decision,
ROUND(SUM(CASE WHEN toss_winner = winner THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS toss_win_percentage
FROM matches
GROUP BY toss_decision;

-- Consistent Performers (Most Player of the Match Awards) -- 
SELECT player_of_match,COUNT(*) AS awards
FROM matches
GROUP BY player_of_match
ORDER BY awards DESC
LIMIT 10;

-- Boundaries per Match (Fours and Sixes) -- 
WITH boundaries AS (
    SELECT 
        match_id, 
        SUM(CASE WHEN batsman_runs = 4 THEN 1 ELSE 0 END) AS total_fours,
        SUM(CASE WHEN batsman_runs = 6 THEN 1 ELSE 0 END) AS total_sixes
    FROM deliveries
    GROUP BY match_id
)
SELECT 
    match_id,
    total_fours,
    total_sixes
FROM boundaries;

--  Dismissal Types per Bowler -- 
SELECT bowler,dismissal_kind,COUNT(*) AS dismissals
FROM deliveries
WHERE is_wicket = 1 AND dismissal_kind NOT IN ('retired hurt', 'retired out','run out')
GROUP BY bowler, dismissal_kind;


-- Top Bowler-Batter Rivalries: Most Frequent Dismissals in IPL History -- 
SELECT 
    batter AS dismissed_player,
    bowler AS dismissing_bowler,
    COUNT(*) AS dismissal_count
FROM 
    deliveries
WHERE 
    is_wicket = 1 
    AND dismissal_kind NOT IN ('retired hurt', 'retired out','run out') 
GROUP BY 
    batter, bowler
ORDER BY 
    dismissal_count DESC
LIMIT 10;


-- Top Partnerships by Runs -- 
SELECT 
    LEAST(batter, non_striker) AS batter,
    GREATEST(batter, non_striker) AS non_striker,
    SUM(total_runs) AS partnership_runs
FROM deliveries
GROUP BY LEAST(batter, non_striker), GREATEST(batter, non_striker)
ORDER BY partnership_runs DESC
LIMIT 10;

-- Dismissals by Fielders (Most Catches) -- 
SELECT fielder,COUNT(*) AS catches
FROM deliveries
WHERE dismissal_kind = 'caught'
GROUP BY fielder
ORDER BY catches DESC;

-- Most Dot Balls Bowled -- 
SELECT bowler, COUNT(*) AS dot_balls
FROM deliveries
WHERE total_runs = 0
GROUP BY bowler
ORDER BY dot_balls DESC;

-- Highest Strike Rate in Death Overs (Overs 16-20) -- 
SELECT batter,SUM(batsman_runs) AS total_runs,COUNT(*) AS balls_faced,
ROUND((SUM(batsman_runs) / COUNT(*)) * 100, 2) AS strike_rate
FROM deliveries
WHERE over1 BETWEEN 16 AND 20
GROUP BY batter
ORDER BY strike_rate DESC
LIMIT 10;

--  Powerplay Overs Efficiency for Bowlers -- 
SELECT bowler,ROUND(SUM(total_runs) / (COUNT(*) / 6), 2) AS powerplay_economy
FROM deliveries
WHERE over1 BETWEEN 1 AND 6
GROUP BY bowler;

-- Top Performers in Chasing Matches (Players with Most Runs When Team Batting Second Wins) -- 
SELECT batter,SUM(batsman_runs) AS runs_in_chase
FROM deliveries
JOIN matches ON deliveries.match_id = matches.id
WHERE inning = 2 AND winner = batting_team
GROUP BY batter
ORDER BY runs_in_chase DESC
LIMIT 10;

-- Pressure Scenarios Performance (Runs in Last 5 Overs Chasing) -- 
SELECT batter,SUM(batsman_runs) AS pressure_runs
FROM deliveries
WHERE inning = 2 AND over1 BETWEEN 16 AND 20
GROUP BY batter
ORDER BY pressure_runs DESC;

--  Extras Conceded per Match by Team -- 
SELECT match_id,bowling_team,SUM(extra_runs) AS extras_conceded
FROM deliveries
GROUP BY match_id, bowling_team;

-- Dismissal Types Distribution by Season -- 
SELECT season,dismissal_kind,COUNT(*) AS frequency
FROM deliveries
JOIN matches ON deliveries.match_id = matches.id
WHERE dismissal_kind IS NOT NULL and dismissal_kind != 'NO'
GROUP BY season, dismissal_kind;



-- Win Contribution Percentage (Teams Winning Due to Toss) -- 
SELECT toss_winner AS team,COUNT(*) AS total_matches_won_toss,
SUM(CASE WHEN toss_winner = winner THEN 1 ELSE 0 END) AS matches_won,
ROUND((SUM(CASE WHEN toss_winner = winner THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS toss_win_contribution_percentage
FROM matches
GROUP BY toss_winner;

-- Boundary Dependency for Wins (Percentage of Runs Scored by Fours and Sixes in Winning Matches) -- 
SELECT match_id,winner,
SUM(CASE WHEN batsman_runs IN (4, 6) THEN batsman_runs ELSE 0 END) / SUM(batsman_runs) * 100 AS boundary_percentage
FROM deliveries
JOIN matches ON deliveries.match_id = matches.id
WHERE winner IS NOT NULL
GROUP BY match_id, winner;

-- effectiveness of Bowling in Middle Overs (Overs 7-15) -- 
SELECT bowler,COUNT(*) / 6 AS overs_bowled,SUM(total_runs) AS runs_conceded,
ROUND(SUM(total_runs) / (COUNT(*) / 6), 2) AS middle_overs_economy_rate
FROM deliveries
WHERE over1 BETWEEN 7 AND 15
GROUP BY bowler;

-- Successful Defenses by Team -- 
SELECT team1 AS defending_team, COUNT(*) AS successful_defenses
FROM matches
WHERE result = 'runs' AND result_margin IS NOT NULL
GROUP BY team1;

-- Win Rate When Batting First vs. Batting Second --
SELECT 
    ROUND((SUM(CASE WHEN winner = team1 THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS batting_first_win_rate,
    ROUND((SUM(CASE WHEN winner = team2 THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS batting_second_win_rate
FROM matches;

--  Average Runs Scored per Season by Batter -- 
WITH MatchTotals AS (
    SELECT 
        batter, 
        season,
        SUM(batsman_runs) AS total_runs
    FROM deliveries
    JOIN matches ON deliveries.match_id = matches.id
    GROUP BY batter, season, deliveries.match_id
)
SELECT 
    batter, 
    season, 
    AVG(total_runs) AS avg_runs
FROM MatchTotals
GROUP BY batter, season;


-- Close Wins (Wins by 10 or Fewer Runs or 2 or Fewer Wickets) --
SELECT winner AS team,COUNT(*) AS close_wins
FROM matches
WHERE (result = 'runs' AND result_margin <= 10) OR (result = 'wickets' AND result_margin <= 2)
GROUP BY winner;

-- Points Table per Season   -- 
WITH TeamMatches AS (
    SELECT season, team1 AS team, winner 
    FROM matches
    WHERE match_type = 'League'
    UNION ALL
    SELECT season, team2 AS team, winner 
    FROM matches
    WHERE match_type = 'League'
)
SELECT 
    season, 
    team, 
    COUNT(*) AS total_matches,
    SUM(CASE WHEN team = winner THEN 1 ELSE 0 END) AS wins,
    COUNT(*) - SUM(CASE WHEN team = winner THEN 1 ELSE 0 END) AS losses
FROM TeamMatches
GROUP BY season, team
ORDER BY season, team;

-- orange cap -- 
WITH season_totals AS (
    SELECT season, batter, SUM(batsman_runs) AS total_runs,
           ROW_NUMBER() OVER (PARTITION BY season ORDER BY SUM(batsman_runs) DESC) AS row_rank
    FROM deliveries
    JOIN matches ON deliveries.match_id = matches.id
    GROUP BY season, batter
)

SELECT season, batter, total_runs
FROM season_totals
WHERE row_rank = 1
ORDER BY season;

-- purple cap -- 
WITH season_wickets AS (
    SELECT season, bowler, COUNT(*) AS total_wickets,
           ROW_NUMBER() OVER (PARTITION BY season ORDER BY COUNT(*) DESC) AS row_rank
    FROM deliveries
    JOIN matches ON deliveries.match_id = matches.id
    WHERE is_wicket = 1 
      AND dismissal_kind NOT IN ('retired hurt', 'retired out', 'run out')
    GROUP BY season, bowler
)

SELECT season, bowler, total_wickets
FROM season_wickets
WHERE row_rank = 1
ORDER BY season;

-- Top Batsmen with Most Half-Centuries and Centuries -- 
WITH TotalRunsPerInning AS (
    SELECT
        batter,
        match_id,
        inning,
        SUM(batsman_runs) AS total_runs
    FROM deliveries
    GROUP BY batter, match_id, inning
)
SELECT 
    batter,
    SUM(CASE WHEN total_runs >= 50 AND total_runs < 100 THEN 1 ELSE 0 END) AS half_centuries,
    SUM(CASE WHEN total_runs >= 100 THEN 1 ELSE 0 END) AS centuries
FROM TotalRunsPerInning
GROUP BY batter
ORDER BY centuries DESC, half_centuries DESC;

-- Find Bowlers with 3-Wicket and 5-Wicket Hauls -- 
WITH WicketsPerInning AS (
    SELECT
        bowler,
        match_id,
        inning,
        COUNT(*) AS wickets
    FROM deliveries
    WHERE is_wicket = 1 AND dismissal_kind NOT IN ('retired hurt', 'retired out', 'run out')
    GROUP BY bowler, match_id, inning
)
SELECT 
    bowler,
    SUM(CASE WHEN wickets = 3 THEN 1 ELSE 0 END) AS three_wickets,
    SUM(CASE WHEN wickets >= 5 THEN 1 ELSE 0 END) AS five_wickets
FROM WicketsPerInning
GROUP BY bowler
ORDER BY five_wickets DESC, three_wickets DESC;


