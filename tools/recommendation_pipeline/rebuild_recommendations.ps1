param(
    [string]$BaseUrl = "http://127.0.0.1:8090",
    [Parameter(Mandatory = $true)]
    [string]$SuperuserEmail,
    [Parameter(Mandatory = $true)]
    [string]$SuperuserPassword,
    [Parameter(Mandatory = $true)]
    [string]$UserId,
    [string]$DatasetDir = ".\assets\db\ml-latest-small",
    [string]$WorkingDir = ".\assets\db\generated",
    [int]$TopN = 10,
    [int]$MinimumRatings = 5,
    [switch]$SkipMetadataSync = $false
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $WorkingDir)) {
    New-Item -ItemType Directory -Path $WorkingDir | Out-Null
}

$safeUserId = $UserId -replace '[^a-zA-Z0-9_-]', '_'
$ratingsFile = Join-Path $WorkingDir "user_ratings_${safeUserId}.json"
$previousRecommendationsFile = Join-Path $WorkingDir "recommendations_${safeUserId}_previous.json"
$recommendationsFile = Join-Path $WorkingDir "recommendations_${safeUserId}.json"
$comparisonReportFile = Join-Path $WorkingDir "recommendation_report_${safeUserId}.json"

Write-Host "Step 1/4: Exporting user ratings from PocketBase..."
python .\tools\recommendation_pipeline\pocketbase_export_ratings.py `
    --base-url $BaseUrl `
    --superuser-email $SuperuserEmail `
    --superuser-password $SuperuserPassword `
    --user-id $UserId `
    --output-file $ratingsFile

if ($LASTEXITCODE -ne 0) {
    throw "Ratings export failed."
}

$ratings = @()
if (Test-Path $ratingsFile) {
    $ratings = Get-Content -Path $ratingsFile -Raw | ConvertFrom-Json
}

$ratingCount = @($ratings).Count
Write-Host "User has rated $ratingCount movies."

if ($ratingCount -lt $MinimumRatings) {
    Write-Warning "The user has fewer than $MinimumRatings ratings. Recommendations may be weak."
}

Write-Host "Step 2/4: Computing recommendations from MovieLens..."
if (Test-Path $recommendationsFile) {
    Copy-Item -Path $recommendationsFile -Destination $previousRecommendationsFile -Force
}

python .\tools\recommendation_pipeline\movielens_recommender.py `
    --dataset-dir $DatasetDir `
    --user-id $UserId `
    --user-ratings-file $ratingsFile `
    --output-file $recommendationsFile `
    --top-n $TopN

if ($LASTEXITCODE -ne 0) {
    throw "Recommendation generation failed."
}

if (Test-Path $previousRecommendationsFile) {
    python .\tools\recommendation_pipeline\compare_recommendation_runs.py `
        --previous-file $previousRecommendationsFile `
        --current-file $recommendationsFile `
        --output-file $comparisonReportFile

    if ($LASTEXITCODE -eq 0 -and (Test-Path $comparisonReportFile)) {
        $report = Get-Content -Path $comparisonReportFile -Raw | ConvertFrom-Json
        Write-Host "Comparison summary:"
        Write-Host "  Previous recommendations: $($report.previousCount)"
        Write-Host "  Current recommendations:  $($report.currentCount)"
        Write-Host "  Overlap ratio:            $($report.overlapRatio)"
        Write-Host "  New movie ids:            $($report.newMovieIds -join ', ')"
    }
}

Write-Host "Step 3/4: Importing recommendations into PocketBase..."
python .\tools\recommendation_pipeline\pocketbase_import_json.py `
    --base-url $BaseUrl `
    --superuser-email $SuperuserEmail `
    --superuser-password $SuperuserPassword `
    --collection recommendations `
    --json-file $recommendationsFile `
    --lookup-template 'uid={uid} && movieId={movieId}'

if ($LASTEXITCODE -ne 0) {
    throw "Recommendation import failed."
}

if (-not $SkipMetadataSync) {
    Write-Host "Step 4/4: Syncing recommendation metadata..."
    python .\tools\recommendation_pipeline\sync_recommendation_metadata.py `
        --base-url $BaseUrl `
        --superuser-email $SuperuserEmail `
        --superuser-password $SuperuserPassword `
        --user-id $UserId

    if ($LASTEXITCODE -ne 0) {
        throw "Recommendation metadata sync failed."
    }
} else {
    Write-Host "Step 4/4: Metadata sync skipped."
}

Write-Host "Done. Open the Recommendations screen and refresh it."
