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

function Get-PythonCommand {
    $candidates = @()

    if (Get-Command python -ErrorAction SilentlyContinue) {
        $candidates += "python"
    }

    if (Get-Command py -ErrorAction SilentlyContinue) {
        $candidates += "py"
    }

    foreach ($candidate in $candidates) {
        & $candidate -c "import pandas, sklearn, requests" 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $candidate
        }
    }

    if ($candidates.Count -gt 0) {
        throw "Python found, but required modules are missing. Install pandas, scikit-learn, requests, and firebase-admin into the interpreter you plan to use."
    }

    throw "Python interpreter not found. Install Python or use the Windows py launcher."
}

function Merge-Reports {
    param(
        [string]$ComparisonReportPath,
        [string]$ValidationReportPath,
        [string]$OutputPath,
        [int]$RatingCount,
        [int]$TopN
    )

    $comparison = $null
    $validation = $null

    if (Test-Path $ComparisonReportPath) {
        $comparison = Get-Content -Path $ComparisonReportPath -Raw | ConvertFrom-Json
    }

    if (Test-Path $ValidationReportPath) {
        $validation = Get-Content -Path $ValidationReportPath -Raw | ConvertFrom-Json
    }

    $summary = [ordered]@{
        ratingCount = $RatingCount
        topN = $TopN
        validationStatus = if ($null -ne $validation) { $validation.status } else { "missing" }
        qualityLabel = if ($null -ne $validation) { $validation.qualityLabel } else { $null }
    }

    $report = [ordered]@{
        summary = $summary
        comparison = $comparison
        validation = $validation
    }

    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
}

if (-not (Test-Path $WorkingDir)) {
    New-Item -ItemType Directory -Path $WorkingDir | Out-Null
}

$pythonCommand = Get-PythonCommand
$safeUserId = $UserId -replace '[^a-zA-Z0-9_-]', '_'
$ratingsFile = Join-Path $WorkingDir "user_ratings_${safeUserId}.json"
$previousRecommendationsFile = Join-Path $WorkingDir "recommendations_${safeUserId}_previous.json"
$recommendationsFile = Join-Path $WorkingDir "recommendations_${safeUserId}.json"
$comparisonReportFile = Join-Path $WorkingDir "recommendation_comparison_${safeUserId}.json"
$validationReportFile = Join-Path $WorkingDir "recommendation_validation_${safeUserId}.json"
$finalReportFile = Join-Path $WorkingDir "recommendation_report_${safeUserId}.json"

Write-Host "Step 1/4: Exporting user ratings from PocketBase..."
& $pythonCommand .\tools\recommendation_pipeline\pocketbase_export_ratings.py `
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

Write-Host "Step 2/4: Computing recommendations and validation metrics..."
if (Test-Path $recommendationsFile) {
    Copy-Item -Path $recommendationsFile -Destination $previousRecommendationsFile -Force
}

& $pythonCommand .\tools\recommendation_pipeline\movielens_recommender.py `
    --dataset-dir $DatasetDir `
    --user-id $UserId `
    --user-ratings-file $ratingsFile `
    --output-file $recommendationsFile `
    --validation-output-file $validationReportFile `
    --top-n $TopN

if ($LASTEXITCODE -ne 0) {
    throw "Recommendation generation failed."
}

if (Test-Path $previousRecommendationsFile) {
    & $pythonCommand .\tools\recommendation_pipeline\compare_recommendation_runs.py `
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

if (Test-Path $validationReportFile) {
    $validation = Get-Content -Path $validationReportFile -Raw | ConvertFrom-Json
    Write-Host "Validation summary:"
    Write-Host "  Status:        $($validation.status)"
    if ($validation.status -eq "ok") {
        Write-Host "  Precision@K:   $($validation.precisionAtK)"
        Write-Host "  Recall@K:      $($validation.recallAtK)"
        Write-Host "  HitRate@K:     $($validation.hitRateAtK)"
        Write-Host "  nDCG@K:        $($validation.ndcgAtK)"
        Write-Host "  Quality label: $($validation.qualityLabel)"
    }
}

Merge-Reports `
    -ComparisonReportPath $comparisonReportFile `
    -ValidationReportPath $validationReportFile `
    -OutputPath $finalReportFile `
    -RatingCount $ratingCount `
    -TopN $TopN

Write-Host "Step 3/4: Importing recommendations into PocketBase..."
& $pythonCommand .\tools\recommendation_pipeline\pocketbase_import_json.py `
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
    & $pythonCommand .\tools\recommendation_pipeline\sync_recommendation_metadata.py `
        --base-url $BaseUrl `
        --superuser-email $SuperuserEmail `
        --superuser-password $SuperuserPassword `
        --user-id $UserId

    if ($LASTEXITCODE -ne 0) {
        throw "Recommendation metadata sync failed."
    }
}
else {
    Write-Host "Step 4/4: Metadata sync skipped."
}

Write-Host "Done. Open the Recommendations screen and refresh it."
